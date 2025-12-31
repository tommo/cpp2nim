# cpp2nim

C++ to Nim binding generator using libclang.

## Installation

```bash
nimble install
```

Requires libclang (LLVM) installed on your system.

## Usage

### CLI Commands

```bash
# Full pipeline: parse + generate
cpp2nim all --config=config.json header1.h header2.h

# Parse only (outputs parsed.json)
cpp2nim parse --config=config.json header.h

# Generate from parsed JSON
cpp2nim generate --config=config.json parsed.json
```

### Configuration

Create a `config.json`:

```json
{
  "output_dir": "generated",
  "cpp_std": "c++17",
  "include_paths": ["/path/to/headers"],
  "defines": ["MYLIB_EXPORT="],
  "type_renames": {
    "MyNamespace::MyType": "MyNimType"
  },
  "opaque_types": ["InternalHandle"],
  "post_fixes": {
    "output.nim": [
      {"type": "plain", "search": "old", "replace": "new"}
    ]
  }
}
```

### Config Options

| Option | Description |
|--------|-------------|
| `output_dir` | Output directory for generated .nim files |
| `cpp_std` | C++ standard (c++11, c++14, c++17, c++20) |
| `include_paths` | Additional include directories |
| `defines` | Preprocessor defines |
| `type_renames` | Map C++ types to Nim names |
| `opaque_types` | Types to treat as opaque (forward declare only) |
| `post_fixes` | Post-generation regex/plain text replacements |
| `import_c` | Use `importc` instead of `importcpp` for plain functions |

## Examples

See `examples/` for real-world usage:

- `examples/real-world/ray_renderer/` - Ray physically-based renderer
- `examples/real-world/rvo2/` - RVO2 collision avoidance library

## Features

- Namespace handling with type renames
- Template type resolution
- `std::size_t`, `std::vector`, etc. support
- Operator overloading
- Constructor/destructor bindings
- Enum and struct field extraction
- Typedef expansion
- Dependency ordering between headers
