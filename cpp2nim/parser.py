"""
C++ header parser using libclang.

This module provides the CppHeaderParser class for parsing C++ headers
using the Clang AST. Supports multiprocessing for faster parsing of
large header sets.
"""

import glob
import logging
import os
import pickle
import re
import sys
import time
from dataclasses import dataclass, field
from multiprocessing import Pool, cpu_count
from pathlib import Path
from typing import Any, Callable

import clang.cindex

from .config import Config
from .models import (
    ClassDecl, ConstructorDecl, EnumDecl, EnumItem, FieldDecl,
    MethodDecl, Parameter, ParsedHeader, ParseResult, StructDecl, TypedefDecl
)
from .utils import (
    NORMAL_TYPES, clean_type_name, format_comment, get_code_span,
    get_fully_qualified_name, get_fully_qualified_type, get_nodes,
    get_root_from_glob, get_template_dependencies, get_template_parameters
)


# Logging setup
logger = logging.getLogger(__name__)


@dataclass
class ParserContext:
    """Holds mutable state during a parse session.
    
    This is passed explicitly rather than using module-level globals,
    making the parser more reentrant and testable.
    """
    visited_enums: set[int] = field(default_factory=set)
    visited_structs: set[int] = field(default_factory=set)
    file_cache: dict[str, list[str]] = field(default_factory=dict)


def _get_params_from_node(node: clang.cindex.Cursor, 
                          file_cache: dict[str, list[str]]) -> list[Parameter]:
    """Extract parameters from a function/method node.
    
    Args:
        node: Clang cursor for the function/method.
        file_cache: Cache of source file contents.
        
    Returns:
        List of Parameter objects.
    """
    params = []
    
    for param_node in node.get_children():
        if param_node.kind != clang.cindex.CursorKind.PARM_DECL:
            continue
        
        param_name = param_node.displayname
        default_value = None
        
        # Extract default value if present
        for child in param_node.get_children():
            if child.kind == clang.cindex.CursorKind.DECL_REF_EXPR:
                for token in child.get_tokens():
                    default_value = token.spelling
                continue
            
            if child.kind in [
                clang.cindex.CursorKind.CALL_EXPR,
                clang.cindex.CursorKind.BINARY_OPERATOR,
                clang.cindex.CursorKind.UNARY_OPERATOR,
                clang.cindex.CursorKind.PAREN_EXPR,
                clang.cindex.CursorKind.UNEXPOSED_EXPR,
                clang.cindex.CursorKind.CXX_BOOL_LITERAL_EXPR,
                clang.cindex.CursorKind.INTEGER_LITERAL,
                clang.cindex.CursorKind.FLOATING_LITERAL
            ]:
                default_value = get_code_span(child, file_cache)
                if default_value and default_value.startswith("="):
                    default_value = default_value[1:].lstrip()
                continue
            
            # Handle more complex expressions
            is_call = False
            if child.kind == clang.cindex.CursorKind.CALL_EXPR:
                default_value = child.spelling + "("
                is_call = True
            
            count = 0
            for grandchild in child.get_children():
                if is_call and count > 0:
                    default_value = (default_value or "") + ", "
                count += 1
                
                if grandchild.kind == clang.cindex.CursorKind.UNEXPOSED_EXPR:
                    if default_value is None:
                        default_value = ""
                    for token in grandchild.get_tokens():
                        default_value += token.spelling
                
                elif grandchild.kind == clang.cindex.CursorKind.CALL_EXPR:
                    if default_value is None:
                        default_value = ""
                    for token in grandchild.get_tokens():
                        if token.spelling == "=":
                            continue
                        default_value += token.spelling
                
                elif grandchild.kind == clang.cindex.CursorKind.GNU_NULL_EXPR:
                    default_value = "nil"
                
                elif grandchild.kind == clang.cindex.CursorKind.STRING_LITERAL:
                    try:
                        default_value = next(grandchild.get_tokens()).spelling
                    except StopIteration:
                        pass
                
                elif grandchild.kind in [
                    clang.cindex.CursorKind.INTEGER_LITERAL,
                    clang.cindex.CursorKind.FLOATING_LITERAL
                ]:
                    if default_value is None:
                        default_value = ""
                    try:
                        default_value += next(grandchild.get_tokens()).spelling
                    except StopIteration:
                        default_value += "???"
            
            if is_call:
                default_value = (default_value or "") + ")"
        
        # Normalize NULL to nil
        if default_value == "NULL":
            default_value = "nil"
        
        params.append(Parameter(
            name=param_name,
            type_name=get_fully_qualified_type(param_node.type),
            default_value=default_value
        ))
    
    return params


