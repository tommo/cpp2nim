"""
Nim code generator for cpp2nim.

This module generates Nim binding code from parsed and analyzed C++ headers.
"""

import os
import textwrap
from typing import Any

from .config import Config, get_global_option
from .models import (
    ClassDecl, ConstructorDecl, EnumDecl, MethodDecl, Parameter,
    ParseResult, StructDecl, TypedefDecl
)
from .types import get_nim_type, TypeConverter
from .utils import clean_identifier, escape_nim_keyword, format_comment, get_template_parameters


class NimCodeGenerator:
    """Generate Nim bindings from analyzed C++ headers.
    
    Example:
        >>> generator = NimCodeGenerator(config, analysis)
        >>> files = generator.generate(parse_result)
        >>> for filename, content in files.items():
        ...     with open(filename, 'w') as f:
        ...         f.write(content)
    """
    
    def __init__(self, config: Config | None = None, rename: dict[str, str] | None = None):
        """Initialize the generator.
        
        Args:
            config: Generation configuration.
            rename: Type rename mapping.
        """
        self.config = config or Config()
        self.rename = rename or {}
        self.type_converter = TypeConverter(self.rename)
    
    def generate_params(self, params: list[Parameter]) -> str:
        """Generate Nim parameter list.
        
        Args:
            params: List of parameters.
            
        Returns:
            Nim parameter string.
        """
        parts = []
        for i, param in enumerate(params):
            name = param.name if param.name else f"a{i:02d}"
            name = clean_identifier(name)
            
            type_str = get_nim_type(param.type_name, self.rename)
            
            if param.default_value and not type_str.startswith("array"):
                default = param.default_value
                if default != "nil" and not default.startswith("{"):
                    if type_str.endswith("Enum") and default != "nil":
                        default = f"{type_str}.{default}"
                    default = default.replace("|", " or ")
                    default = default.replace("||", " or ")
                    default = default.replace("&", " and ")
                    default = default.replace("&&", " and ")
                    type_str = f"{type_str} = {default}"
            
            parts.append(f"{name}: {type_str}")
        
        return ", ".join(parts)
    
    def generate_params_for_constructor(self, params: list[Parameter]) -> list[tuple[str, bool]]:
        """Generate constructor parameters with default value tracking.
        
        Args:
            params: List of parameters.
            
        Returns:
            List of (param_string, has_default) tuples.
        """
        output = []
        for i, param in enumerate(params):
            name = param.name if param.name else f"a{i:02d}"
            name = clean_identifier(name)
            
            type_str = get_nim_type(param.type_name, self.rename)
            has_default = param.default_value is not None
            
            prefix = ", " if i > 0 else ""
            output.append((f"{prefix}{name}: {type_str}", has_default))
        
        return output
    
    def generate_enum(self, enum: EnumDecl, include: str | None = None) -> str:
        """Generate Nim enum declaration.
        
        Args:
            enum: Enum declaration.
            include: Header file for pragma.
            
        Returns:
            Nim enum code.
        """
        name = self.rename.get(enum.fully_qualified, enum.name.split("::")[-1])
        name = clean_identifier(name)
        
        include_pragma = f'header: "{include}", ' if include else ""
        type_size = get_nim_type(enum.underlying_type, self.rename)
        type_pragma = f"size:sizeof({type_size})"
        
        # Sort items by value
        items = sorted(enum.items, key=lambda x: x.value)
        
        items_txt = ""
        for i, item in enumerate(items):
            items_txt += f"    {item.name} = {item.value}"
            if i < len(items) - 1:
                items_txt += ","
            items_txt += "\n"
            if item.comment:
                items_txt += format_comment(item, 6)
        
        result = f'  {name}* {{{type_size},{include_pragma}importcpp: "{enum.fully_qualified}", pure.}} = enum\n'
        if enum.comment:
            result += format_comment(enum.comment) + "\n"
        result += items_txt + "\n"
        
        return result
    
    def generate_struct(
        self, 
        struct: StructDecl, 
        include: str | None = None,
        inheritable: bool = False,
        nofield: bool = False
    ) -> str:
        """Generate Nim struct/object declaration.
        
        Args:
            struct: Struct declaration.
            include: Header file for pragma.
            inheritable: Mark as inheritable.
            nofield: Skip field generation.
            
        Returns:
            Nim struct code.
        """
        if not struct.name:
            return ""
        
        name = self.rename.get(struct.fully_qualified, struct.name.split("::")[-1])
        name = clean_identifier(name)
        
        include_pragma = f'header: "{include}", ' if include else ""
        union_pragma = "union, " if struct.is_union else ""
        inheritable_pragma = "inheritable, " if inheritable else ""
        incomplete_pragma = "incompleteStruct, " if struct.is_incomplete else ""
        
        inheritance = ""
        if struct.base_types:
            base = get_nim_type(struct.base_types[0], self.rename)
            inheritance = f" of {base}"
        
        result = f'  {name}* {{{inheritable_pragma}{union_pragma}{include_pragma}{incomplete_pragma}importcpp: "{struct.fully_qualified}".}} = object{inheritance}\n'
        
        if not nofield:
            for field in struct.fields:
                fname = field.name
                if not fname or fname.startswith("_"):
                    continue
                if field.type_name.startswith("struct "):
                    continue
                
                fname = clean_identifier(fname)
                tname = get_nim_type(field.type_name, self.rename)
                
                if fname.endswith("_"):
                    result += f'    {fname[:-1]}* {{.importcpp:"{fname}".}}: {tname}\n'
                else:
                    result += f'    {fname}*: {tname}\n'
        
        if struct.comment:
            result += format_comment(struct.comment) + "\n"
        
        return result
    
    def generate_class(
        self,
        cls: ClassDecl,
        include: str | None = None,
        byref: bool = True,
        inheritable: bool = False,
        nofield: bool = False
    ) -> str:
        """Generate Nim class/object declaration.
        
        Args:
            cls: Class declaration.
            include: Header file for pragma.
            byref: Pass by reference.
            inheritable: Mark as inheritable.
            nofield: Skip field generation.
            
        Returns:
            Nim class code.
        """
        name = self.rename.get(cls.fully_qualified, cls.fully_qualified.split("::")[-1])
        name = clean_identifier(name)
        
        include_pragma = f'header: "{include}", ' if include else ""
        byref_pragma = ", byref" if byref else ", bycopy"
        inheritable_pragma = "inheritable, " if inheritable else ""
        
        inheritance = ""
        if cls.base_types:
            base = get_nim_type(cls.base_types[0], self.rename)
            inheritance = f" of {base}"
        
        template_str = ""
        if cls.template_params:
            params = []
            for p in cls.template_params:
                if isinstance(p, tuple):
                    params.append(f"{p[0]}:{get_nim_type(p[1], self.rename)}")
                else:
                    params.append(p)
            template_str = f'[{"; ".join(params)}]'
        
        result = f'  {name}*{template_str} {{{inheritable_pragma}{include_pragma}importcpp: "{cls.fully_qualified}"{byref_pragma}.}} = object{inheritance}\n'
        
        if not nofield:
            for field in cls.fields:
                fname = field.name
                if not fname or fname.startswith("_"):
                    continue
                if field.type_name.startswith("struct "):
                    continue
                
                fname = clean_identifier(fname)
                tname = get_nim_type(field.type_name, self.rename)
                
                if fname.endswith("_"):
                    result += f'    {fname[:-1]}* {{.importcpp:"{fname}".}}: {tname}\n'
                else:
                    result += f'    {fname}*: {tname}\n'
        
        if cls.comment:
            result += format_comment(cls.comment) + "\n"
        
        return result
    
    def generate_constructor(
        self,
        ctor: ConstructorDecl,
        dup_tracker: dict[str, bool] | None = None
    ) -> str:
        """Generate Nim constructor proc.
        
        Args:
            ctor: Constructor declaration.
            dup_tracker: Track duplicate constructors.
            
        Returns:
            Nim constructor code.
        """
        dup_tracker = dup_tracker or {}
        
        param_parts = self.generate_params_for_constructor(ctor.params)
        
        class_type = self.rename.get(ctor.fully_qualified, ctor.fully_qualified.split("::")[-1])
        method_name, template_params = get_template_parameters(ctor.name)
        
        result = ""
        
        if not param_parts:
            # No-arg constructor
            proc = f'proc new{method_name}*{template_params}(): {class_type} {{.constructor,importcpp: "{ctor.fully_qualified}".}}\n'
            result = proc + format_comment(ctor.comment) + "\n" if ctor.comment else proc
        else:
            # Generate overloads for default parameters
            n = len(param_parts)
            added = False
            
            for r in range(n - 1, -1, -1):
                params = "".join(p[0] for p in param_parts[:r + 1])
                proc = f'proc new{method_name}*{template_params}({params}): {class_type} {{.constructor,importcpp: "{ctor.fully_qualified}(@)".}}\n'
                
                if proc not in dup_tracker:
                    dup_tracker[proc] = True
                    result += proc
                    added = True
                
                # Stop if this param doesn't have a default
                if not param_parts[r][1]:
                    break
            
            if added and ctor.comment:
                result += format_comment(ctor.comment) + "\n"
        
        return result
    
    def generate_method(
        self,
        method: MethodDecl,
        visited: set[str] | None = None,
        varargs: list[str] | None = None
    ) -> str | None:
        """Generate Nim method/proc declaration.
        
        Args:
            method: Method declaration.
            visited: Track visited methods to avoid duplicates.
            varargs: Functions to mark as varargs.
            
        Returns:
            Nim proc code, or None if duplicate/skipped.
        """
        visited = visited if visited is not None else set()
        varargs = varargs or []
        
        # Method name (lowercase first letter)
        method_name = method.name
        method_name = method_name[0].lower() + method_name[1:]
        
        # Handle varargs
        params = method.params
        has_valist = False
        if params and params[-1].type_name == "va_list":
            has_valist = True
            params = params[:-1]
        
        params_str = self.generate_params(params)
        class_name = f"ptr {method.class_name}"
        
        if not method.is_plain_function:
            import_method = "importcpp"
            import_name = method.name
            if params_str:
                params_str = f"self: {class_name}, {params_str}"
            else:
                params_str = f"self: {class_name}"
        else:
            import_name = method.fully_qualified
            import_method = "importc"
        
        is_vararg = has_valist or (import_name in varargs)
        
        # Return type
        return_str = ""
        if method.return_type and method.return_type != "void":
            result_type = method.return_type.strip()
            is_ref = result_type.endswith("&")
            if is_ref:
                result_type = result_type[:-1].strip()
            result_type = get_nim_type(result_type, self.rename, return_type=True)
            if is_ref:
                result_type = "var " + result_type
                import_method = "importcpp"
            return_str = f": {result_type}"
        
        # Handle operators
        is_operator = False
        if import_name.startswith("`") and import_name.endswith("`"):
            import_name = import_name[1:-1]
            import_name = f"# {import_name} #"
            is_operator = True
        
        pragmas = ""
        if is_vararg:
            pragmas += ", varargs"
        
        method_name = clean_identifier(method_name)
        
        # Generate proc
        if is_operator and method_name in ["`=`"]:
            proc = f'proc assign*({params_str}) {{.{import_method}: "{import_name}"{pragmas}.}}\n'
        elif is_operator and method_name in ["`[]`"]:
            import_name = "#[#]"
            proc = f'proc {method_name}*({params_str}){return_str} {{.{import_method}: "{import_name}"{pragmas}.}}\n'
        elif is_operator and method_name in ["`()`"]:
            return None  # Skip function call operator
        else:
            proc = f'proc {method_name}*({params_str}){return_str} {{.{import_method}: "{import_name}"{pragmas}.}}\n'
        
        if proc in visited:
            return None
        visited.add(proc)
        
        if method.comment:
            proc += format_comment(method.comment) + "\n"
        
        return proc
    
    def generate_typedef(
        self,
        typedef: TypedefDecl,
        include: str | None = None
    ) -> str:
        """Generate Nim typedef.
        
        Args:
            typedef: Typedef declaration.
            include: Header file for pragma.
            
        Returns:
            Nim typedef code.
        """
        if typedef.typedef_kind == "struct" and typedef.struct_data:
            return self.generate_struct(typedef.struct_data, include)
        
        if typedef.typedef_kind == "enum" and typedef.enum_data:
            return self.generate_enum(typedef.enum_data, include)
        
        underlying = typedef.underlying
        nim_type = get_nim_type(underlying, self.rename)
        
        include_pragma = f'header: "{include}", ' if include else ""
        name = clean_identifier(typedef.name)
        
        if typedef.typedef_kind == "function":
            return_str = ""
            if typedef.result_type and typedef.result_type != "void":
                result_type = typedef.result_type.strip()
                if result_type.endswith("&"):
                    result_type = result_type[:-1].strip()
                result_type = get_nim_type(result_type, self.rename)
                return_str = f": {result_type}"
            
            params_str = self.generate_params(typedef.params)
            proc_type = f"proc ({params_str}){return_str} {{.cdecl.}}"
            
            return f'  {name}* {{.{include_pragma}importcpp: "{typedef.fully_qualified}".}} = {proc_type}\n'
        else:
            if nim_type.startswith("struct "):
                nim_type = nim_type[7:]
            
            if name == nim_type:  # Avoid self-reference
                return ""
            
            return f'  {name}* {{.{include_pragma}importcpp: "{typedef.fully_qualified}".}} = {nim_type}\n'
    
    def generate_const(self, enum: EnumDecl) -> str:
        """Generate Nim const values from anonymous enum.
        
        Args:
            enum: Enum treated as constants.
            
        Returns:
            Nim const declarations.
        """
        result = ""
        for item in enum.items:
            result += f"  {item.name}* = {item.value}\n"
            if item.comment:
                result += format_comment(item.comment) + "\n"
        return result


