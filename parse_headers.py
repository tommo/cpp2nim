#!/usr/bin/env python
"""
C++ header parser using Visitor pattern
"""

import sys
import clang.cindex
import os
import glob
import textwrap
import re
from pprint import pprint
from pathlib import Path
import collections
import concurrent.futures
import multiprocessing
import queue
import threading
import time
import logging

# Global state and constants remain the same
_visitedEnum = {}
_visitedStruct = {}
files = {}

NIM_KEYWORDS = ["addr", "and", "as", "asm", "bind", "block", "break",
                "case", "cast", "concept", "const", "continue", "converter",
                "defer", "discard", "distinct", "div", "do", "elif", "else",
                "end", "enum", "except", "export", "finally", "for", "from",
                "func", "if", "import", "include", "interface", "is",
                "isnot", "iterator", "let", "macro", "method", "mixin", "mod",
                "nil", "not", "notin", "object", "of", "or", "out", "proc", "ptr",
                "raise", "ref", "return", "shl", "shr", "static", "template",
                "try", "tuple", "type", "using", "var", "when", "while", "xor",
                "yield"]

NORMAL_TYPES = ["void", "long", "unsigned long", "int", "size_t", "long long", "long double", 
                "float", "double", "char", "signed char", "unsigned char", "unsigned short", 
                "unsigned int", "unsigned long long", "char*", "bool"]

PRINT_STRUCT = False
MAX_CACHED_FILES = 100

# Utility functions remain unchanged
def getCodeSpan(cursor):
    """Extract source code text for a given cursor."""
    filename = cursor.location.file.name
    extent = cursor.extent
    
    if filename not in files:
        with open(filename, 'r') as fp:
            files[filename] = fp.readlines()
    
    lines = files[filename]
    lineIdx = extent.start.line - 1
    off0 = extent.start.column - 1
    off1 = extent.end.column - 1
    
    if extent.start.line < extent.end.line:
        off1 = -1
    
    line = lines[lineIdx]
    if off1 < 0:
        return line[off0:]
    else:
        return line[off0:off1]

def flatten(L):
    """Flatten a nested list structure."""
    if not L:
        return []
    if len(L) == 1:
        if isinstance(L[0], list):
            return flatten(L[0])
        return L
    elif isinstance(L[0], list):
        return flatten(L[0]) + flatten(L[1:])
    else:
        return [L[0]] + flatten(L[1:])
        
def clean(txt):
    """Clean up C++ type names for Nim."""
    txt = txt.strip()
    if txt.endswith(" &"):
        txt = txt[:-2]
    if txt.startswith("_"):
        txt = "prefix" + txt[1:]
    if txt in NIM_KEYWORDS:
        txt = f"`{txt}`"
    return txt

def cleanit(tmp):
    """More thorough cleaning of C++ type names."""
    if tmp.endswith("const *"):
        tmp = tmp[:-7] + "*"
    if tmp.startswith("const "):
        tmp = tmp[6:]
    if tmp[-1] in ["&", "*"]:
        tmp = tmp[:-2]
    return tmp

def get_comment(data, n=4):
    """Format a comment for Nim output."""
    spc = " " * n
    result = ""
    comment = data["comment"]
    
    if comment:
        comment_lines = textwrap.fill(comment, width=70).split("\n")
        for line in comment_lines:
            result += f"{spc}## {line}\n"
    
    return result

def get_template_parameters(methodname):
    """Extract template parameters from a method name."""
    if '<' in methodname and '>' == methodname[-1]:
        name, params = methodname.split('<', 1)
        params = params[:-1]  # Remove trailing '>'
        return (name, f"[{params}]")
    return (methodname, '')

def get_root(blob):
    """Get the root directory from a glob pattern."""
    # Case where a specific file is given (no blob)
    if "*" not in blob and "?" not in blob:
        parts = blob.split("/")
        return "/".join(parts[:-1]) + "/"
    
    # Blob case
    parts = blob.split("/")
    result = ""
    for part in parts:
        if "*" not in part:
            result += part + "/"
    return result

