"""
Utility functions for cpp2nim.

This module consolidates utility functions that were previously duplicated
across parse_headers.py, export.py, and analize.py.
"""

import re
import textwrap
from typing import Any

import clang.cindex


# Nim keywords that need escaping with backticks
NIM_KEYWORDS = frozenset([
    "addr", "and", "as", "asm", "bind", "block", "break",
    "case", "cast", "concept", "const", "continue", "converter",
    "defer", "discard", "distinct", "div", "do", "elif", "else",
    "end", "enum", "except", "export", "finally", "for", "from",
    "func", "if", "import", "in", "include", "interface", "is",
    "isnot", "iterator", "let", "macro", "method", "mixin", "mod",
    "nil", "not", "notin", "object", "of", "or", "out", "proc", "ptr",
    "raise", "ref", "return", "shl", "shr", "static", "template",
    "try", "tuple", "type", "using", "var", "when", "while", "xor",
    "yield", "array"
])

# C/C++ primitive types
NORMAL_TYPES = frozenset([
    "void", "long", "unsigned long", "int", "size_t", "long long", "long double",
    "float", "double", "char", "signed char", "unsigned char", "unsigned short",
    "unsigned int", "unsigned long long", "char*", "bool"
])


def escape_nim_keyword(name: str) -> str:
    """Escape a name if it's a Nim keyword.
    
    Args:
        name: The identifier name.
        
    Returns:
        The name with backticks if it's a keyword, otherwise unchanged.
        
    Example:
        >>> escape_nim_keyword("type")
        '`type`'
        >>> escape_nim_keyword("myVar")
        'myVar'
    """
    if name in NIM_KEYWORDS:
        return f"`{name}`"
    return name


def clean_identifier(name: str) -> str:
    """Clean an identifier for Nim output.
    
    Args:
        name: The identifier to clean.
        
    Returns:
        Cleaned identifier suitable for Nim.
        
    Example:
        >>> clean_identifier("_internal")
        'v_internal'
        >>> clean_identifier("type")
        '`type`'
    """
    if not name:
        return name
    if name.startswith("_"):
        name = "v_" + name[1:]
    return escape_nim_keyword(name)


def clean_type_name(type_name: str) -> str:
    """Remove const qualifiers and clean a C++ type name.
    
    Args:
        type_name: The C++ type name.
        
    Returns:
        Cleaned type name.
        
    Example:
        >>> clean_type_name("const int &")
        'int'
        >>> clean_type_name("const char *")
        'char'
    """
    result = type_name
    if result.endswith("const *"):
        result = result[:-7] + "*"
    if result.startswith("const "):
        result = result[6:]
    if result and result[-1] in ["&", "*"]:
        result = result[:-2] if len(result) > 1 else result[:-1]
    return result.strip()


def get_fully_qualified_name(cursor: clang.cindex.Cursor) -> str:
    """Get the fully qualified name of a Clang cursor.
    
    Args:
        cursor: A Clang AST cursor.
        
    Returns:
        Fully qualified name like "namespace::Class::member".
        
    Example:
        >>> # For a cursor pointing to std::vector::push_back
        >>> get_fully_qualified_name(cursor)
        'std::vector::push_back'
    """
    if cursor is None:
        return ''
    if cursor.kind == clang.cindex.CursorKind.TRANSLATION_UNIT:
        return ''
    
    parent = get_fully_qualified_name(cursor.semantic_parent)
    if parent:
        return parent + '::' + cursor.spelling
    return cursor.spelling


