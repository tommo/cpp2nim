"""
Data models for cpp2nim.

Type-safe dataclasses representing C++ declarations extracted from headers.
These replace the untyped dictionaries used in the original implementation.
"""

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Parameter:
    """A function/method parameter.
    
    Attributes:
        name: Parameter name (may be empty for unnamed params).
        type_name: The C++ type as a string.
        default_value: Default value expression, or None if no default.
    """
    name: str
    type_name: str
    default_value: str | None = None


@dataclass
class EnumItem:
    """A single enumerator within an enum.
    
    Attributes:
        name: Enumerator name.
        value: Integer value.
        comment: Documentation comment, if any.
    """
    name: str
    value: int
    comment: str | None = None


@dataclass
class EnumDecl:
    """An enum declaration.
    
    Attributes:
        name: Enum name (may be empty for anonymous enums).
        fully_qualified: Fully qualified C++ name (e.g., "ns::MyEnum").
        underlying_type: The underlying integer type.
        items: List of enumerators.
        comment: Documentation comment.
    """
    name: str
    fully_qualified: str
    underlying_type: str
    items: list[EnumItem] = field(default_factory=list)
    comment: str | None = None
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to legacy dict format for compatibility."""
        return {
            "name": self.name,
            "type": self.underlying_type,
            "comment": self.comment,
            "items": [
                {"name": item.name, "value": item.value, "comment": item.comment}
                for item in self.items
            ]
        }
    
    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "EnumDecl":
        """Create from legacy dict format."""
        items = [
            EnumItem(name=item["name"], value=item["value"], comment=item.get("comment"))
            for item in data.get("items", [])
        ]
        return cls(
            name=data.get("name", name),
            fully_qualified=name,
            underlying_type=data.get("type", "int"),
            items=items,
            comment=data.get("comment")
        )


@dataclass
class FieldDecl:
    """A struct/class field declaration.
    
    Attributes:
        name: Field name.
        type_name: The C++ type.
        is_anonymous: Whether this is from an anonymous union/struct.
    """
    name: str
    type_name: str
    is_anonymous: bool = False
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to legacy dict format."""
        result = {"name": self.name, "type": self.type_name}
        if self.is_anonymous:
            result["is_anonymous"] = True
        return result
    
    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "FieldDecl":
        """Create from legacy dict format."""
        return cls(
            name=data.get("name", ""),
            type_name=data.get("type", ""),
            is_anonymous=data.get("is_anonymous", False)
        )


@dataclass
class StructDecl:
    """A struct declaration.
    
    Attributes:
        name: Struct name.
        fully_qualified: Fully qualified C++ name.
        fields: List of field declarations.
        base_types: Base class/struct types for inheritance.
        template_params: Template parameters (strings or (name, type) tuples).
        is_incomplete: Whether the struct has opaque/incomplete size.
        is_union: Whether this is actually a union.
        comment: Documentation comment.
        underlying_deps: Type dependencies extracted from fields.
    """
    name: str
    fully_qualified: str
    fields: list[FieldDecl] = field(default_factory=list)
    base_types: list[str] = field(default_factory=list)
    template_params: list[str | tuple[str, str]] = field(default_factory=list)
    is_incomplete: bool = False
    is_union: bool = False
    comment: str | None = None
    underlying_deps: list[str] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to legacy dict format."""
        return {
            "name": self.name,
            "fully_qualified": self.fully_qualified,
            "fields": [f.to_dict() for f in self.fields],
            "base": self.base_types,
            "template_params": self.template_params,
            "incomplete": self.is_incomplete,
            "is_union": self.is_union,
            "comment": self.comment,
            "underlying_deps": self.underlying_deps,
        }
    
    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "StructDecl":
        """Create from legacy dict format."""
        fields = [FieldDecl.from_dict(f) for f in data.get("fields", [])]
        return cls(
            name=data.get("name", name),
            fully_qualified=data.get("fully_qualified", name),
            fields=fields,
            base_types=data.get("base", []),
            template_params=data.get("template_params", []),
            is_incomplete=data.get("incomplete", False),
            is_union=data.get("is_union", False),
            comment=data.get("comment"),
            underlying_deps=data.get("underlying_deps", []),
        )


@dataclass
class ClassDecl:
    """A C++ class declaration.
    
    Attributes:
        name: Class name.
        fully_qualified: Fully qualified C++ name.
        fields: Public fields.
        base_types: Base class types.
        template_params: Template parameters.
        comment: Documentation comment.
    """
    name: str
    fully_qualified: str
    fields: list[FieldDecl] = field(default_factory=list)
    base_types: list[str] = field(default_factory=list)
    template_params: list[str | tuple[str, str]] = field(default_factory=list)
    comment: str | None = None
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to legacy dict format."""
        return {
            "fully_qualified": self.fully_qualified,
            "fields": [f.to_dict() for f in self.fields],
            "base": self.base_types,
            "template_params": self.template_params,
            "comment": self.comment,
        }
    
    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "ClassDecl":
        """Create from legacy dict format."""
        fields = [FieldDecl.from_dict(f) for f in data.get("fields", [])]
        return cls(
            name=name.split("::")[-1],
            fully_qualified=data.get("fully_qualified", name),
            fields=fields,
            base_types=data.get("base", []),
            template_params=data.get("template_params", []),
            comment=data.get("comment"),
        )