def get_template_dependencies(type_name):
    """Extract template parameter dependencies from a type."""
    result = []
    cleaned = cleanit(type_name)
    
    if cleaned.endswith(">") and "<" in cleaned:
        # Parse template parameters
        parts = [p.split('>') for p in cleaned.split('<')]
        parts = flatten(parts)
        parts = [p.split(',') for p in parts]
        parts = flatten(parts)
        parts = [p.strip() for p in parts if p.strip()]
        parts = [cleanit(p) for p in parts if not p.isdigit()]
        return parts
    
    return [cleaned]


def fully_qualified(cursor):
    """Get fully qualified name of a cursor."""
    if cursor is None:
        return ''
    elif cursor.kind == clang.cindex.CursorKind.TRANSLATION_UNIT:
        return ''
    else:
        parent = fully_qualified(cursor.semantic_parent)
        if parent:
            return parent + '::' + cursor.spelling
    return cursor.spelling

def fully_qualified_type(cursor_type):
    """Get fully qualified name for a type, handling pointers/arrays/references."""
    if cursor_type.kind == clang.cindex.TypeKind.POINTER:
        pointee = cursor_type.get_pointee()
        return f"{fully_qualified_type(pointee)}*"
    
    elif cursor_type.kind == clang.cindex.TypeKind.LVALUEREFERENCE:
        ref = cursor_type.get_pointee()
        return f"{fully_qualified_type(ref)}&"
    
    elif cursor_type.kind == clang.cindex.TypeKind.CONSTANTARRAY:
        array_size = cursor_type.get_array_size()
        element_type = cursor_type.get_array_element_type()
        return f"{fully_qualified_type(element_type)}[{array_size}]"
    
    elif cursor_type.kind == clang.cindex.TypeKind.INCOMPLETEARRAY:
        element_type = cursor_type.get_array_element_type()
        return f"{fully_qualified_type(element_type)}[]"
    
    elif cursor_type.kind in [
        clang.cindex.TypeKind.TYPEDEF,
        clang.cindex.TypeKind.ELABORATED,
        clang.cindex.TypeKind.RECORD
    ]:
        decl = cursor_type.get_declaration()
        if decl:
            return fully_qualified(decl)
    
    # Handle template specializations
    elif cursor_type.kind == clang.cindex.TypeKind.UNEXPOSED:
        # Try to get the canonical type which might be exposed
        canonical = cursor_type.get_canonical()
        if canonical != cursor_type:
            return fully_qualified_type(canonical)
    
    return cursor_type.spelling


def fully_qualified_constructor(cursor):
    """Get fully qualified name of a constructor's class."""
    if cursor is None:
        return ''
    elif cursor.kind == clang.cindex.CursorKind.TRANSLATION_UNIT:
        return ''
    else:
        return fully_qualified(cursor.semantic_parent)

def get_nodes(node, depth=0):
    """Traverse the AST tree."""
    yield (depth, node)
    for child in node.get_children():
        yield from get_nodes(child, depth=depth+1)

def get_params_from_node(node):
    """Extract parameters from a function/method node."""
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
            
            elif child.kind in [
                clang.cindex.CursorKind.CALL_EXPR,
                clang.cindex.CursorKind.BINARY_OPERATOR,
                clang.cindex.CursorKind.UNARY_OPERATOR,
                clang.cindex.CursorKind.PAREN_EXPR,
                clang.cindex.CursorKind.UNEXPOSED_EXPR,
                clang.cindex.CursorKind.CXX_BOOL_LITERAL_EXPR,
                clang.cindex.CursorKind.INTEGER_LITERAL,
                clang.cindex.CursorKind.FLOATING_LITERAL
            ]:
                default_value = getCodeSpan(child)
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
                    default_value += ", "
                count += 1
                
                if grandchild.kind == clang.cindex.CursorKind.UNEXPOSED_EXPR:
                    if default_value is None:
                        default_value = ""
                    for token in grandchild.get_tokens():
                        default_value += token.spelling
                
                elif grandchild.kind == clang.cindex.CursorKind.CALL_EXPR:
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
                default_value += ")"
        
        # Normalize NULL to nil
        if default_value == "NULL":
            default_value = "nil"
        
        param_data = (param_name, fully_qualified_type(param_node.type), default_value)
        params.append(param_data)
    
    return params