class CppAstVisitor:
    """Visitor for extracting declarations from a Clang AST.
    
    This class traverses the Clang AST and extracts type definitions,
    enums, structs, classes, methods, constructors, and typedefs.
    """
    
    def __init__(self, filename: str, config: Config, ctx: ParserContext):
        """Initialize the visitor.
        
        Args:
            filename: The source file being parsed.
            config: Parser configuration.
            ctx: Parser context for state tracking.
        """
        self.filename = filename
        self.config = config
        self.ctx = ctx
        
        # Accumulated declarations
        self.enums: list[EnumDecl] = []
        self.structs: list[StructDecl] = []
        self.classes: list[ClassDecl] = []
        self.methods: list[MethodDecl] = []
        self.constructors: list[ConstructorDecl] = []
        self.typedefs: list[TypedefDecl] = []
        self.constants: list[EnumDecl] = []
        self.enum_dups: list[dict[str, str]] = []
    
    def can_visit(self, node: clang.cindex.Cursor) -> bool:
        """Check if a node should be visited."""
        if not node.location.file:
            return False
        return node.location.file.name == self.filename
    
    def visit_all(self, cursor: clang.cindex.Cursor) -> None:
        """Visit all nodes in the AST.
        
        Args:
            cursor: Root cursor of the translation unit.
        """
        # Collect nodes by type
        nodes_by_type: dict[str, list[clang.cindex.Cursor]] = {
            'typedef': [],
            'enum': [],
            'class': [],
            'struct': [],
            'constructor': [],
            'method': [],
            'function': [],
            'var': []
        }
        
        for _, node in get_nodes(cursor):
            if node.kind == clang.cindex.CursorKind.TYPEDEF_DECL:
                nodes_by_type['typedef'].append(node)
            elif node.kind == clang.cindex.CursorKind.ENUM_DECL:
                nodes_by_type['enum'].append(node)
            elif node.kind == clang.cindex.CursorKind.CLASS_DECL:
                nodes_by_type['class'].append(node)
            elif node.kind == clang.cindex.CursorKind.STRUCT_DECL:
                nodes_by_type['struct'].append(node)
            elif node.kind == clang.cindex.CursorKind.CONSTRUCTOR:
                nodes_by_type['constructor'].append(node)
            elif node.kind == clang.cindex.CursorKind.CXX_METHOD:
                nodes_by_type['method'].append(node)
            elif node.kind == clang.cindex.CursorKind.FUNCTION_DECL:
                nodes_by_type['function'].append(node)
            elif node.kind == clang.cindex.CursorKind.VAR_DECL:
                nodes_by_type['var'].append(node)
        
        # Visit typedefs first (they may define structs/enums)
        for node in nodes_by_type['typedef']:
            if node.location.file and node.location.file.name == self.filename:
                self._visit_typedef_decl(node)
        
        # Visit remaining types
        for node in nodes_by_type['enum']:
            if self.can_visit(node):
                self._visit_enum_decl(node)
        
        for node in nodes_by_type['class']:
            if self.can_visit(node):
                self._visit_class_decl(node)
        
        for node in nodes_by_type['struct']:
            if self.can_visit(node):
                self._visit_struct_decl(node)
        
        for node in nodes_by_type['constructor']:
            if self.can_visit(node):
                self._visit_constructor_decl(node)
        
        for node in nodes_by_type['method']:
            if self.can_visit(node):
                self._visit_cxx_method(node)
        
        for node in nodes_by_type['function']:
            if self.can_visit(node):
                self._visit_function_decl(node)
        
        for node in nodes_by_type['var']:
            if self.can_visit(node):
                self._visit_var_decl(node)
    
    def _visit_enum_decl(self, node: clang.cindex.Cursor) -> None:
        """Visit an enum declaration."""
        if node.hash in self.ctx.visited_enums:
            return
        if not node.is_definition():
            return
        
        is_const = (
            node.spelling == "" or
            node.spelling.startswith("(unnamed") or
            node.spelling.startswith("(anonymous") or
            node.spelling in self.config.enum_to_const
        )
        
        # Collect enum items
        items: list[EnumItem] = []
        for child in node.get_children():
            if child.kind == clang.cindex.CursorKind.ENUM_CONSTANT_DECL:
                items.append(EnumItem(
                    name=child.spelling,
                    value=child.enum_value,
                    comment=child.brief_comment
                ))
        
        enum_data = EnumDecl(
            name=node.spelling,
            fully_qualified=get_fully_qualified_name(node.referenced),
            underlying_type=node.enum_type.spelling,
            items=items,
            comment=node.brief_comment
        )
        
        if not is_const:
            # Sort by value and handle duplicates
            values = sorted(set(item.value for item in items))
            new_items = []
            dup_items = []
            value2name: dict[int, str] = {}
            remaining_names = [item.name for item in items]
            
            for value in values:
                for item in items:
                    if item.value == value and item.name in remaining_names:
                        new_items.append(item)
                        remaining_names.remove(item.name)
                        value2name[value] = item.name
                        break
            
            # Handle remaining items (duplicate values)
            for name in remaining_names:
                for item in items:
                    if item.name == name:
                        dup_items.append({"name": name, "target": value2name[item.value]})
                        break
            
            enum_data.items = new_items
            self.enums.append(enum_data)
            if dup_items:
                self.enum_dups.append(dup_items)
        else:
            self.constants.append(enum_data)
        
        self.ctx.visited_enums.add(node.hash)
    
    def _visit_typedef_decl(self, node: clang.cindex.Cursor) -> None:
        """Visit a typedef declaration."""
        if node.access_specifier in [
            clang.cindex.AccessSpecifier.PRIVATE,
            clang.cindex.AccessSpecifier.PROTECTED
        ]:
            return
        
        underlying = node.underlying_typedef_type.spelling
        underlying_deps = get_template_dependencies(underlying)
        params = _get_params_from_node(node, self.ctx.file_cache)
        
        typedef_kind = None
        result_type = node.result_type.spelling
        struct_data = None
        enum_data = None
        
        kind = node.underlying_typedef_type.kind
        
        if kind == clang.cindex.TypeKind.POINTER:
            pointee = node.underlying_typedef_type.get_pointee()
            if pointee.kind == clang.cindex.TypeKind.FUNCTIONPROTO:
                result_type = pointee.get_result().spelling
                typedef_kind = "function"
        
        elif kind == clang.cindex.TypeKind.FUNCTIONPROTO:
            result_type = node.underlying_typedef_type.get_result().spelling
            typedef_kind = "function"
        
        else:
            inner = node.underlying_typedef_type.get_declaration()
            
            if inner.kind == clang.cindex.CursorKind.STRUCT_DECL:
                if inner.hash in self.ctx.visited_structs:
                    return
                self.ctx.visited_structs.add(inner.hash)
                struct_data = self._parse_struct_inner(inner)
                typedef_kind = "struct"
            
            elif inner.kind == clang.cindex.CursorKind.UNION_DECL:
                if inner.hash in self.ctx.visited_structs:
                    return
                self.ctx.visited_structs.add(inner.hash)
                struct_data = self._parse_struct_inner(inner)
                struct_data.is_union = True
                typedef_kind = "struct"
            
            elif inner.kind == clang.cindex.CursorKind.ENUM_DECL:
                if node.spelling in self.config.enum_to_const:
                    return
                if inner.hash in self.ctx.visited_structs:
                    return
                self.ctx.visited_enums.add(inner.hash)
                
                items = []
                for child in inner.get_children():
                    if child.kind == clang.cindex.CursorKind.ENUM_CONSTANT_DECL:
                        items.append(EnumItem(
                            name=child.spelling,
                            value=child.enum_value,
                            comment=child.brief_comment
                        ))
                
                enum_data = EnumDecl(
                    name=inner.spelling,
                    fully_qualified=get_fully_qualified_name(node.referenced),
                    underlying_type=inner.enum_type.spelling,
                    items=items,
                    comment=inner.brief_comment
                )
                typedef_kind = "enum"
        
        self.typedefs.append(TypedefDecl(
            name=node.spelling,
            fully_qualified=get_fully_qualified_name(node.referenced),
            underlying=underlying,
            typedef_kind=typedef_kind,
            params=params,
            result_type=result_type,
            underlying_deps=underlying_deps,
            struct_data=struct_data,
            enum_data=enum_data
        ))
    
    def _collect_anonymous_fields(
        self, 
        field_cursor: clang.cindex.Cursor, 
        deps: list[str],
        has_union_parent: bool = False
    ) -> tuple[list[FieldDecl], bool]:
        """Recursively collect fields from anonymous unions/structs."""
        collected_fields: list[FieldDecl] = []
        
        if not field_cursor.is_anonymous():
            field_type = get_fully_qualified_type(field_cursor.type)
            collected_fields.append(FieldDecl(
                name=field_cursor.spelling,
                type_name=field_type
            ))
            deps.extend(get_template_dependencies(field_type))
            return collected_fields, has_union_parent
        
        field_decl = field_cursor.type.get_declaration()
        
        if field_decl.kind == clang.cindex.CursorKind.UNION_DECL:
            self.ctx.visited_structs.add(field_decl.hash)
            for union_member in field_cursor.type.get_fields():
                member_fields, _ = self._collect_anonymous_fields(union_member, deps, True)
                collected_fields.extend(member_fields)
            has_union_parent = True
        
        elif field_decl.kind == clang.cindex.CursorKind.STRUCT_DECL:
            self.ctx.visited_structs.add(field_decl.hash)
            for struct_member in field_cursor.type.get_fields():
                member_fields, union_found = self._collect_anonymous_fields(
                    struct_member, deps, has_union_parent
                )
                collected_fields.extend(member_fields)
                has_union_parent = has_union_parent or union_found
        
        else:
            field_type = get_fully_qualified_type(field_cursor.type)
            collected_fields.append(FieldDecl(
                name=f"_anonymous_{id(field_cursor)}",
                type_name=field_type,
                is_anonymous=True
            ))
            deps.extend(get_template_dependencies(field_type))
        
        return collected_fields, has_union_parent
    
    def _parse_struct_inner(self, node: clang.cindex.Cursor) -> StructDecl:
        """Parse the inner content of a struct."""
        fields: list[FieldDecl] = []
        deps: list[str] = []
        has_anonymous_union = False
        
        # Get template parameters
        template_params: list[str | tuple[str, str]] = []
        for child in node.get_children():
            if child.kind == clang.cindex.CursorKind.TEMPLATE_TYPE_PARAMETER:
                template_params.append(child.spelling)
            elif child.kind == clang.cindex.CursorKind.TEMPLATE_NON_TYPE_PARAMETER:
                template_params.append((child.spelling, child.type.spelling))
        
        # Process fields
        for field_cursor in node.type.get_fields():
            collected, has_union = self._collect_anonymous_fields(field_cursor, deps)
            fields.extend(collected)
            has_anonymous_union = has_anonymous_union or has_union
        
        is_incomplete = node.type.get_size() < 0 or has_anonymous_union
        
        # Get base classes
        base_types: list[str] = []
        for child in node.get_children():
            if child.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
                base_types.append(get_fully_qualified_type(child.type))
        
        return StructDecl(
            name=node.spelling,
            fully_qualified=get_fully_qualified_name(node.referenced),
            fields=fields,
            base_types=base_types,
            template_params=template_params,
            is_incomplete=is_incomplete,
            comment=node.brief_comment,
            underlying_deps=deps
        )
    
    def _visit_class_decl(self, node: clang.cindex.Cursor) -> None:
        """Visit a class declaration."""
        if node.access_specifier in [
            clang.cindex.AccessSpecifier.PRIVATE,
            clang.cindex.AccessSpecifier.PROTECTED
        ]:
            return
        if not node.is_definition():
            return
        if not node.location.file or node.location.file.name != self.filename:
            return
        
        # Get template parameters
        template_params: list[str | tuple[str, str]] = []
        base_types: list[str] = []
        
        for child in node.get_children():
            if child.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
                base_types.append(get_fully_qualified_type(child.type))
            elif child.kind == clang.cindex.CursorKind.TEMPLATE_TYPE_PARAMETER:
                template_params.append(child.spelling)
            elif child.kind == clang.cindex.CursorKind.TEMPLATE_NON_TYPE_PARAMETER:
                template_params.append((child.spelling, child.type.spelling))
        
        # Get public fields
        fields: list[FieldDecl] = []
        for field_cursor in node.type.get_fields():
            if field_cursor.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
                continue
            
            if field_cursor.is_anonymous():
                for subfield in field_cursor.type.get_fields():
                    fields.append(FieldDecl(
                        name=subfield.spelling,
                        type_name=get_fully_qualified_type(subfield.type)
                    ))
            else:
                fields.append(FieldDecl(
                    name=field_cursor.spelling,
                    type_name=get_fully_qualified_type(field_cursor.type)
                ))
        
        self.classes.append(ClassDecl(
            name=node.spelling,
            fully_qualified=get_fully_qualified_name(node.referenced),
            fields=fields,
            base_types=base_types,
            template_params=template_params,
            comment=node.brief_comment
        ))
    
    def _visit_struct_decl(self, node: clang.cindex.Cursor) -> None:
        """Visit a struct declaration."""
        if node.hash in self.ctx.visited_structs:
            return
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
            return
        if not node.is_definition():
            return
        if node.spelling.startswith("(unnamed"):
            return
        
        struct_data = self._parse_struct_inner(node)
        if node.type.get_size() >= 0:
            self.structs.append(struct_data)
        self.ctx.visited_structs.add(node.hash)
    
    def _visit_constructor_decl(self, node: clang.cindex.Cursor) -> None:
        """Visit a constructor declaration."""
        if not node.location.file or node.location.file.name != self.filename:
            return
        
        self.constructors.append(ConstructorDecl(
            name=node.spelling,
            fully_qualified=get_fully_qualified_name(node.semantic_parent),
            class_name=node.semantic_parent.spelling,
            params=_get_params_from_node(node, self.ctx.file_cache),
            comment=node.brief_comment
        ))
    
    def _visit_cxx_method(self, node: clang.cindex.Cursor) -> None:
        """Visit a C++ method."""
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
            return
        if not node.location.file or node.location.file.name != self.filename:
            return
        
        name = node.spelling
        if name.startswith("operator"):
            op = name[8:]
            if re.match(r"[\[\]!+\-=*\^/]+", op):
                name = f"`{op}`"
            else:
                return
        
        self.methods.append(MethodDecl(
            name=name,
            fully_qualified=get_fully_qualified_name(node.referenced),
            class_name=node.semantic_parent.spelling,
            return_type=node.result_type.spelling,
            params=_get_params_from_node(node, self.ctx.file_cache),
            is_const=node.is_const_method(),
            is_plain_function=False,
            file_origin=node.location.file.name,
            comment=node.brief_comment,
            result_deps=get_template_dependencies(node.result_type.spelling)
        ))
    
    def _visit_function_decl(self, node: clang.cindex.Cursor) -> None:
        """Visit a function declaration."""
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
            return
        
        name = node.spelling
        if name.startswith("operator"):
            return
        
        self.methods.append(MethodDecl(
            name=name,
            fully_qualified=get_fully_qualified_name(node.referenced),
            class_name="",
            return_type=node.result_type.spelling,
            params=_get_params_from_node(node, self.ctx.file_cache),
            is_const=False,
            is_plain_function=True,
            file_origin=node.location.file.name if node.location.file else "",
            comment=node.brief_comment,
            result_deps=get_template_dependencies(node.result_type.spelling)
        ))
    
    def _visit_var_decl(self, node: clang.cindex.Cursor) -> None:
        """Visit a variable declaration (for function pointers)."""
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
            return
        if node.type.kind != clang.cindex.TypeKind.TYPEDEF:
            return
        if not node.location.file or node.location.file.name != self.filename:
            return
        
        vtype_decl = node.type.get_declaration()
        pointee = vtype_decl.underlying_typedef_type.get_pointee()
        
        if pointee.kind != clang.cindex.TypeKind.FUNCTIONPROTO:
            return
        
        self.methods.append(MethodDecl(
            name=node.spelling,
            fully_qualified=get_fully_qualified_name(node.referenced),
            class_name="",
            return_type=pointee.get_result().spelling,
            params=_get_params_from_node(vtype_decl, self.ctx.file_cache),
            is_const=False,
            is_plain_function=True,
            file_origin=node.location.file.name,
            comment="",
            result_deps=get_template_dependencies(pointee.get_result().spelling)
        ))


