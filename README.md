# cpp2nim

A clang-based C/C++ to Nim binding generator. Parses C/C++ headers using libclang and generates Nim FFI bindings with proper `{.importcpp.}` / `{.importc.}` pragmas.

Rewritten in Nim from the original [cpp2nim Python script](https://github.com/mantielero/cpp2nim) by [@mantielero](https://github.com/mantielero).

> **Note**: This tool generates bindings that will likely need manual adjustments, but should get you much closer to working code than starting from scratch.

## Installation

```bash
cd nim
nimble install
```

Requires libclang to be installed:
- **macOS**: `brew install llvm` or use Xcode's clang
- **Linux**: `apt install libclang-dev` or equivalent

Set `CPP2NIM_LIBCLANG_PATH` environment variable if libclang is not auto-detected.

## Quick Start

```bash
# Generate bindings for a single header
cpp2nim all -o bindings/ mylib.h

# Generate bindings with a config file
cpp2nim all --config=cpp2nim.json "src/*.hpp"

# Process multiple files with options
cpp2nim all -I/usr/include -o bindings/ --namespace=MyLib "include/*.h"
```

## Commands

| Command | Description |
|---------|-------------|
| `parse` | Parse C++ headers to intermediate JSON |
| `analyze` | Analyze dependencies between parsed headers |
| `generate` | Generate Nim bindings from parsed JSON |
| `all` | Run complete pipeline (parse + analyze + generate) |

## CLI Options

```
-c, --config=FILE     Load configuration from JSON file
-o, --output=DIR      Output directory (default: current dir)
-I, --include=PATH    Add include search path (can be repeated)
-D, --define=MACRO    Add preprocessor define (can be repeated)
-v, --verbose         Enable verbose output
-q, --quiet           Suppress non-error output
--c-mode              Parse as C instead of C++
--no-camel            Disable camelCase conversion
--namespace=NS        Root namespace to strip
--rename=OLD:NEW      Add type rename (can be repeated)
--ignore-type=TYPE    Ignore type (can be repeated)
--ignore-file=FILE    Ignore file pattern (can be repeated)
--parallel            Enable parallel parsing
--workers=N           Number of parallel workers
```

## Configuration File

Create a `cpp2nim.json` for project-specific settings:

```json
{
  "output_dir": "bindings",
  "root_namespace": "MyLib",
  "search_paths": ["/usr/include", "./include"],
  "extra_args": ["-std=c++17"],
  "defines": ["MY_DEFINE=1"],
  "camel_case": true,
  "type_renames": {
    "OldType": "NewType",
    "std::vector": "Vector"
  },
  "ignore_types": ["std::allocator", "std::string"],
  "ignore_fields": ["_internal", "_reserved"],
  "inheritable_types": ["BaseClass"],
  "force_shared_types": ["SharedEnum"],
  "c_mode": false,
  "parallel": true,
  "num_workers": 4
}
```

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `output_dir` | string | Directory for generated .nim files |
| `root_namespace` | string | C++ namespace to strip from names |
| `search_paths` | array | Include directories for clang |
| `extra_args` | array | Additional clang arguments (e.g., `-std=c++17`) |
| `defines` | array | Preprocessor defines |
| `c_mode` | bool | Parse as C instead of C++ |
| `camel_case` | bool | Convert identifiers to camelCase |
| `type_renames` | object | Map of type name replacements |
| `ignore_types` | array | Types to skip during generation |
| `ignore_fields` | array | Fields to exclude from structs |
| `ignore_files` | array | File patterns to skip |
| `inheritable_types` | array | Types to mark as `RootObj` for inheritance |
| `force_shared_types` | array | Types to always put in shared_types.nim |
| `parallel` | bool | Enable parallel header parsing |
| `num_workers` | int | Number of parallel workers |
| `post_fixes` | object | Regex post-processing rules per file |

## Pipeline Stages

### 1. Parse
Extracts declarations from C++ headers using libclang:
- Enums and enum classes
- Structs and classes (public members)
- Methods and free functions
- Constructors
- Typedefs and type aliases
- Constants

### 2. Analyze
Resolves dependencies between headers:
- Identifies shared types (used by multiple files)
- Detects inheritance relationships
- Generates import graph
- Handles type renames for conflicts

### 3. Generate
Produces Nim code with:
- Type definitions with `{.importcpp.}` pragmas
- Method bindings with proper calling conventions
- `shared_types.nim` for cross-file types
- Automatic imports between modules

## Examples

See the `nim/examples/` directory:

- **simple/** - Basic enum, struct, and method binding
- **advanced/** - Multi-file with inheritance and templates
- **real-world/** - Bindings for actual libraries (stb_image, RVO2, im3d, etc.)

### Simple Example

Input (`input.h`):
```cpp
namespace Graphics {
    enum Color { Red, Green, Blue };

    struct Point {
        float x, y;
        float distance(Point other);
    };
}
```

Config (`cpp2nim.json`):
```json
{
  "output_dir": "output",
  "root_namespace": "Graphics",
  "type_renames": { "Point": "Vec2" }
}
```

Generated (`input.nim`):
```nim
type
  Color* {.size: sizeof(cint), header: "input.h",
          importcpp: "Graphics::Color", pure.} = enum
    Red = 0, Green = 1, Blue = 2

  Vec2* {.header: "input.h", importcpp: "Graphics::Point".} = object
    x*: cfloat
    y*: cfloat

proc distance*(self: ptr Vec2, other: Vec2): cfloat
    {.importcpp: "#.distance(@)", header: "input.h".}
```

## Post-Processing

For complex cases, use regex-based post-processing:

```json
{
  "post_fixes": {
    "shared_types.nim": [
      {
        "pattern": "OldPattern",
        "replacement": "NewReplacement",
        "mode": "regex"
      }
    ],
    "*.nim": [
      {
        "pattern": "foo",
        "replacement": "bar",
        "mode": "plain"
      }
    ]
  }
}
```

Modes: `regex`, `plain`, `regex_one`, `plain_one`

## Known Limitations

- Forward-declared types may need manual stub definitions
- Nested template typedefs can generate incorrectly
- Template-heavy code may need manual adjustments
- Operator overloading has limited support

See `nim/docs/known_issues.md` for details.

## Architecture

```
C++ Headers → [Parse] → JSON → [Analyze] → [Generate] → Nim Bindings
                ↓                  ↓              ↓
            libclang         Dependency      {.importcpp.}
           AST traversal      resolution       pragmas
```

Key modules in `nim/src/cpp2nim/`:
- `parser.nim` - libclang-based C++ parsing
- `analyzer.nim` - Dependency analysis
- `generator.nim` - Nim code generation
- `types.nim` - C++ to Nim type mapping
- `config.nim` - Configuration management

## License

MIT