# Legacy format functions for backward compatibility

def get_constructor(data: dict[str, Any], rename: dict[str, str] | None = None,
                   dup: dict[str, bool] | None = None) -> str:
    """Generate constructor from legacy dict format."""
    rename = rename or {}
    dup = dup or {}
    
    params = [
        Parameter(name=p[0], type_name=p[1], default_value=p[2] if len(p) > 2 else None)
        for p in data.get("params", [])
    ]
    
    ctor = ConstructorDecl(
        name=data.get("name", ""),
        fully_qualified=data.get("fully_qualified", ""),
        class_name=data.get("class_name", ""),
        params=params,
        comment=data.get("comment")
    )
    
    generator = NimCodeGenerator(rename=rename)
    return generator.generate_constructor(ctor, dup)


def get_method(data: dict[str, Any], rename: dict[str, str] | None = None,
               visited: set[str] | None = None, varargs: dict[str, bool] | None = None) -> str | bool:
    """Generate method from legacy dict format."""
    rename = rename or {}
    visited = visited if visited is not None else set()
    varargs_list = list(varargs.keys()) if varargs else []
    
    params = [
        Parameter(name=p[0], type_name=p[1], default_value=p[2] if len(p) > 2 else None)
        for p in data.get("params", [])
    ]
    
    method = MethodDecl(
        name=data.get("name", ""),
        fully_qualified=data.get("fully_qualified", ""),
        class_name=data.get("class_name", ""),
        return_type=data.get("result", "void"),
        params=params,
        is_const=data.get("const_method", False),
        is_plain_function=data.get("plain_function", False),
        file_origin=data.get("file_origin", ""),
        comment=data.get("comment"),
        result_deps=data.get("result_deps", [])
    )
    
    generator = NimCodeGenerator(rename=rename)
    result = generator.generate_method(method, visited, varargs_list)
    return result if result else False


