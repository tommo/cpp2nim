"""
Backward compatibility layer for cpp2nim.

This module provides legacy API functions that maintain compatibility with
existing scripts like genBGFX.py and genImgui.py, while internally using
the new modular architecture.
"""

import os
import pickle
from pathlib import Path
from typing import Any, Sequence

from .config import Config, set_global_option, get_global_option
from .parser import CppHeaderParser, parse_include_file
from .analyzer import (
    DependencyAnalyzer, _relationships, find_dependencies, move_to_shared_types
)
from .generator import (
    NimCodeGenerator, get_constructor, get_method, get_typedef,
    get_class, get_struct, get_enum, get_const
)
from .postprocess import sub_in_file, append_to_file
from .types import get_nim_type
from .utils import flatten_namespace


def do_parse(
    root: str,
    folders: list[str],
    dest: str,
    search_paths: list[str] | None = None,
    extra_args: list[str] | None = None,
    ignore: list[str] | None = None,
    enum_to_const: list[str] | None = None,
    c_mode: bool = False
) -> None:
    """Parse C++ headers (legacy API).
    
    This function parses C++ headers and saves the result to a pickle file,
    maintaining compatibility with existing scripts.
    
    Args:
        root: Root directory containing headers.
        folders: List of header file paths or glob patterns.
        dest: Output directory for parsed data.
        search_paths: Include directories for clang.
        extra_args: Additional clang compiler arguments.
        ignore: Files to ignore during parsing.
        enum_to_const: Enum names to treat as constants.
        c_mode: Parse as C instead of C++.
        
    Example:
        >>> do_parse(
        ...     root="/usr/include/mylib",
        ...     folders=["/usr/include/mylib/*.h"],
        ...     dest="output_gen",
        ...     search_paths=["/usr/include/mylib"]
        ... )
    """
    config = Config(
        search_paths=search_paths or [],
        extra_args=extra_args or [],
        ignore_files=ignore or [],
        enum_to_const=enum_to_const or [],
        c_mode=c_mode,
        output_dir=dest
    )
    
    # Create output directory
    os.makedirs(dest, exist_ok=True)
    
    # Parse headers
    parser = CppHeaderParser(config)
    result = parser.parse_files(folders)
    
    # Convert to legacy format
    data: list[tuple[Any, ...]] = []
    depends_on: dict[str, set[str]] = {}
    provides: dict[str, set[str]] = {}
    missing: dict[str, set[str]] = {}
    
    for filename, header in result.headers.items():
        # Strip root prefix from filename for output
        if filename.startswith(root):
            rel_filename = filename[len(root):].lstrip("/")
        else:
            rel_filename = filename
        
        # Constants (anonymous enums)
        for const_enum in header.constants:
            data.append((rel_filename, "const", const_enum.to_dict()))
        
        # Enums
        for enum in header.enums:
            data.append((rel_filename, "enum", enum.fully_qualified, enum.to_dict()))
        
        # Enum duplicates
        for dup in header.enum_dups:
            data.append((rel_filename, "enum_dup", dup))
        
        # Typedefs
        for typedef in header.typedefs:
            data.append((rel_filename, "typedef", typedef.name, typedef.to_dict()))
        
        # Structs
        for struct in header.structs:
            data.append((rel_filename, "struct", struct.fully_qualified, struct.to_dict()))
        
        # Classes
        for cls in header.classes:
            data.append((rel_filename, "class", cls.fully_qualified, cls.to_dict()))
        
        # Constructors
        for ctor in header.constructors:
            data.append((rel_filename, "constructor", ctor.fully_qualified, ctor.to_dict()))
        
        # Methods/Functions
        for method in header.methods:
            data.append((rel_filename, "method", method.fully_qualified, method.to_dict()))
        
        # Track dependencies
        depends_on[rel_filename] = result.all_dependencies.get(filename, set())
        provides[rel_filename] = result.all_provides.get(filename, set())
        missing[rel_filename] = result.all_missing.get(filename, set())
    
    # Save to pickle file
    output_file = os.path.join(dest, "data.pkl")
    with open(output_file, 'wb') as f:
        pickle.dump((data, depends_on, provides, missing), f)
    
    print(f"Parsed {len(result.headers)} headers -> {output_file}")