class CppAstVisitor:
    def __init__(self, filename, enum_to_const=None):
        self.filename = filename
        self.enum_to_const = enum_to_const or []
        self.data = []
        self._current_depth = 0
        self._struct_stack = []
    
    def is_local(self, node):
        return node.location.file.name == self.filename

    def visit_all(self, cursor):
        for depth, node in get_nodes(cursor):
            self.visit(node)

    def visit(self, node):
        # Dispatch based on node kind
        if node.kind == clang.cindex.CursorKind.ENUM_DECL:
            if self.is_local(node):  return self.visit_enumdecl(node)
        elif node.kind == clang.cindex.CursorKind.TYPEDEF_DECL:
            if self.is_local(node):  return self.visit_typedefdecl(node)
        elif node.kind == clang.cindex.CursorKind.CLASS_DECL:
            if self.is_local(node):  return self.visit_classdecl(node)
        elif node.kind == clang.cindex.CursorKind.STRUCT_DECL:
            if self.is_local(node):  return self.visit_structdecl(node)
        elif node.kind == clang.cindex.CursorKind.CONSTRUCTOR:
            if self.is_local(node):  return self.visit_constructordecldef(node)
        elif node.kind == clang.cindex.CursorKind.CXX_METHOD:
            if self.is_local(node):  return self.visit_cxxmethod(node)
        elif node.kind == clang.cindex.CursorKind.FUNCTION_DECL:
            if self.is_local(node):  return self.visit_functiondecl(node)
        elif node.kind == clang.cindex.CursorKind.VAR_DECL:
            if self.is_local(node):  return self.visit_vardecl(node)
        # else:
        #     return self.generic_visit(node)
        
    # def generic_visit(self, node):
    #     for child in node.get_children():
    #         self.visit(child)
        
    def visit_enumdecl(self, node):
        if (not node.is_definition() or 
            node.location.file.name != self.filename or
            _visitedEnum.get(node.hash, False)):
            return
            
        is_const = (node.spelling == "" or node.spelling in self.enum_to_const)
        enum_data = {
            "comment": node.brief_comment,
            "type": node.enum_type.spelling,
            "name": node.spelling,
            "items": []
        }
        
        # Collect enum items first
        items = []
        for child in node.get_children():
            if child.kind == clang.cindex.CursorKind.ENUM_CONSTANT_DECL:
                items.append({
                    "name": child.spelling,
                    "comment": child.brief_comment,
                    "value": child.enum_value
                })
        
        # Sort by value if not const
        if not is_const:
            values = sorted(set(item["value"] for item in items))
            names = [item["name"] for item in items]
            new_items = []
            dup_items = []
            value2name = {}
            for value in values:
                for item in items:
                    if item["value"] == value:
                        new_items.append(item)
                        names.remove(item["name"])
                        value2name[value] = item["name"]
                        break
            
            # Handle remaining items (duplicate values)
            for name in names:
                for item in items:
                    if item["name"] == name:
                        dup_items.append({"name":name, "target":value2name[item["value"]]})
                        break
            enum_data["items"] = new_items
        else:
            enum_data["items"] = items
        
        if is_const:
            self.data.append(("const", enum_data))
        else:
            self.data.append(("enum", fully_qualified(node.referenced), enum_data))
            if dup_items: self.data.append(("enum_dup", dup_items))
        _visitedEnum[node.hash] = True
    
    def visit_typedefdecl(self, node):
        if (node.access_specifier in [
                clang.cindex.AccessSpecifier.PRIVATE,
                clang.cindex.AccessSpecifier.PROTECTED
            ] or not (node.location.file and node.location.file.name == self.filename)):
            return
            
        typedef_data = {
            "underlying": node.underlying_typedef_type.spelling,
            "typedef_type": False,
            "fully_qualified": fully_qualified(node.referenced),
            "result": node.result_type.spelling
        }
        
        typedef_data["underlying_deps"] = get_template_dependencies(typedef_data["underlying"])
        typedef_data["params"] = get_params_from_node(node)
        
        kind = node.underlying_typedef_type.kind
        
        if kind == clang.cindex.TypeKind.POINTER:
            pointee = node.underlying_typedef_type.get_pointee()
            if pointee.kind == clang.cindex.TypeKind.FUNCTIONPROTO:
                typedef_data["result"] = pointee.get_result().spelling
                typedef_data["typedef_type"] = "function"
        
        elif kind == clang.cindex.TypeKind.FUNCTIONPROTO:
            typedef_data["result"] = node.underlying_typedef_type.get_result().spelling
            typedef_data["typedef_type"] = "function"
        
        else:
            inner = node.underlying_typedef_type.get_declaration()
            
            if inner.kind == clang.cindex.CursorKind.STRUCT_DECL:
                _visitedStruct[inner.hash] = True
                typedef_data.update(self._parse_struct_inner(inner))
                typedef_data["typedef_type"] = "struct"
            
            elif inner.kind == clang.cindex.CursorKind.UNION_DECL:
                _visitedStruct[inner.hash] = True
                typedef_data.update(self._parse_struct_inner(inner))
                typedef_data["typedef_type"] = "struct"
                typedef_data["is_union"] = True
            
            elif inner.kind == clang.cindex.CursorKind.ENUM_DECL:
                if node.spelling in self.enum_to_const:
                    return
                
                _visitedEnum[inner.hash] = True
                typedef_data.update({
                    "underlying": node.underlying_typedef_type.spelling,
                    "comment": inner.brief_comment,
                    "type": inner.enum_type.spelling,
                    "name": inner.spelling,
                    "items": [],
                    "typedef_type": "enum"
                })
                
                for child in inner.get_children():
                    if child.kind == clang.cindex.CursorKind.ENUM_CONSTANT_DECL:
                        typedef_data["items"].append({
                            "name": child.spelling,
                            "comment": child.brief_comment,
                            "value": child.enum_value
                        })
        
        self.data.append(("typedef", node.spelling, typedef_data))
    
    def _parse_struct_inner(self, node):
        fields = []
        deps = []
        
        for field in node.type.get_fields():
            if field.is_anonymous():
                for subfield in field.type.get_fields():
                    fields.append({
                        "name": subfield.spelling,
                        "type": fully_qualified_type(subfield.type)
                    })
                    deps.extend(get_template_dependencies(subfield.type.spelling))
            else:
                fields.append({
                    "name": field.spelling,
                    "type": fully_qualified_type(field.type)
                })
                deps.extend(get_template_dependencies(field.type.spelling))
        
        struct_data = {
            "name": node.spelling,
            "comment": node.brief_comment,
            "base": [],
            "fully_qualified": fully_qualified(node.referenced),
            "template_params": [],
            "underlying_deps": deps,
            "fields": fields,
            "incomplete": node.type.get_size() < 0
        }
        
        for child in node.get_children():
            if child.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
                struct_data["base"].append(fully_qualified_type(child.type))
        
        return struct_data
    
    def visit_classdecl(self, node):
        if (node.access_specifier in [
                clang.cindex.AccessSpecifier.PRIVATE,
                clang.cindex.AccessSpecifier.PROTECTED
            ] or not node.is_definition() or
            node.location.file.name != self.filename):
            return
            
        class_data = {
            "name": node.spelling,
            "comment": node.brief_comment,
            "base": [],
            "fields": [],
            "fully_qualified": fully_qualified(node.referenced),
            "template_params": []
        }
        
        for child in node.get_children():
            if child.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
                class_data["base"].append(fully_qualified_type(child.type))
            elif child.kind == clang.cindex.CursorKind.TEMPLATE_TYPE_PARAMETER:
                class_data["template_params"].append(child.spelling)
            elif child.kind == clang.cindex.CursorKind.TEMPLATE_NON_TYPE_PARAMETER:
                param_info = (child.spelling, child.type.spelling)
                class_data["template_params"].append(param_info)
        
        fields = []
        for field in node.type.get_fields():
            if field.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
                continue
                
            if field.is_anonymous():
                for subfield in field.type.get_fields():
                    fields.append({
                        "name": subfield.spelling,
                        "type": fully_qualified_type(subfield.type)
                    })
            else:
                fields.append({
                    "name": field.spelling,
                    "type": fully_qualified_type(field.type)
                })
        
        class_data["fields"] = fields
        class_data.pop("name")
        self.data.append(("class", class_data["fully_qualified"], class_data))
    
    def visit_structdecl(self, node):
        if (_visitedStruct.get(node.hash, False) or
            node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE or
            not node.is_definition() or
            node.location.file.name != self.filename):
            return
            
        if node.spelling.startswith("(unnamed"):
            return
            
        struct_data = self._parse_struct_inner(node)
        if node.type.get_size() >= 0:
            self.data.append(("struct", struct_data["fully_qualified"], struct_data))
            # self.data.append(("struct", node.spelling, struct_data))
        _visitedStruct[node.hash] = True
    
    def visit_constructordecldef(self, node):
        if node.location.file.name != self.filename:
            return
            
        constructor_data = {
            "name": node.spelling,
            "class_name": node.semantic_parent.spelling,
            "comment": node.brief_comment,
            "fully_qualified": fully_qualified_constructor(node.referenced),
            "params": get_params_from_node(node)
        }
        
        self.data.append(("constructor", constructor_data["fully_qualified"], constructor_data))
    
    def visit_cxxmethod(self, node):
        if (node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE or
            node.location.file.name != self.filename):
            return
            
        name = node.spelling
        if name.startswith("operator"):
            op = name[8:]
            if re.match(r"[\[\]!+\-=*\^/]+", op):
                name = f"`{op}`"
            else:
                return
        
        method_data = {
            "name": name,
            "fully_qualified": fully_qualified(node.referenced),
            "result": node.result_type.spelling,
            "class_name": node.semantic_parent.spelling,
            "const_method": node.is_const_method(),
            "comment": node.brief_comment,
            "plain_function": False,
            "file_origin": node.location.file.name,
            "params": get_params_from_node(node),
            "result_deps": get_template_dependencies(node.result_type.spelling)
        }
        
        self.data.append(("method", method_data["fully_qualified"], method_data))
    
    def visit_functiondecl(self, node):
        if node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
            return
            
        name = node.spelling
        if name.startswith("operator"):
            return
            
        method_data = {
            "name": name,
            "fully_qualified": fully_qualified(node.referenced),
            "result": node.result_type.spelling,
            "class_name": "",
            "const_method": False,
            "comment": node.brief_comment,
            "plain_function": True,
            "file_origin": node.location.file.name,
            "params": get_params_from_node(node),
            "result_deps": get_template_dependencies(node.result_type.spelling)
        }
        
        self.data.append(("method", method_data["fully_qualified"], method_data))
    
    def visit_vardecl(self, node):
        if (node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE or
            node.type.kind != clang.cindex.TypeKind.TYPEDEF or
            node.location.file.name != self.filename):
            return
            
        vtype_decl = node.type.get_declaration()
        pointee = vtype_decl.underlying_typedef_type.get_pointee()
        
        if pointee.kind != clang.cindex.TypeKind.FUNCTIONPROTO:
            return
            
        method_data = {
            "name": node.spelling,
            "fully_qualified": fully_qualified(node.referenced),
            "result": pointee.get_result().spelling,
            "class_name": "",
            "const_method": False,
            "comment": "",
            "plain_function": True,
            "file_origin": node.location.file.name,
            "params": get_params_from_node(vtype_decl),
            "result_deps": get_params_from_node(pointee.get_result().spelling)
        }
        
        self.data.append(("method", method_data["fully_qualified"], method_data))