def get_typedef(name: str, data: dict[str, Any], include: str | None = None,
                rename: dict[str, str] | None = None) -> str:
    """Generate typedef from legacy dict format."""
    rename = rename or {}
    
    params = [
        Parameter(name=p[0], type_name=p[1], default_value=p[2] if len(p) > 2 else None)
        for p in data.get("params", [])
    ]
    
    typedef = TypedefDecl(
        name=name,
        fully_qualified=data.get("fully_qualified", name),
        underlying=data.get("underlying", ""),
        typedef_kind=data.get("typedef_type"),
        params=params,
        result_type=data.get("result"),
        underlying_deps=data.get("underlying_deps", [])
    )
    
    generator = NimCodeGenerator(rename=rename)
    return generator.generate_typedef(typedef, include)


def get_class(name: str, data: dict[str, Any], include: str | None = None,
              byref: bool = True, rename: dict[str, str] | None = None,
              inheritable: bool = False, nofield: bool = False) -> str:
    """Generate class from legacy dict format."""
    from .models import FieldDecl
    rename = rename or {}
    
    fields = [
        FieldDecl(name=f.get("name", ""), type_name=f.get("type", ""))
        for f in data.get("fields", [])
    ]
    
    cls = ClassDecl(
        name=name.split("::")[-1],
        fully_qualified=data.get("fully_qualified", name),
        fields=fields,
        base_types=data.get("base", []),
        template_params=data.get("template_params", []),
        comment=data.get("comment")
    )
    
    generator = NimCodeGenerator(rename=rename)
    return generator.generate_class(cls, include, byref, inheritable, nofield)