def _find_depends_on(header: ParsedHeader) -> set[str]:
    """Find all dependencies in the parsed header."""
    dependencies: set[str] = set()
    
    for method in header.methods:
        for param in method.params:
            deps = get_template_dependencies(param.type_name)
            if deps:
                dependencies.update(deps)
            else:
                dependencies.add(clean_type_name(param.type_name))
            
            if param.default_value is not None:
                dependencies.add(param.default_value)
        
        if method.result_deps:
            dependencies.update(method.result_deps)
        elif method.return_type:
            dependencies.add(clean_type_name(method.return_type))
    
    for constructor in header.constructors:
        for param in constructor.params:
            deps = get_template_dependencies(param.type_name)
            if deps:
                dependencies.update(deps)
            else:
                dependencies.add(clean_type_name(param.type_name))
    
    for typedef in header.typedefs:
        if typedef.underlying_deps:
            dependencies.update(typedef.underlying_deps)
        else:
            dependencies.add(clean_type_name(typedef.underlying))
    
    for struct in header.structs:
        for field_decl in struct.fields:
            dependencies.add(field_decl.type_name)
    
    return dependencies


def _find_provided(header: ParsedHeader, dependencies: set[str]) -> set[str]:
    """Find all types that the header provides."""
    provides: set[str] = set()
    
    for const_enum in header.constants:
        for item in const_enum.items:
            if item.name in dependencies:
                provides.add(item.name)
    
    for enum in header.enums:
        for item in enum.items:
            provides.add((item.name, enum.fully_qualified))  # type: ignore
        provides.add(enum.fully_qualified)
    
    for struct in header.structs:
        provides.add(struct.fully_qualified)
    
    for cls in header.classes:
        provides.add(cls.fully_qualified)
    
    for typedef in header.typedefs:
        provides.add(typedef.fully_qualified)
    
    return provides


