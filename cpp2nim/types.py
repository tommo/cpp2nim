"""
C++ to Nim type conversion.

This module handles the conversion of C++ type names to their Nim equivalents.
"""

import re
from typing import Any

from .utils import escape_nim_keyword


# C++ to Nim basic type mapping
BASIC_TYPE_MAP = {
    "void": "void",
    "void *": "pointer",
    "const void *": "ConstPointer",
    "const char *": "ccstring",
    "_Bool": "bool",
    "bool": "bool",
    "long": "clong",
    "unsigned long": "culong",
    "unsigned int": "cuint",
    "unsigned short": "cushort",
    "short": "cshort",
    "int": "cint",
    "size_t": "csize_t",
    "long long": "clonglong",
    "long double": "clongdouble",
    "float": "cfloat",
    "double *": "ptr cdouble",
    "double": "cdouble",
    "char *": "cstring",
    "char": "cchar",
    "signed char": "cschar",
    "unsigned char": "uint8",
    "unsigned long long": "culonglong",
    "char**": "cstringArray",
}

# Pattern for matching template types
TEMPLATE_PATTERN = re.compile(r"([^<]+)[<]*([^>]*)[>]*")


def normalize_ptr_type(c_type: str) -> str:
    """Normalize pointer type spacing.
    
    Args:
        c_type: C++ type string.
        
    Returns:
        Normalized type string with consistent spacing.
    """
    v = re.sub(r'(\w)\*', r'\1 *', c_type.strip())
    v = re.sub(r'const (const )*', 'const ', v)
    return v


def get_nim_array_type(c_type: str, rename: dict[str, str] | None = None) -> str:
    """Convert a C++ array type to Nim.
    
    Args:
        c_type: C++ array type (e.g., "int[10]").
        rename: Type rename mapping.
        
    Returns:
        Nim array type.
        
    Example:
        >>> get_nim_array_type("int[10]")
        'array[10,cint]'
        >>> get_nim_array_type("char[]")
        'ptr cchar'
    """
    rename = rename or {}
    mo = re.match(r'(.*)\[\s*(\d*)\s*\]', c_type)
    if not mo:
        return c_type
    
    etype = mo.group(1)
    count = mo.group(2)
    
    if count == '':
        return f'ptr {get_nim_type(etype, rename)}'
    return f'array[{count},{get_nim_type(etype, rename)}]'


def get_nim_proc_type(c_type: str, rename: dict[str, str] | None = None, 
                      is_const: bool = False) -> str:
    """Convert a C++ function pointer type to Nim proc type.
    
    Args:
        c_type: C++ function pointer type.
        rename: Type rename mapping.
        is_const: Whether the return type is const.
        
    Returns:
        Nim proc type.
    """
    rename = rename or {}
    mo = re.match(r'(.*)\s*\((.*)\)\s*\*', c_type)
    if not mo:
        return c_type
    
    rtype = mo.group(1)
    inner = mo.group(2)
    out = "proc("
    count = 0
    
    if len(inner) > 0:
        for x in inner.split(","):
            if count > 0:
                out += ','
            out += f'arg_{count}:{get_nim_type(x.strip(), rename, return_type=True)}'
            count += 1
    
    if rtype.strip() != "void":
        if is_const:
            rtype = "const " + rtype
        out += f'):{get_nim_type(rtype.strip(), rename, return_type=True)}' + '{.cdecl}'
    else:
        out += ')' + '{.cdecl}'
    
    return out