def _find_depends_on(filename, data):
    """Find all dependencies in the file."""
    dependencies = []
    
    for item in data:
        if len(item) != 4:
            continue
            
        item_filename, item_type, item_name, item_values = item
        
        if item_filename != filename:
            continue
        
        if item_type in ["method", "constructor"]:
            # Add parameter types as dependencies
            for param_name, param_type, param_default in item_values["params"]:
                template_deps = get_template_dependencies(param_type)
                if template_deps:
                    dependencies.extend(template_deps)
                else:
                    dependencies.append(cleanit(param_type))
                
                if param_default is not None:
                    dependencies.append(param_default)
            
            # Add return type as dependency
            if "result" in item_values and item_values["result"] is not None:
                if item_values.get("result_deps"):
                    dependencies.extend(item_values["result_deps"])
                else:
                    dependencies.append(cleanit(item_values["result"]))
        
        elif item_type == "typedefs":
            if item_values.get("underlying_deps"):
                dependencies.extend(item_values["underlying_deps"])
            else:
                dependencies.append(cleanit(item_values["underlying"]))
        
        elif item_type == "class" and "template_params" in item_values:
            # Add template parameter types as dependencies
            for param in item_values["template_params"]:
                if isinstance(param, tuple):
                    dependencies.append(param[1])
        
        elif item_type == "struct":
            for field_name, field_type in item_values["fields"]:
                dependencies.append(field_type)
    
    return set(dependencies)