@dataclass
class MethodDecl:
    """A method or function declaration.
    
    Attributes:
        name: Method/function name.
        fully_qualified: Fully qualified name.
        class_name: Owning class name (empty for free functions).
        return_type: Return type.
        params: Parameter list.
        is_const: Whether this is a const method.
        is_plain_function: Whether this is a free function vs method.
        file_origin: Source file path.
        comment: Documentation comment.
        result_deps: Dependencies from return type.
    """
    name: str
    fully_qualified: str
    class_name: str
    return_type: str
    params: list[Parameter] = field(default_factory=list)
    is_const: bool = False
    is_plain_function: bool = False
    file_origin: str = ""
    comment: str | None = None
    result_deps: list[str] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to legacy dict format."""
        return {
            "name": self.name,
            "fully_qualified": self.fully_qualified,
            "class_name": self.class_name,
            "result": self.return_type,
            "params": [(p.name, p.type_name, p.default_value) for p in self.params],
            "const_method": self.is_const,
            "plain_function": self.is_plain_function,
            "file_origin": self.file_origin,
            "comment": self.comment,
            "result_deps": self.result_deps,
        }
    
    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "MethodDecl":
        """Create from legacy dict format."""
        params = [
            Parameter(name=p[0], type_name=p[1], default_value=p[2] if len(p) > 2 else None)
            for p in data.get("params", [])
        ]
        return cls(
            name=data.get("name", name),
            fully_qualified=data.get("fully_qualified", name),
            class_name=data.get("class_name", ""),
            return_type=data.get("result", "void"),
            params=params,
            is_const=data.get("const_method", False),
            is_plain_function=data.get("plain_function", False),
            file_origin=data.get("file_origin", ""),
            comment=data.get("comment"),
            result_deps=data.get("result_deps", []),
        )


@dataclass
class ConstructorDecl:
    """A constructor declaration.
    
    Attributes:
        name: Constructor name (class name).
        fully_qualified: Fully qualified class name.
        class_name: Class name.
        params: Constructor parameters.
        comment: Documentation comment.
    """
    name: str
    fully_qualified: str
    class_name: str
    params: list[Parameter] = field(default_factory=list)
    comment: str | None = None
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to legacy dict format."""
        return {
            "name": self.name,
            "fully_qualified": self.fully_qualified,
            "class_name": self.class_name,
            "params": [(p.name, p.type_name, p.default_value) for p in self.params],
            "comment": self.comment,
        }
    
    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "ConstructorDecl":
        """Create from legacy dict format."""
        params = [
            Parameter(name=p[0], type_name=p[1], default_value=p[2] if len(p) > 2 else None)
            for p in data.get("params", [])
        ]
        return cls(
            name=data.get("name", name),
            fully_qualified=data.get("fully_qualified", name),
            class_name=data.get("class_name", ""),
            params=params,
            comment=data.get("comment"),
        )