def _find_missing(dependencies: set[str], provides: set[str]) -> set[str]:
    """Find dependencies that are not provided locally."""
    missing: set[str] = set()
    
    for dep in dependencies:
        if dep in NORMAL_TYPES:
            continue
        if dep in provides:
            continue
        # Check tuple provides (enum values)
        provided_values = [k[0] for k in provides if isinstance(k, tuple)]
        if dep in provided_values:
            continue
        missing.add(dep)
    
    return missing


def _parse_single_file_worker(args: tuple[str, dict[str, Any]]) -> dict[str, Any]:
    """Worker function for multiprocessing.
    
    Must be at module level for pickling.
    """
    filename, config_dict = args
    config = Config.from_dict(config_dict)
    
    ctx = ParserContext()
    
    # Create Clang index
    index = clang.cindex.Index.create()
    
    # Prepare arguments
    clang_args = []
    if config.c_mode:
        clang_args += ['-x', 'c']
    else:
        clang_args += ['-x', 'c++', '-std=c++17']
    
    clang_args += config.extra_args
    clang_args += [f"-I{path}" for path in config.search_paths]
    
    # Parse options
    opts = (
        clang.cindex.TranslationUnit.PARSE_SKIP_FUNCTION_BODIES |
        clang.cindex.TranslationUnit.PARSE_PRECOMPILED_PREAMBLE |
        clang.cindex.TranslationUnit.PARSE_CACHE_COMPLETION_RESULTS
    )
    
    # Parse the file
    tu = index.parse(filename, clang_args, None, opts)
    
    # Visit AST
    visitor = CppAstVisitor(filename, config, ctx)
    visitor.visit_all(tu.cursor)
    
    # Create ParsedHeader
    header = ParsedHeader(
        filename=filename,
        enums=visitor.enums,
        structs=visitor.structs,
        classes=visitor.classes,
        methods=visitor.methods,
        constructors=visitor.constructors,
        typedefs=visitor.typedefs,
        constants=visitor.constants,
        enum_dups=visitor.enum_dups
    )
    
    # Compute dependencies
    header.dependencies = _find_depends_on(header)
    header.provides = _find_provided(header, header.dependencies)
    header.missing = _find_missing(header.dependencies, header.provides)
    
    # Return as dict for pickling
    return {
        "filename": filename,
        "header": header,
        "dependencies": header.dependencies,
        "provides": header.provides,
        "missing": header.missing
    }