def _find_provided(filename, data, dependencies):
    """Find all types that the file provides to others."""
    provides = []
    
    for item in data:
        if len(item) != 4:
            continue
            
        item_filename, item_type, item_name, item_values = item
        
        if item_filename != filename:
            continue
        
        if item_type == "const":
            for const_item in item_values["items"]:
                if const_item["name"] in dependencies:
                    provides.append(const_item["name"])
        
        elif item_type == "enum":
            for enum_item in item_values["items"]:
                provides.append((enum_item["name"], item_name))
            provides.append(item_name)
        
        elif item_type in ["class", "struct", "typedef"]:
            provides.append(item_values["fully_qualified"])
    
    return set(provides)

def _missing_dependencies(filename, data, dependencies, provides):
    """Find dependencies that are not provided by the file."""
    missing = set()
    
    for dep in dependencies:
        if dep in NORMAL_TYPES:
            continue
            
        if dep in provides:
            continue
            
        # Check if dependency is provided as part of an enum
        provided_enum_values = [k[0] for k in provides if isinstance(k, tuple)]
        if dep in provided_enum_values:
            continue
            
        missing.add(dep)
    
    return missing


def parse_include_file(filename, dependsOn, provides, search_paths=None, extra_args=None, 
                      enum_to_const=None, c_mode=False):
    """Parse a single include file using visitor pattern."""
    if search_paths is None:
        search_paths = []
    if extra_args is None:
        extra_args = []
    if enum_to_const is None:
        enum_to_const = []
        
    # Create Clang index
    index = clang.cindex.Index.create()
    
    # Prepare arguments for parsing
    args = []
    if c_mode:
        args += ['-x', 'c']
    else:
        args += ['-x', 'c++', '-std=c++17']
    
    args += extra_args
    args += [f"-I{path}" for path in search_paths]
    
    # Parse options
    opts = (
            clang.cindex.TranslationUnit.PARSE_SKIP_FUNCTION_BODIES 
            | clang.cindex.TranslationUnit.PARSE_PRECOMPILED_PREAMBLE
            | clang.cindex.TranslationUnit.PARSE_CACHE_COMPLETION_RESULTS
            )
    
    # Parse the file
    tu = index.parse(filename, args, None, opts)
    
    # Create and run visitor
    visitor = CppAstVisitor(filename, enum_to_const)
    visitor.visit_all(tu.cursor)
    
    # Process visitor data into expected format
    data = [(filename, item[0], *item[1:]) for item in visitor.data]
    
    # Find dependencies
    deps = _find_depends_on(filename, data)
    provs = _find_provided(filename, data, deps)
    missing = _missing_dependencies(filename, data, deps, provs)
    
    return data, deps, provs, missing


