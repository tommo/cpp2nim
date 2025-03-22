#!/usr/bin/env python
"""
C++ header parser for generating Nim bindings.

Usage examples:
  python parse_headers.py "/usr/include/opencascade/gp_*.hxx" occt
  python parse_headers.py "/usr/include/osg/**/*" osg
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

# Global state
_visitedEnum = {}
_visitedStruct = {}
files = {}

# Nim keywords to avoid name collisions
NIM_KEYWORDS = ["addr", "and", "as", "asm", "bind", "block", "break",
                "case", "cast", "concept", "const", "continue", "converter",
                "defer", "discard", "distinct", "div", "do", "elif", "else",
                "end", "enum", "except", "export", "finally", "for", "from",
                "func", "if", "import", "in", "include", "interface", "is",
                "isnot", "iterator", "let", "macro", "method", "mixin", "mod",
                "nil", "not", "notin", "object", "of", "or", "out", "proc", "ptr",
                "raise", "ref", "return", "shl", "shr", "static", "template",
                "try", "tuple", "type", "using", "var", "when", "while", "xor",
                "yield"]

# Common C/C++ types that don't need special handling
NORMAL_TYPES = ["void", "long", "unsigned long", "int", "size_t", "long long", "long double", 
                "float", "double", "char", "signed char", "unsigned char", "unsigned short", 
                "unsigned int", "unsigned long long", "char*", "bool"]

PRINT_STRUCT = False

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
        
        params.append((param_name, param_node.type.spelling, default_value))
    
    return params

def _parse_enums(filename, tu, enum_to_const=None):
    """Extract enum declarations from translation unit."""
    if enum_to_const is None:
        enum_to_const = []
        
    consts = []
    repeated = {}
    enums = {}
    
    for depth, node in get_nodes(tu.cursor):
        if (node.kind != clang.cindex.CursorKind.ENUM_DECL or
            not node.is_definition() or
            node.location.file.name != filename or
            _visitedEnum.get(node.hash, False)):
            continue
            
        is_const = (node.spelling == "" or node.spelling in enum_to_const)
        
        enum_data = {
            "comment": node.brief_comment,
            "type": node.enum_type.spelling,
            "name": node.spelling,
            "items": []
        }
        
        for _, enum_const in get_nodes(node, depth):
            if enum_const.kind == clang.cindex.CursorKind.ENUM_CONSTANT_DECL:
                enum_data["items"].append({
                    "name": enum_const.spelling,
                    "comment": enum_const.brief_comment,
                    "value": enum_const.enum_value
                })
        
        if is_const:
            consts.append(enum_data)
        else:
            # Sort enum values
            values = sorted(set(item["value"] for item in enum_data["items"]))
            names = [item["name"] for item in enum_data["items"]]
            
            new_items = []
            for value in values:
                for item in enum_data["items"]:
                    if item["value"] == value:
                        new_items.append(item)
                        names.remove(item["name"])
                        break
            
            for name in names:
                for item in enum_data["items"]:
                    if item["name"] == name:
                        repeated[name] = item
            
            enum_data["items"] = new_items
            enums[fully_qualified(node.referenced)] = enum_data
    
    return consts, enums, repeated

def _parse_typedef(filename, tu, enum_to_const=None):
    """Extract typedef declarations from translation unit."""
    if enum_to_const is None:
        enum_to_const = []
        
    typedefs = {}
    
    for depth, node in get_nodes(tu.cursor):
        if (node.access_specifier in [
                clang.cindex.AccessSpecifier.PRIVATE,
                clang.cindex.AccessSpecifier.PROTECTED
            ] or
            not (node.location.file and node.location.file.name == filename)):
            continue
        
        if node.kind == clang.cindex.CursorKind.TYPE_REF:
            ref_kind = node.referenced.kind
            name = node.referenced.spelling
            
            if ref_kind in [
                clang.cindex.CursorKind.ENUM_DECL,
                clang.cindex.CursorKind.TYPEDEF_DECL
            ]:
                continue
                
            typedef_data = {
                "underlying": node.displayname,
                "typedef_type": "ref",
                "fully_qualified": fully_qualified(node.referenced),
                "result": node.result_type.spelling
            }
            # typedefs[name] = typedef_data
        
        elif node.kind == clang.cindex.CursorKind.TYPEDEF_DECL:
            name = node.displayname
            
            typedef_data = {
                "underlying": node.underlying_typedef_type.spelling,
                "typedef_type": False,
                "fully_qualified": fully_qualified(node.referenced),
                "result": node.result_type.spelling
            }
            
            # Extract underlying dependencies
            typedef_data["underlying_deps"] = get_template_dependencies(typedef_data["underlying"])
            
            # Extract parameters if this is a function typedef
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
                    typedef_data = _parse_struct_inner(inner, 0)
                    typedef_data["typedef_type"] = "struct"
                    typedef_data["fully_qualified"] = fully_qualified(node.referenced)
                
                elif inner.kind == clang.cindex.CursorKind.UNION_DECL:
                    _visitedStruct[inner.hash] = True
                    typedef_data = _parse_struct_inner(inner, 0)
                    typedef_data["typedef_type"] = "struct"
                    typedef_data["fully_qualified"] = fully_qualified(node.referenced)
                    typedef_data["is_union"] = True
                
                elif inner.kind == clang.cindex.CursorKind.ENUM_DECL:
                    if node.spelling in enum_to_const:
                        # Let enum body handle this
                        continue
                    
                    _visitedEnum[inner.hash] = True
                    typedef_data = {
                        "underlying": node.underlying_typedef_type.spelling,
                        "comment": inner.brief_comment,
                        "type": inner.enum_type.spelling,
                        "name": inner.spelling,
                        "items": [],
                        "fully_qualified": fully_qualified(node.referenced),
                        "typedef_type": "enum"
                    }
                    
                    for _, enum_const in get_nodes(inner, depth):
                        if enum_const.kind == clang.cindex.CursorKind.ENUM_CONSTANT_DECL:
                            typedef_data["items"].append({
                                "name": enum_const.spelling,
                                "comment": enum_const.brief_comment,
                                "value": enum_const.enum_value
                            })
            
            typedefs[name] = typedef_data
    
    return typedefs

def _parse_class_inner(node, depth):
    """Parse the internals of a class declaration."""
    class_data = {
        "name": node.spelling,
        "comment": node.brief_comment,
        "base": [],
        "fields": [],
        "fully_qualified": fully_qualified(node.referenced),
        "template_params": []
    }
    
    # Extract base classes
    for _, base_node in get_nodes(node, depth):
        if base_node.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
            class_data["base"].append(base_node.displayname)
    
    # Extract template parameters
    if node.kind == clang.cindex.CursorKind.CLASS_TEMPLATE:
        for _, template_param in get_nodes(node, depth):
            if template_param.kind == clang.cindex.CursorKind.TEMPLATE_TYPE_PARAMETER:
                class_data["template_params"].append(template_param.spelling)
            elif template_param.kind == clang.cindex.CursorKind.TEMPLATE_NON_TYPE_PARAMETER:
                param_info = (template_param.spelling, template_param.type.spelling)
                class_data["template_params"].append(param_info)
            elif template_param.kind in [
                clang.cindex.CursorKind.CLASS_TEMPLATE,
                clang.cindex.CursorKind.TYPE_REF
            ]:
                pass
            else:
                break
    
    # Extract fields
    fields = []
    for field in node.type.get_fields():
        if field.access_specifier == clang.cindex.AccessSpecifier.PRIVATE:
            continue
            
        if field.is_anonymous():
            for subfield in field.type.get_fields():
                if PRINT_STRUCT:
                    print(f" []:{subfield.spelling} {subfield.type.spelling}")
                fields.append({
                    "name": subfield.spelling,
                    "type": subfield.type.spelling
                })
        else:
            if PRINT_STRUCT:
                print(f" {field.spelling} {field.type.spelling}")
            fields.append({
                "name": field.spelling,
                "type": field.type.spelling
            })
    
    class_data["fields"] = fields
    class_data.pop("name")  # Remove redundant name field
    
    return class_data

def _parse_class(filename, tu):
    """Parse class declarations from translation unit."""
    classes = {}
    
    for depth, node in get_nodes(tu.cursor):
        if (node.access_specifier in [
                clang.cindex.AccessSpecifier.PRIVATE,
                clang.cindex.AccessSpecifier.PROTECTED
            ] or
            node.kind not in [
                clang.cindex.CursorKind.CLASS_DECL,
                clang.cindex.CursorKind.CLASS_TEMPLATE
            ] or
            not node.is_definition() or
            node.location.file.name != filename):
            continue
        
        class_name = node.spelling
        class_data = _parse_class_inner(node, depth)
        classes[class_name] = class_data
    
    return classes

def _parse_struct_inner(node, depth):
    """Parse the internals of a struct declaration."""
    fields = []
    deps = []
    
    if PRINT_STRUCT:
        print(f">>>>>>parse_struct {node.spelling} {node.kind} {node.type.kind}")
    
    for field in node.type.get_fields():
        if field.is_anonymous():
            for subfield in field.type.get_fields():
                if PRINT_STRUCT:
                    print(f" []:{subfield.spelling} {subfield.type.spelling}")
                fields.append({
                    "name": subfield.spelling,
                    "type": subfield.type.spelling
                })
                deps.extend(get_template_dependencies(subfield.type.spelling))
        else:
            if PRINT_STRUCT:
                print(f" {field.spelling} {field.type.spelling}")
            fields.append({
                "name": field.spelling,
                "type": field.type.spelling
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
    
    # Extract base classes
    for _, base_node in get_nodes(node, depth):
        if base_node.kind == clang.cindex.CursorKind.CXX_BASE_SPECIFIER:
            struct_data["base"].append(base_node.displayname)
    
    return struct_data

def _parse_struct(filename, tu):
    """Parse struct declarations from translation unit."""
    structs = {}
    
    for depth, node in get_nodes(tu.cursor):
        if (_visitedStruct.get(node.hash, False) or
            node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE or
            node.kind != clang.cindex.CursorKind.STRUCT_DECL or
            not node.is_definition() or
            node.location.file.name != filename):
            continue
        
        struct_name = node.spelling
        
        # Skip if we've already processed a complete definition
        if (not node.is_definition()) and (struct_name in structs):
            continue
        
        struct_data = _parse_struct_inner(node, depth)
        
        # Only add complete structs
        if node.type.get_size() >= 0:
            structs[struct_name] = struct_data
    
    return structs

def _parse_constructors(filename, tu):
    """Parse constructor declarations from translation unit."""
    constructors = []
    
    for depth, node in get_nodes(tu.cursor):
        if (node.kind != clang.cindex.CursorKind.CONSTRUCTOR or
            node.location.file.name != filename):
            continue
        
        constructor_data = {
            "name": node.spelling,
            "class_name": node.semantic_parent.spelling,
            "comment": node.brief_comment,
            "fully_qualified": fully_qualified_constructor(node.referenced),
            "params": get_params_from_node(node)
        }
        
        constructors.append(constructor_data)
    
    return constructors

def _parse_methods(filename, tu):
    """Parse method and function declarations from translation unit."""
    methods = []
    
    # First pass: handle variable declarations that are function pointers
    for depth, node in get_nodes(tu.cursor):
        if (node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE or
            node.kind != clang.cindex.CursorKind.VAR_DECL or
            node.type.kind != clang.cindex.TypeKind.TYPEDEF or
            node.location.file.name != filename):
            continue
        
        vtype_decl = node.type.get_declaration()
        pointee = vtype_decl.underlying_typedef_type.get_pointee()
        
        if pointee.kind != clang.cindex.TypeKind.FUNCTIONPROTO:
            continue
        
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
            "result_deps": get_template_dependencies(pointee.get_result().spelling)
        }
        
        methods.append(method_data)
    
    # Second pass: handle methods and functions
    for depth, node in get_nodes(tu.cursor):
        if (node.access_specifier == clang.cindex.AccessSpecifier.PRIVATE or
            node.kind not in [
                clang.cindex.CursorKind.CXX_METHOD,
                clang.cindex.CursorKind.FUNCTION_DECL
            ] or
            node.location.file.name != filename):
            continue
        
        name = node.spelling
        
        # Handle operator overloads
        if name.startswith("operator"):
            op = name[8:]
            if re.match(r"[\[\]!+\-=*\^/]+", op):
                name = f"`{op}`"
        
        method_data = {
            "name": name,
            "fully_qualified": fully_qualified(node.referenced),
            "result": node.result_type.spelling,
            "class_name": node.semantic_parent.spelling,
            "const_method": node.is_const_method(),
            "comment": node.brief_comment,
            "plain_function": node.kind == clang.cindex.CursorKind.FUNCTION_DECL,
            "file_origin": node.location.file.name,
            "params": get_params_from_node(node),
            "result_deps": get_template_dependencies(node.result_type.spelling)
        }
        
        methods.append(method_data)
    
    return methods

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
    """Parse a single include file and return its data."""
    if search_paths is None:
        search_paths = []
    if extra_args is None:
        extra_args = []
    if enum_to_const is None:
        enum_to_const = []
        
    data = []
    
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
    
    print(args)
    
    # Parse options
    opts = (clang.cindex.TranslationUnit.PARSE_DETAILED_PROCESSING_RECORD |
            clang.cindex.TranslationUnit.PARSE_PRECOMPILED_PREAMBLE |
            clang.cindex.TranslationUnit.PARSE_SKIP_FUNCTION_BODIES |
            clang.cindex.TranslationUnit.PARSE_INCOMPLETE)
    
    # Parse the file
    tu = index.parse(filename, args, None, opts)
    
    # Print diagnostics
    for diag in tu.diagnostics:
        print(diag)
    
    # Parse typedefs
    typedefs = _parse_typedef(filename, tu, enum_to_const=enum_to_const)
    for key, value in typedefs.items():
        data.append((filename, "typedef", key, value))
    
    # Parse enums
    consts, enums, repeated = _parse_enums(filename, tu, enum_to_const=enum_to_const)
    for const in consts:
        data.append((filename, "const", const))
    for key, value in enums.items():
        data.append((filename, "enum", key, value))
    for key, value in repeated.items():
        data.append((filename, "repeated", key, value))
    
    # Parse classes
    classes = _parse_class(filename, tu)
    for key, value in classes.items():
        data.append((filename, "class", key, value))
    
    # Parse structs
    structs = _parse_struct(filename, tu)
    for key, value in structs.items():
        data.append((filename, "struct", key, value))
    
    # Parse constructors
    constructors = _parse_constructors(filename, tu)
    for constructor in constructors:
        data.append((filename, "constructor", constructor["fully_qualified"], constructor))
    
    # Parse methods
    methods = _parse_methods(filename, tu)
    for method in methods:
        data.append((filename, "method", method["fully_qualified"], method))
    
    # Find dependencies
    deps = _find_depends_on(filename, data)
    
    # Find provided types
    provs = _find_provided(filename, data, deps)
    
    # Find missing dependencies
    missing = _missing_dependencies(filename, data, deps, provs)
    
    return data, deps, provs, missing

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
    
    # Get the list of files to parse
    files_to_parse = []
    dirs = []
    
    for folder in folders:
        all_files = glob.glob(folder, recursive=True)
        files_to_parse.extend([f for f in all_files if os.path.isfile(f)])
        dirs.extend([d for d in all_files if not os.path.isfile(d)])
    
    print(f"Root folder: {root}")
    
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
    
    # Parse all files
    parsed_data = []
    depends_on = {}
    provides = {}
    missing = {}
    
    total_files = len(files_to_parse)
    for i, include_file in enumerate(files_to_parse, 1):
        if include_file in ignore:
            continue
            
        print(f"Parsing ({i}/{total_files}): {include_file}")
        
        data, deps, provs, miss = parse_include_file(
            include_file, depends_on, provides,
            search_paths=search_paths,
            extra_args=extra_args,
            enum_to_const=enum_to_const,
            c_mode=c_mode
        )
        
        parsed_data.extend(data)
        depends_on[include_file] = deps
        provides[include_file] = provs
        missing[include_file] = miss
    
    # Save results
    result = {
        "includes": parsed_data,
        "dependsOn": depends_on,
        "provides": provides,
        "missing": missing
    }
    
    import pickle
    pickle_path = os.path.join(delete_folder, 'files.pickle')
    with open(pickle_path, 'wb') as fp:
        pickle.dump(result, fp)

class Unbuffered:
    """Wrapper to unbuffer stdout."""
    def __init__(self, stream):
        self.stream = stream
        
    def write(self, data):
        self.stream.write(data)
        self.stream.flush()
        
    def writelines(self, datas):
        self.stream.writelines(datas)
        self.stream.flush()
        
    def __getattr__(self, attr):
        return getattr(self.stream, attr)

def main():
    """Main entry point."""
    # Unbuffer stdout
    sys.stdout = Unbuffered(sys.stdout)
    
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