@dataclass
class TypedefDecl:
    """A typedef declaration.
    
    Attributes:
        name: Typedef name.
        fully_qualified: Fully qualified name.
        underlying: Underlying type.
        typedef_kind: Kind of typedef ("function", "struct", "enum", or None).
        params: Parameters if this is a function typedef.
        result_type: Return type if this is a function typedef.
        underlying_deps: Type dependencies.
        struct_data: Embedded struct data if typedef_kind is "struct".
        enum_data: Embedded enum data if typedef_kind is "enum".
    """
    name: str
    fully_qualified: str
    underlying: str
    typedef_kind: str | None = None
    params: list[Parameter] = field(default_factory=list)
    result_type: str | None = None
    underlying_deps: list[str] = field(default_factory=list)
    # For struct/enum typedefs, store the embedded data
    struct_data: StructDecl | None = None
    enum_data: EnumDecl | None = None
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to legacy dict format."""
        result: dict[str, Any] = {
            "underlying": self.underlying,
            "fully_qualified": self.fully_qualified,
            "typedef_type": self.typedef_kind,
            "params": [(p.name, p.type_name, p.default_value) for p in self.params],
            "result": self.result_type,
            "underlying_deps": self.underlying_deps,
        }
        if self.struct_data:
            result.update(self.struct_data.to_dict())
        if self.enum_data:
            result.update(self.enum_data.to_dict())
        return result
    
    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "TypedefDecl":
        """Create from legacy dict format."""
        params = [
            Parameter(name=p[0], type_name=p[1], default_value=p[2] if len(p) > 2 else None)
            for p in data.get("params", [])
        ]
        
        struct_data = None
        enum_data = None
        typedef_kind = data.get("typedef_type")
        
        if typedef_kind == "struct":
            struct_data = StructDecl.from_dict(name, data)
        elif typedef_kind == "enum":
            enum_data = EnumDecl.from_dict(name, data)
        
        return cls(
            name=name,
            fully_qualified=data.get("fully_qualified", name),
            underlying=data.get("underlying", ""),
            typedef_kind=typedef_kind,
            params=params,
            result_type=data.get("result"),
            underlying_deps=data.get("underlying_deps", []),
            struct_data=struct_data,
            enum_data=enum_data,
        )


@dataclass
class ParsedHeader:
    """Result of parsing a single header file.
    
    Attributes:
        filename: Path to the source header file.
        enums: Enum declarations found.
        structs: Struct declarations found.
        classes: Class declarations found.
        methods: Method and function declarations found.
        constructors: Constructor declarations found.
        typedefs: Typedef declarations found.
        constants: Anonymous enums treated as constants.
        enum_dups: Duplicate enum value mappings.
        dependencies: Types this header depends on.
        provides: Types this header provides.
        missing: Dependencies not found locally.
    """
    filename: str
    enums: list[EnumDecl] = field(default_factory=list)
    structs: list[StructDecl] = field(default_factory=list)
    classes: list[ClassDecl] = field(default_factory=list)
    methods: list[MethodDecl] = field(default_factory=list)
    constructors: list[ConstructorDecl] = field(default_factory=list)
    typedefs: list[TypedefDecl] = field(default_factory=list)
    constants: list[EnumDecl] = field(default_factory=list)
    enum_dups: list[dict[str, str]] = field(default_factory=list)
    dependencies: set[str] = field(default_factory=set)
    provides: set[str] = field(default_factory=set)
    missing: set[str] = field(default_factory=set)


@dataclass
class ParseResult:
    """Result of parsing multiple headers.
    
    Attributes:
        headers: Map from filename to ParsedHeader.
        all_dependencies: Dependencies per file.
        all_provides: Provided types per file.
        all_missing: Missing dependencies per file.
    """
    headers: dict[str, ParsedHeader] = field(default_factory=dict)
    all_dependencies: dict[str, set[str]] = field(default_factory=dict)
    all_provides: dict[str, set[str]] = field(default_factory=dict)
    all_missing: dict[str, set[str]] = field(default_factory=dict)