def get_struct(name: str, data: dict[str, Any], include: str | None = None,
               rename: dict[str, str] | None = None, inheritable: bool = False,
               nofield: bool = False) -> str:
    """Generate struct from legacy dict format."""
    from .models import FieldDecl
    rename = rename or {}
    
    fields = [
        FieldDecl(name=f.get("name", ""), type_name=f.get("type", ""))
        for f in data.get("fields", [])
    ]
    
    struct = StructDecl(
        name=data.get("name", name),
        fully_qualified=data.get("fully_qualified", name),
        fields=fields,
        base_types=data.get("base", []),
        template_params=data.get("template_params", []),
        is_incomplete=data.get("incomplete", False),
        is_union=data.get("is_union", False),
        comment=data.get("comment"),
        underlying_deps=data.get("underlying_deps", [])
    )
    
    generator = NimCodeGenerator(rename=rename)
    return generator.generate_struct(struct, include, inheritable, nofield)


def get_enum(name: str, data: dict[str, Any], include: str | None = None,
             rename: dict[str, str] | None = None) -> str:
    """Generate enum from legacy dict format."""
    from .models import EnumItem
    rename = rename or {}
    
    items = [
        EnumItem(name=i.get("name", ""), value=i.get("value", 0), comment=i.get("comment"))
        for i in data.get("items", [])
    ]
    
    enum = EnumDecl(
        name=data.get("name", name),
        fully_qualified=name,
        underlying_type=data.get("type", "int"),
        items=items,
        comment=data.get("comment")
    )
    
    generator = NimCodeGenerator(rename=rename)
    return generator.generate_enum(enum, include)


def get_const(data: dict[str, Any], include: str | None = None) -> str:
    """Generate const from legacy dict format."""
    from .models import EnumItem
    
    items = [
        EnumItem(name=i.get("name", ""), value=i.get("value", 0), comment=i.get("comment"))
        for i in data.get("items", [])
    ]
    
    enum = EnumDecl(
        name="",
        fully_qualified="",
        underlying_type="int",
        items=items,
        comment=data.get("comment")
    )
    
    generator = NimCodeGenerator()
    return generator.generate_const(enum)
