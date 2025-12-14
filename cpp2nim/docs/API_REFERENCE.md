# cpp2nim API Reference

Complete API documentation for the cpp2nim binding generator.

## Core Modules

### cpp2nim.parser

**CppHeaderParser** - Main class for parsing C++ headers.

```python
class CppHeaderParser:
    def __init__(self, config: Config | None = None):
        """Initialize the parser with optional configuration."""
    
    def parse_file(self, filename: str) -> ParsedHeader:
        """Parse a single header file.
        
        Args:
            filename: Absolute path to the header file.
            
        Returns:
            ParsedHeader containing all declarations found.
        """
    
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
```

### cpp2nim.models

**ParsedHeader** - Result of parsing a single header file.

```python
@dataclass
class ParsedHeader:
    filename: str
    enums: list[EnumDecl]           # Enum declarations
    structs: list[StructDecl]       # Struct declarations
    classes: list[ClassDecl]        # Class declarations
    methods: list[MethodDecl]       # Method/function declarations
    constructors: list[ConstructorDecl]
    typedefs: list[TypedefDecl]
    constants: list[EnumDecl]       # Anonymous enums as constants
    enum_dups: list[dict[str, str]] # Duplicate enum value mappings
    dependencies: set[str]          # Types this header depends on
    provides: set[str]              # Types this header provides
    missing: set[str]               # Dependencies not found locally
```

**ParseResult** - Result of parsing multiple headers.

```python
@dataclass
class ParseResult:
    headers: dict[str, ParsedHeader]          # filename -> parsed header
    all_dependencies: dict[str, set[str]]     # Dependencies per file
    all_provides: dict[str, set[str]]         # Provided types per file
    all_missing: dict[str, set[str]]          # Missing dependencies per file
```

**EnumDecl** - An enum declaration.

```python
@dataclass
class EnumDecl:
    name: str                    # Enum name
    fully_qualified: str         # Fully qualified C++ name
    underlying_type: str         # The underlying integer type
    items: list[EnumItem]        # List of enumerators
    comment: str | None          # Documentation comment
```

**StructDecl** - A struct declaration.

```python
@dataclass
class StructDecl:
    name: str
    fully_qualified: str
    fields: list[FieldDecl]
    base_types: list[str]        # Inheritance
    template_params: list[str | tuple[str, str]]
    is_incomplete: bool          # Opaque type
    is_union: bool
    comment: str | None
    underlying_deps: list[str]   # Type dependencies
```

**MethodDecl** - A method or function declaration.

```python
@dataclass
class MethodDecl:
    name: str
    fully_qualified: str
    class_name: str              # Empty for free functions
    return_type: str
    params: list[Parameter]
    is_const: bool
    is_plain_function: bool      # Free function vs method
    file_origin: str
    comment: str | None
    result_deps: list[str]
```

**Parameter** - A function parameter.

```python
@dataclass
class Parameter:
    name: str
    type_name: str
    default_value: str | None
```

### cpp2nim.config

**Config** - Centralized configuration.

```python
@dataclass
class Config:
    # Parsing options
    search_paths: list[str]      # -I paths for clang
    extra_args: list[str]        # Additional clang args
    c_mode: bool = False         # Parse as C instead of C++
    enum_to_const: list[str]     # Enums to treat as constants
    ignore_files: list[str]      # Files to skip
    
    # Output options
    output_dir: str = "."
    root_namespace: str | None   # Namespace to strip
    camel_case: bool = True
    
    # Type handling
    type_renames: dict[str, str] # Manual renames
    ignore_types: list[str]
    ignore_fields: list[str]
    inheritable_types: list[str]
    varargs_functions: list[str]
    force_shared_types: list[str]
    
    # Performance
    parallel: bool = True        # Use multiprocessing
    num_workers: int | None      # Worker count (None = cpu_count)
    
    @classmethod
    def from_yaml(cls, path: str) -> "Config":
        """Load configuration from YAML file."""
    
    @classmethod
    def from_dict(cls, data: dict) -> "Config":
        """Create from dictionary."""
    
    def to_dict(self) -> dict:
        """Serialize to dictionary."""
    
    def merge_with(self, other: "Config") -> "Config":
        """Merge another config into this one."""
```

### cpp2nim.generator

**NimCodeGenerator** - Generate Nim code from parsed data.