def export_nim_option(options: dict[str, Any]) -> None:
    """Set global export options (legacy API).
    
    Args:
        options: Dictionary of options to set globally.
        
    Example:
        >>> export_nim_option({'root_namespace': 'bgfx'})
    """
    for key, value in options.items():
        set_global_option(key, value)


def export_nim(
    dest: str,
    parsed: str,
    output: str,
    root: str | None = None,
    ignore: dict[str, bool] | list[str] | None = None,
    ignorefields: list[str] | None = None,
    inheritable: dict[str, bool] | list[str] | None = None,
    varargs: list[str] | None = None,
    rename: dict[str, str] | None = None
) -> None:
    """Export Nim bindings from parsed data (legacy API).
    
    This function generates Nim binding files from previously parsed C++ headers.
    
    Args:
        dest: Destination name/prefix for generated files.
        parsed: Directory containing parsed data (from do_parse).
        output: Output directory for generated Nim files.
        root: Root path for header references.
        ignore: Types to ignore/skip.
        ignorefields: Field names to ignore.
        inheritable: Types to mark as inheritable.
        varargs: Functions to mark as varargs.
        rename: Manual type renames.
        
    Example:
        >>> export_nim(
        ...     dest="mylib",
        ...     parsed="output_gen",
        ...     output="output_gen/mylib",
        ...     root="/usr/include/mylib"
        ... )
    """
    # Normalize options
    if isinstance(ignore, dict):
        ignore_list = list(ignore.keys())
    elif isinstance(ignore, list):
        ignore_list = ignore
    else:
        ignore_list = []
    
    if isinstance(inheritable, dict):
        inheritable_list = list(inheritable.keys())
    elif isinstance(inheritable, list):
        inheritable_list = inheritable
    else:
        inheritable_list = []
    
    rename = rename or {}
    ignorefields = ignorefields or []
    varargs = varargs or []
    
    # Load parsed data
    data_file = os.path.join(parsed, "data.pkl")
    with open(data_file, 'rb') as f:
        data, depends_on, provides, missing = pickle.load(f)
    
    # Create output directory
    os.makedirs(output, exist_ok=True)
    
    # Compute relationships
    relations = _relationships(data, provides, missing)
    
    # Generate shared types file
    shared_types_file = f"{dest}_types"
    if root:
        root = root.rstrip("/") + "/"
    else:
        root = ""
    
    data = move_to_shared_types(shared_types_file + ".h", data, root, relations)
    
    # Generate renames
    rename = _get_renames(data, rename)
    
    # Generate Nim code for each file
    filenames = list(set(d[0] for d in data))
    
    for filename in filenames:
        nim_filename = _get_nim_filename(filename, dest, shared_types_file)
        nim_path = os.path.join(output, nim_filename + ".nim")
        
        content = _generate_file_content(
            filename, data, root, rename, ignore_list, ignorefields,
            inheritable_list, varargs, relations
        )
        
        with open(nim_path, 'w') as f:
            f.write(content)
        
        print(f"Generated: {nim_path}")


def _get_nim_filename(filename: str, dest: str, shared_types_file: str) -> str:
    """Convert C++ header filename to Nim module name."""
    if filename == shared_types_file + ".h":
        return shared_types_file
    
    basename = os.path.basename(filename)
    name = os.path.splitext(basename)[0]
    
    # Convert naming conventions
    name = name.replace("-", "_")
    name = name.lower()
    
    return name