def get_nim_type(c_type: str, rename: dict[str, str] | None = None, 
                 return_type: bool = False) -> str:
    """Convert a C++ type to its Nim equivalent.
    
    This is the main type conversion function that handles all C++ types
    including pointers, references, templates, arrays, and function pointers.
    
    Args:
        c_type: The C++ type name.
        rename: Dictionary mapping C++ names to Nim names.
        return_type: Whether this is a return type (affects const handling).
        
    Returns:
        The equivalent Nim type.
        
    Example:
        >>> get_nim_type("int")
        'cint'
        >>> get_nim_type("const char *")
        'ccstring'
        >>> get_nim_type("std::vector<int>")
        'vector[cint]'
    """
    rename = rename or {}
    c_type = normalize_ptr_type(c_type)
    
    # Handle arrays first
    if c_type.endswith("]"):
        c_type = get_nim_array_type(c_type, rename)
    
    is_var = True
    is_const = False
    
    # Special cases
    if c_type in ["const void *"]:
        return "ConstPointer"
    
    if c_type in ["const char *"]:
        return "ccstring"
    
    # Handle trailing const pointer
    if c_type.endswith("const *"):
        is_const = True
        c_type = c_type[:-7] + "*"
    
    # Strip class prefix
    if c_type.startswith("class "):
        c_type = c_type[5:].strip()
    
    # Handle const prefix
    while c_type.startswith("const "):
        c_type = c_type[5:].strip()
        is_const = True
        is_var = False
    
    # Handle references
    if not c_type.endswith("&"):
        is_var = False
    else:
        c_type = c_type[:-1]
    
    c_type = c_type.strip()
    
    # Check basic type mapping
    if c_type in BASIC_TYPE_MAP:
        result = BASIC_TYPE_MAP[c_type]
        if is_var and not is_const:
            result = f"var {result}"
        return result
    
    # Handle char* with const/var
    if c_type == "char *":
        if is_var:
            return "cstring"
        return "ccstring" if is_const else "cstring"
    
    # Strip enum/struct prefixes
    c_type = c_type.replace("enum ", "")
    c_type = c_type.replace("struct ", "")
    
    # Handle function pointers
    if ")*" in c_type:
        return get_nim_proc_type(c_type, rename, is_const)
    
    # Handle template types with namespaces (xxxx::yyyy<zzzzz>)
    if "::" in c_type:
        matches = TEMPLATE_PATTERN.findall(c_type)
        if matches:
            base, template_params = matches[0]
            result = base.split("::")[-1]
            
            # Check for rename
            for somename, renamed in rename.items():
                if somename.endswith(base):
                    result = renamed
                    break
            
            # Handle pointers
            while result.endswith("*"):
                inner = result[:-1]
                result = f"ptr {inner}"
            
            # Handle template parameters
            if template_params:
                params = template_params.split(", ")
                params = [get_nim_type(p, rename) for p in params]
                for idx in range(len(params)):
                    if params[idx].endswith("*"):
                        params[idx] = f"ptr {params[idx][:-1].strip()}"
                params_str = ",".join(params)
                result = f"{result}[{params_str}]"
            
            c_type = get_nim_type(result, rename, True)
            
            if is_var and not is_const:
                c_type = f"var {c_type}"
            
            if return_type and is_const:
                if c_type.startswith("ptr "):
                    return f"ConstPtr[{c_type[4:]}]"
            
            return c_type
    
    # Handle simple templates
    if "<" in c_type and ">" in c_type:
        c_type = c_type.replace("<", "[")
        c_type = c_type.replace(">", "]")
    
    c_type = c_type.strip()
    
    # Handle pointers
    if c_type:
        while c_type.endswith("*"):
            inner = c_type[:-1]
            inner = get_nim_type(inner, rename)
            c_type = f"ptr {inner}"
    
    # Final type fixups
    if c_type.startswith("ptr float"):
        c_type = "ptr cfloat"
    if c_type.startswith("ptr Char"):
        c_type = "cstring"
    if c_type.startswith("ptr void"):
        c_type = "pointer"
    if c_type.startswith("ptr ptr void"):
        c_type = "ptr pointer"
    
    # Handle const return type
    if return_type and is_const:
        if c_type.startswith("ptr "):
            return f"ConstPtr[{c_type[4:]}]"
    
    # Handle var modifier
    if is_var and not is_const:
        c_type = f"var {c_type}"
    
    return c_type


class TypeConverter:
    """Type converter with configuration support.
    
    This class wraps the type conversion functions with a specific configuration,
    making it easier to apply consistent renaming across a project.
    
    Example:
        >>> converter = TypeConverter({"MyType": "MyNimType"})
        >>> converter.to_nim("MyType*")
        'ptr MyNimType'
    """
    
    def __init__(self, rename: dict[str, str] | None = None):
        """Initialize the type converter.
        
        Args:
            rename: Type rename mapping.
        """
        self.rename = rename or {}
    
    def to_nim(self, c_type: str, return_type: bool = False) -> str:
        """Convert a C++ type to Nim.
        
        Args:
            c_type: C++ type name.
            return_type: Whether this is a return type.
            
        Returns:
            Nim type name.
        """
        return get_nim_type(c_type, self.rename, return_type)
    
    def add_rename(self, cpp_name: str, nim_name: str) -> None:
        """Add a type rename mapping.
        
        Args:
            cpp_name: C++ type name.
            nim_name: Nim type name.
        """
        self.rename[cpp_name] = nim_name