# 替换do_parse函数中的worker函数和相关日志设置
def do_parse(root, folders, dest, search_paths=None, extra_args=None, ignore=None, 
            enum_to_const=None, c_mode=False):
    """Parse multiple include files and save the results."""
    
    if search_paths is None:
        search_paths = []
    if extra_args is None:
        extra_args = []
    if ignore is None:
        ignore = []
    if enum_to_const is None:
        enum_to_const = []
    
    # 设置日志
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(threadName)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )
    logger = logging.getLogger(__name__)
    
    # Get the list of files to parse
    files_to_parse = []
    dirs = []
    
    for folder in folders:
        all_files = glob.glob(folder, recursive=True)
        files_to_parse.extend([f for f in all_files if os.path.isfile(f)])
        dirs.extend([d for d in all_files if not os.path.isfile(d)])
    
    logger.info(f"Root folder: {root}")
    
    # Create output directories
    path = os.getcwd()
    delete_folder = os.path.join(dest, "__parsed")
    destination_folder = os.path.join(path, dest)
    
    if not os.path.isdir(destination_folder):
        os.mkdir(destination_folder)
    if not os.path.isdir(delete_folder):
        os.mkdir(delete_folder)
    
    # Create subdirectories matching the source structure
    for dir_path in dirs:
        rel_path = os.path.relpath(dir_path, root)
        folder_path = os.path.join(dest, rel_path)
        Path(folder_path).mkdir(parents=True, exist_ok=True)
    
    # Remove files in ignore list
    files_to_parse = [f for f in files_to_parse if f not in ignore]
    total_files = len(files_to_parse)
    
    # Shared data structures protected by a lock
    lock = threading.Lock()
    parsed_data = []
    depends_on = {}
    provides = {}
    missing = {}
    
    # Worker function for thread pool
    def worker():
        thread_logger = logging.getLogger(f"{__name__}.worker.{threading.current_thread().name}")
        
        while True:
            try:
                task = task_queue.get(block=False)
                if task is None:  # Sentinel to stop worker
                    break
                    
                idx, include_file = task
                thread_logger.info(f"Parsing ({idx}/{total_files}): {include_file}")
                
                try:
                    data, deps, provs, miss = parse_include_file(
                        include_file,
                        depends_on, provides,  # Use the shared dictionaries
                        search_paths=search_paths,
                        extra_args=extra_args,
                        enum_to_const=enum_to_const,
                        c_mode=c_mode
                    )
                    
                    with lock:
                        parsed_data.extend(data)
                        depends_on[include_file] = deps
                        provides[include_file] = provs
                        missing[include_file] = miss
                        
                except Exception as e:
                    thread_logger.error(f"Error parsing {include_file}: {str(e)}", exc_info=True)
                
                task_queue.task_done()
            except queue.Empty:
                time.sleep(0.1)  # Small sleep to reduce CPU usage in the polling loop
    
    # Create task queue and workers
    task_queue = queue.Queue()
    
    # Determine number of worker threads (use fewer than CPU count to prevent resource contention)
    num_workers = 1
    # num_workers = max(1, multiprocessing.cpu_count() // 2)
    logger.info(f"Using {num_workers} worker threads")
    
    # Start worker threads
    threads = []
    for i in range(num_workers):
        t = threading.Thread(target=worker, name=f"Worker-{i+1}")
        t.daemon = True
        t.start()
        threads.append(t)
    
    # Add tasks to queue
    for idx, f in enumerate(files_to_parse, 1):
        task_queue.put((idx, f))
    
    # Wait for all tasks to complete
    task_queue.join()
    
    # Stop workers
    for _ in range(num_workers):
        task_queue.put(None)
    
    # Wait for all worker threads to finish
    for t in threads:
        t.join()
    
    # Save results
    result = {
        "includes": parsed_data,
        "dependsOn": depends_on,
        "provides": provides,
        "missing": missing
    }
    
    import pickle
    pickle_path = os.path.join(delete_folder, 'files.pickle')
    logger.info(f"Saving results to {pickle_path}")
    with open(pickle_path, 'wb') as fp:
        pickle.dump(result, fp)


def main():
    # Parse command line arguments
    if len(sys.argv) < 3:
        print("Usage: parse_headers.py <glob_pattern> <destination>")
        sys.exit(1)
        
    folder = sys.argv[1]
    dest = sys.argv[2]
    root = get_root(folder)
    
    do_parse(root, [folder], dest)

if __name__ == '__main__':
    main()