def get_fully_qualified_type(cursor_type: clang.cindex.Type) -> str:
    """Get fully qualified name for a type, preserving templates, const, etc.
    
    Args:
        cursor_type: A Clang type.
        
    Returns:
        Fully qualified type name with template arguments preserved.
    """
    const_str = "const " if cursor_type.is_const_qualified() else ""
    
    # Handle pointer types
    if cursor_type.kind == clang.cindex.TypeKind.POINTER:
        pointee = cursor_type.get_pointee()
        return f"{get_fully_qualified_type(pointee)}*{const_str.strip()}"
    
    # Handle reference types
    if cursor_type.kind == clang.cindex.TypeKind.LVALUEREFERENCE:
        ref = cursor_type.get_pointee()
        return f"{get_fully_qualified_type(ref)}&{const_str.strip()}"
    
    # Handle arrays
    if cursor_type.kind in [clang.cindex.TypeKind.CONSTANTARRAY,
                            clang.cindex.TypeKind.INCOMPLETEARRAY]:
        element_type = cursor_type.get_array_element_type()
        array_size = ""
        if cursor_type.kind == clang.cindex.TypeKind.CONSTANTARRAY:
            array_size = str(cursor_type.get_array_size())
        return f"{get_fully_qualified_type(element_type)}[{array_size}]{const_str.strip()}"
    
    # Handle template specializations
    if cursor_type.kind == clang.cindex.TypeKind.UNEXPOSED:
        decl = cursor_type.get_declaration()
        if decl and decl.kind == clang.cindex.CursorKind.CLASS_TEMPLATE:
            template_args = []
            for i in range(cursor_type.get_num_template_arguments()):
                arg = cursor_type.get_template_argument_type(i)
                template_args.append(get_fully_qualified_type(arg))
            return f"{const_str}{get_fully_qualified_name(decl)}<{', '.join(template_args)}>"
    
    # Handle regular types
    if cursor_type.kind in [
        clang.cindex.TypeKind.TYPEDEF,
        clang.cindex.TypeKind.RECORD,
        clang.cindex.TypeKind.ELABORATED
    ]:
        decl = cursor_type.get_declaration()
        if decl:
            tvar_count = cursor_type.get_num_template_arguments()
            if tvar_count > 0:
                template_args = []
                for i in range(tvar_count):
                    arg = cursor_type.get_template_argument_type(i)
                    template_args.append(get_fully_qualified_type(arg))
                return f"{const_str}{get_fully_qualified_name(decl)}<{', '.join(template_args)}>"
            return const_str + get_fully_qualified_name(decl)
    
    # Fallback to spelling
    return const_str + cursor_type.spelling


def get_template_dependencies(type_name: str) -> list[str]:
    """Extract template parameter dependencies from a type.
    
    Args:
        type_name: A C++ type name that may contain template parameters.
        
    Returns:
        List of dependent type names extracted from template arguments.
        
    Example:
        >>> get_template_dependencies("std::vector<MyClass>")
        ['std::vector', 'MyClass']
        >>> get_template_dependencies("std::map<K, V>")
        ['std::map', 'K', 'V']
    """
    result = []
    cleaned = clean_type_name(type_name)
    
    # Handle nested templates
    if '<' in cleaned and cleaned.endswith('>'):
        # Split into base type and parameters
        base, params = cleaned.split('<', 1)
        params = params[:-1]  # Remove trailing '>'
        
        # Add base type (e.g., "vector" from "vector<int>")
        result.append(base.strip())
        
        # Parse individual parameters
        depth = 0
        current_param: list[str] = []
        for c in params:
            if c == '<':
                depth += 1
                current_param.append(c)
            elif c == '>':
                depth -= 1
                current_param.append(c)
            elif c == ',' and depth == 0:
                param = ''.join(current_param).strip()
                if param:
                    result.extend(get_template_dependencies(param))
                current_param = []
            else:
                current_param.append(c)
        
        # Add last parameter
        if current_param:
            param = ''.join(current_param).strip()
            if param:
                result.extend(get_template_dependencies(param))
    else:
        # Non-template type
        result.append(cleaned)
    
    return [r for r in result if r and not r.isdigit()]


def flatten_namespace(name: str) -> str:
    """Convert NS1::NS2::Name to NS2_Name.
    
    Args:
        name: A fully qualified C++ name.
        
    Returns:
        Flattened name suitable for Nim.
        
    Example:
        >>> flatten_namespace("std::vector")
        'std_vector'
        >>> flatten_namespace("boost::asio::ip::tcp")
        'ip_tcp'
    """
    if not name or '::' not in name:
        return name
    
    parts = name.split('::')
    # Take last two parts if available
    if len(parts) >= 2:
        return f"{parts[-2]}_{parts[-1]}"
    return parts[-1]