```python
class NimCodeGenerator:
    def __init__(self, config: Config | None = None, rename: dict[str, str] | None = None):
        """Initialize the generator."""
    
    def generate_enum(self, enum: EnumDecl, include: str | None = None) -> str:
        """Generate Nim enum declaration."""
    
    def generate_struct(self, struct: StructDecl, include: str | None = None,
                       inheritable: bool = False, nofield: bool = False) -> str:
        """Generate Nim struct/object declaration."""
    
    def generate_class(self, cls: ClassDecl, include: str | None = None,
                      byref: bool = True, inheritable: bool = False,
                      nofield: bool = False) -> str:
        """Generate Nim class/object declaration."""
    
    def generate_method(self, method: MethodDecl, visited: set[str] | None = None,
                       varargs: list[str] | None = None) -> str | None:
        """Generate Nim method/proc declaration."""
    
    def generate_constructor(self, ctor: ConstructorDecl,
                            dup_tracker: dict[str, bool] | None = None) -> str:
        """Generate Nim constructor proc."""
    
    def generate_typedef(self, typedef: TypedefDecl, include: str | None = None) -> str:
        """Generate Nim typedef."""
    
    def generate_const(self, enum: EnumDecl) -> str:
        """Generate Nim const values from anonymous enum."""
```

### cpp2nim.postprocess

**PostProcessor** - Apply text transformations to generated files.

```python
class PostProcessor:
    def __init__(self, rules: list[PostProcessConfig] | None = None):
        """Initialize with post-processing rules."""
    
    def add_rule(self, file_pattern: str, replacements: list[Replacement]) -> None:
        """Add a post-processing rule."""
    
    def process_file(self, filename: str, content: str) -> str:
        """Apply matching rules to file content."""
    
    def process_all(self, files: dict[str, str]) -> dict[str, str]:
        """Process all generated files."""
    
    @classmethod
    def from_legacy_format(cls, replacements: Sequence[tuple[str, ...]],
                          default_mode: str = "regex") -> "PostProcessor":
        """Convert from legacy sub_in_file format."""
```

**Replacement** - A single text replacement rule.

```python
@dataclass
class Replacement:
    pattern: str              # Pattern to match
    replacement: str          # Replacement text
    mode: str = "regex"       # "regex", "plain", "regex_one", "plain_one"
```

### cpp2nim.types

**TypeConverter** - C++ to Nim type conversion.

```python
class TypeConverter:
    def __init__(self, rename: dict[str, str] | None = None):
        """Initialize with optional rename mapping."""
    
    def to_nim(self, c_type: str, return_type: bool = False) -> str:
        """Convert a C++ type to Nim."""
    
    def add_rename(self, cpp_name: str, nim_name: str) -> None:
        """Add a type rename mapping."""
```

**get_nim_type** - Standalone type conversion function.

```python
def get_nim_type(c_type: str, rename: dict[str, str] | None = None,
                 return_type: bool = False) -> str:
    """Convert a C++ type to its Nim equivalent.
    
    Args:
        c_type: The C++ type name.
        rename: Dictionary mapping C++ names to Nim names.
        return_type: Whether this is a return type (affects const handling).
        
    Returns:
        The equivalent Nim type.
    """
```

## Legacy API (Backward Compatibility)

### cpp2nim.compat

These functions maintain compatibility with existing scripts:

```python
def do_parse(root: str, folders: list[str], dest: str,
             search_paths: list[str] | None = None,
             extra_args: list[str] | None = None,
             ignore: list[str] | None = None,
             enum_to_const: list[str] | None = None,
             c_mode: bool = False) -> None:
    """Parse C++ headers and save to pickle file."""

def export_nim(dest: str, parsed: str, output: str,
               root: str | None = None,
               ignore: dict | list | None = None,
               ignorefields: list[str] | None = None,
               inheritable: dict | list | None = None,
               varargs: list[str] | None = None,
               rename: dict[str, str] | None = None) -> None:
    """Export Nim bindings from parsed data."""

def export_nim_option(options: dict[str, Any]) -> None:
    """Set global export options."""

def sub_in_file(filename: str, old_to_new: Sequence[tuple[str, ...]],
                default_mode: str = 'regex') -> None:
    """Replace text in a file."""
```

## Type Mappings

### Basic Types

| C++ Type | Nim Type |
|----------|----------|
| `void` | `void` |
| `void *` | `pointer` |
| `const void *` | `ConstPointer` |
| `bool` | `bool` |
| `char` | `cchar` |
| `char *` | `cstring` |
| `const char *` | `ccstring` |
| `int` | `cint` |
| `unsigned int` | `cuint` |
| `long` | `clong` |
| `unsigned long` | `culong` |
| `long long` | `clonglong` |
| `float` | `cfloat` |
| `double` | `cdouble` |
| `size_t` | `csize_t` |

### Pointer/Reference Types

| C++ Type | Nim Type |
|----------|----------|
| `T*` | `ptr T` |
| `T&` | `var T` |
| `const T*` | `ConstPtr[T]` |
| `const T&` | `T` |

### Template Types

| C++ Type | Nim Type |
|----------|----------|
| `vector<T>` | `vector[T]` |
| `map<K, V>` | `map[K, V]` |
| `NS::Type<T>` | `Type[T]` |