class CppHeaderParser:
    """Parse C++ headers using libclang.
    
    Supports parallel parsing via multiprocessing for large header sets.
    
    Example:
        >>> config = Config(search_paths=["/usr/include"])
        >>> parser = CppHeaderParser(config)
        >>> result = parser.parse_files(["/path/to/*.h"], parallel=True)
    """
    
    def __init__(self, config: Config | None = None):
        """Initialize the parser.
        
        Args:
            config: Parser configuration. Uses defaults if None.
        """
        self.config = config or Config()
    
    def parse_file(self, filename: str) -> ParsedHeader:
        """Parse a single header file.
        
        Args:
            filename: Absolute path to the header file.
            
        Returns:
            ParsedHeader containing all declarations found.
        """
        result = _parse_single_file_worker((filename, self.config.to_dict()))
        return result["header"]
    
    def parse_files(
        self,
        patterns: list[str],
        parallel: bool | None = None,
        num_workers: int | None = None,
        progress_callback: Callable[[int, int, str], None] | None = None
    ) -> ParseResult:
        """Parse multiple header files matching glob patterns.
        
        Args:
            patterns: List of file paths or glob patterns for header files.
            parallel: Use multiprocessing (default: from config).
            num_workers: Number of workers (default: from config or cpu_count).
            progress_callback: Optional callback(current, total, filename).
            
        Returns:
            ParseResult containing all parsed headers and dependency info.
        """
        # Expand patterns to file list
        files: list[str] = []
        for pattern in patterns:
            if "*" in pattern or "?" in pattern:
                files.extend(glob.glob(pattern, recursive=True))
            elif os.path.isfile(pattern):
                files.append(pattern)
        
        # Filter out ignored files
        files = [f for f in files if f not in self.config.ignore_files]
        
        if not files:
            return ParseResult()
        
        # Determine parallelism
        if parallel is None:
            parallel = self.config.parallel
        if num_workers is None:
            num_workers = self.config.num_workers or cpu_count()
        
        # Parse files
        if parallel and len(files) > 1:
            return self._parse_parallel(files, num_workers, progress_callback)
        return self._parse_sequential(files, progress_callback)
    
    def _parse_sequential(
        self,
        files: list[str],
        progress_callback: Callable[[int, int, str], None] | None
    ) -> ParseResult:
        """Parse files sequentially."""
        result = ParseResult()
        config_dict = self.config.to_dict()
        
        for i, filename in enumerate(files):
            logger.info(f"Parsing ({i+1}/{len(files)}): {filename}")
            
            worker_result = _parse_single_file_worker((filename, config_dict))
            header = worker_result["header"]
            
            result.headers[filename] = header
            result.all_dependencies[filename] = worker_result["dependencies"]
            result.all_provides[filename] = worker_result["provides"]
            result.all_missing[filename] = worker_result["missing"]
            
            if progress_callback:
                progress_callback(i + 1, len(files), filename)
        
        return result
    
    def _parse_parallel(
        self,
        files: list[str],
        num_workers: int,
        progress_callback: Callable[[int, int, str], None] | None
    ) -> ParseResult:
        """Parse files in parallel using multiprocessing."""
        result = ParseResult()
        config_dict = self.config.to_dict()
        
        args = [(f, config_dict) for f in files]
        
        with Pool(num_workers) as pool:
            for i, worker_result in enumerate(pool.imap_unordered(_parse_single_file_worker, args)):
                filename = worker_result["filename"]
                header = worker_result["header"]
                
                result.headers[filename] = header
                result.all_dependencies[filename] = worker_result["dependencies"]
                result.all_provides[filename] = worker_result["provides"]
                result.all_missing[filename] = worker_result["missing"]
                
                logger.info(f"Parsed ({i+1}/{len(files)}): {filename}")
                
                if progress_callback:
                    progress_callback(i + 1, len(files), filename)
        
        return result


