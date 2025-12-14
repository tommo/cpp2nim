"""
cpp2nim - C++ to Nim Binding Generator

A clang-based parser and code generator for creating Nim bindings from C++ headers.

Example usage:
    from cpp2nim import parse_headers, export_nim

    # Parse C++ headers
    parse_headers(
        root="/path/to/include",
        folders=["/path/to/include/*.h"],
        dest="output_gen",
        search_paths=["/path/to/include"]
    )

    # Generate Nim bindings
    export_nim(
        dest="mylib",
        parsed="output_gen",
        output="output_gen/mylib",
        root="/path/to/include"
    )
"""

__version__ = "2.0.0"

# Re-export the main API functions for backward compatibility
from .parser import CppHeaderParser, parse_include_file
from .analyzer import DependencyAnalyzer
from .generator import NimCodeGenerator
from .postprocess import PostProcessor, sub_in_file
from .config import Config

# Legacy API - these maintain backward compatibility with existing scripts
from .compat import do_parse, export_nim, export_nim_option

__all__ = [
    # Version
    "__version__",
    # New API
    "CppHeaderParser",
    "parse_include_file",
    "DependencyAnalyzer",
    "NimCodeGenerator",
    "PostProcessor",
    "Config",
    # Legacy API (backward compatible)
    "do_parse",
    "export_nim",
    "export_nim_option",
    "sub_in_file",
]