def _get_renames(data: list[tuple[Any, ...]], existing: dict[str, str]) -> dict[str, str]:
    """Generate type renames to avoid conflicts."""
    rename = dict(existing)
    root_namespace = get_global_option("root_namespace")
    
    # Find identifiers that could conflict
    identifiers: dict[str, list[str]] = {}
    
    for item in data:
        if len(item) < 4:
            continue
        
        item_type = item[1]
        if item_type not in ["enum", "struct", "class", "typedef"]:
            continue
        
        fully_qualified = item[2]
        short_name = fully_qualified.split("::")[-1]
        
        if short_name not in identifiers:
            identifiers[short_name] = []
        identifiers[short_name].append(fully_qualified)
    
    # Generate renames for conflicts
    for short_name, full_names in identifiers.items():
        if len(full_names) > 1:
            for full_name in full_names:
                if full_name not in rename:
                    parts = full_name.split("::")
                    if root_namespace and parts and parts[0] == root_namespace:
                        new_name = "_".join(parts[1:])
                    else:
                        new_name = flatten_namespace(full_name)
                    rename[full_name] = new_name
    
    return rename


def _generate_file_content(
    filename: str,
    data: list[tuple[Any, ...]],
    root: str,
    rename: dict[str, str],
    ignore: list[str],
    ignorefields: list[str],
    inheritable: list[str],
    varargs: list[str],
    relations: dict[str, dict[str, set[str]]]
) -> str:
    """Generate Nim file content for a single source file."""
    
    # Header
    content = "import wrapping_tools\n"
    content += "import builtin_types\n"
    
    # Imports from other files
    file_deps = relations.get(filename, {})
    for dep_file in file_deps.keys():
        if dep_file == filename:
            continue
        module_name = os.path.splitext(os.path.basename(dep_file))[0]
        content += f"import {module_name}\n"
    
    content += "\n"
    
    # Include header reference
    include_header = filename
    if root and include_header.startswith(root):
        include_header = include_header[len(root):]
    
    # Process items
    visited_methods: set[str] = set()
    ctor_dup: dict[str, bool] = {}
    
    # Type section
    content += "type\n"
    
    for item in data:
        if item[0] != filename:
            continue
        
        item_type = item[1]
        
        if item_type == "enum" and len(item) > 3:
            name = item[2]
            values = item[3]
            if name not in ignore:
                content += get_enum(name, values, include_header, rename)
        
        elif item_type == "typedef" and len(item) > 3:
            name = item[2]
            values = item[3]
            if name not in ignore:
                typedef_type = values.get("typedef_type")
                if typedef_type == "struct":
                    content += get_struct(name, values, include_header, rename)
                elif typedef_type == "enum":
                    content += get_enum(name, values, include_header, rename)
                else:
                    content += get_typedef(name, values, include_header, rename)
        
        elif item_type == "struct" and len(item) > 3:
            name = item[2]
            values = item[3]
            if name not in ignore:
                is_inheritable = name in inheritable
                content += get_struct(name, values, include_header, rename, is_inheritable)
        
        elif item_type == "class" and len(item) > 3:
            name = item[2]
            values = item[3]
            if name not in ignore:
                is_inheritable = name in inheritable
                content += get_class(name, values, include_header, True, rename, is_inheritable)
    
    content += "\n"
    
    # Const section
    for item in data:
        if item[0] != filename:
            continue
        if item[1] == "const" and len(item) > 2:
            content += get_const(item[2], include_header)
    content += "\n"
    
    # Constructor section
    for item in data:
        if item[0] != filename:
            continue
        if item[1] == "constructor" and len(item) > 3:
            name = item[2]
            values = item[3]
            if values.get("class_name") not in ignore:
                content += get_constructor(values, rename, ctor_dup)
    content += "\n"
    
    # Method section
    varargs_dict = {v: True for v in varargs}
    
    for item in data:
        if item[0] != filename:
            continue
        if item[1] == "method" and len(item) > 3:
            name = item[2]
            values = item[3]
            class_name = values.get("class_name", "")
            if class_name not in ignore:
                result = get_method(values, rename, visited_methods, varargs_dict)
                if result:
                    content += result
    
    return content