def parse_include_file(
    filename: str,
    depends_on: dict[str, set[str]],
    provides: dict[str, set[str]],
    search_paths: list[str] | None = None,
    extra_args: list[str] | None = None,
    enum_to_const: list[str] | None = None,
    c_mode: bool = False
) -> tuple[list[tuple[Any, ...]], set[str], set[str], set[str]]:
    """Parse a single include file (legacy API).
    
    This function maintains backward compatibility with the old parse_headers.py API.
    
    Args:
        filename: Path to header file.
        depends_on: Dictionary to update with dependencies (unused, for signature compat).
        provides: Dictionary to update with provides (unused, for signature compat).
        search_paths: Include directories.
        extra_args: Additional clang arguments.
        enum_to_const: Enums to treat as constants.
        c_mode: Parse as C instead of C++.
        
    Returns:
        Tuple of (data, dependencies, provides, missing) in legacy format.
    """
    config = Config(
        search_paths=search_paths or [],
        extra_args=extra_args or [],
        enum_to_const=enum_to_const or [],
        c_mode=c_mode
    )
    
    parser = CppHeaderParser(config)
    header = parser.parse_file(filename)
    
    # Convert to legacy format
    data: list[tuple[Any, ...]] = []
    
    for const_enum in header.constants:
        data.append((filename, "const", const_enum.to_dict()))
    
    for enum in header.enums:
        data.append((filename, "enum", enum.fully_qualified, enum.to_dict()))
    
    for dup in header.enum_dups:
        data.append((filename, "enum_dup", dup))
    
    for typedef in header.typedefs:
        data.append((filename, "typedef", typedef.name, typedef.to_dict()))
    
    for struct in header.structs:
        data.append((filename, "struct", struct.fully_qualified, struct.to_dict()))
    
    for cls in header.classes:
        data.append((filename, "class", cls.fully_qualified, cls.to_dict()))
    
    for ctor in header.constructors:
        data.append((filename, "constructor", ctor.fully_qualified, ctor.to_dict()))
    
    for method in header.methods:
        data.append((filename, "method", method.fully_qualified, method.to_dict()))
    
    return data, header.dependencies, header.provides, header.missing