def get_code_span(cursor: clang.cindex.Cursor, file_cache: dict[str, list[str]]) -> str:
    """Extract source code text for a cursor.
    
    Args:
        cursor: A Clang AST cursor.
        file_cache: Cache of file contents (filename -> lines).
        
    Returns:
        The source text for the cursor's extent.
    """
    if not cursor.location.file:
        return ""
    
    filename = cursor.location.file.name
    extent = cursor.extent
    
    if filename not in file_cache:
        try:
            with open(filename, 'r') as fp:
                file_cache[filename] = fp.readlines()
        except Exception:
            return ""
    
    lines = file_cache[filename]
    if not lines:
        return ""
    
    line_idx = extent.start.line - 1
    if line_idx >= len(lines):
        return ""
    
    off0 = extent.start.column - 1
    off1 = extent.end.column - 1
    
    if extent.start.line < extent.end.line:
        off1 = -1
    
    line = lines[line_idx]
    if off1 < 0:
        return line[off0:]
    return line[off0:off1]


def get_template_parameters(method_name: str) -> tuple[str, str]:
    """Extract template parameters from a method name.
    
    Args:
        method_name: A method name that may include template parameters.
        
    Returns:
        Tuple of (base_name, template_params_string).
        
    Example:
        >>> get_template_parameters("push_back<T>")
        ('push_back', '[T]')
        >>> get_template_parameters("foo")
        ('foo', '')
    """
    if '<' in method_name and method_name[-1] == '>':
        name, params = method_name.split('<', 1)
        params = params[:-1]  # Remove trailing '>'
        return (name, f"[{params}]")
    return (method_name, '')


def format_comment(comment: str | None, indent: int = 4) -> str:
    """Format a comment for Nim output.
    
    Args:
        comment: The comment text, or None.
        indent: Number of spaces for indentation.
        
    Returns:
        Formatted Nim doc comment string.
        
    Example:
        >>> format_comment("This is a function", 4)
        '    ## This is a function\\n'
    """
    if not comment:
        return ""
    
    spc = " " * indent
    result = ""
    comment_lines = textwrap.fill(comment, width=70).split("\n")
    for line in comment_lines:
        result += f"{spc}## {line}\n"
    return result


def get_root_from_glob(pattern: str) -> str:
    """Get the root directory from a glob pattern.
    
    Args:
        pattern: A file glob pattern.
        
    Returns:
        The root directory portion without wildcards.
        
    Example:
        >>> get_root_from_glob("/usr/include/*.h")
        '/usr/include/'
        >>> get_root_from_glob("/path/to/file.h")
        '/path/to/'
    """
    # Case where a specific file is given (no glob)
    if "*" not in pattern and "?" not in pattern:
        parts = pattern.split("/")
        return "/".join(parts[:-1]) + "/"
    
    # Glob case
    parts = pattern.split("/")
    result = ""
    for part in parts:
        if "*" not in part and "?" not in part:
            result += part + "/"
        else:
            break
    return result


def flatten_list(nested: list[Any]) -> list[Any]:
    """Flatten a nested list structure.
    
    Args:
        nested: A potentially nested list.
        
    Returns:
        Flattened list.
        
    Example:
        >>> flatten_list([[1, 2], [3, [4, 5]]])
        [1, 2, 3, 4, 5]
    """
    if not nested:
        return []
    if len(nested) == 1:
        if isinstance(nested[0], list):
            return flatten_list(nested[0])
        return nested
    elif isinstance(nested[0], list):
        return flatten_list(nested[0]) + flatten_list(nested[1:])
    else:
        return [nested[0]] + flatten_list(nested[1:])


def get_nodes(node: clang.cindex.Cursor, depth: int = 0):
    """Traverse the AST tree yielding (depth, node) pairs.
    
    Args:
        node: Root cursor to traverse from.
        depth: Current depth (for recursion).
        
    Yields:
        Tuples of (depth, cursor) for each node in the tree.
    """
    yield (depth, node)
    for child in node.get_children():
        yield from get_nodes(child, depth=depth + 1)
