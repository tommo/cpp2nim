# cpp2nim Examples

Usage examples for cpp2nim - the C++ to Nim binding generator.

## Examples

### [simple/](simple/)
Basic example with a single header file:
- Enums, structs, and simple methods
- Type renaming and namespace stripping
- Minimal configuration

### [advanced/](advanced/)
Complex example with multiple files:
- Class inheritance and virtual methods
- Template classes and specializations
- Dependency resolution between files
- Shared types across modules

## Quick Start

```bash
# Build cpp2nim (from project root)
nimble build

# Run simple example
cd examples/simple
../../cpp2nim_cli all --config=config.json input.h

# Run advanced example
cd examples/advanced
../../cpp2nim_cli all --config=config.json vehicle.h engine.h
```

> Note: The CLI currently uses JSON config files.

## Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `output_dir` | string | Directory for generated .nim files |
| `root_namespace` | string | C++ namespace to strip from names |
| `type_renames` | map | Custom type name mappings |
| `ignore_types` | list | Types to skip (e.g., std:: types) |
| `ignore_fields` | list | Fields to exclude from structs |
| `inheritable_types` | list | Types to mark as inheritable (RootObj) |
| `force_shared_types` | list | Types to put in shared module |
| `extra_args` | list | Additional clang arguments |
| `search_paths` | list | Include directories (-I paths) |
| `camel_case` | bool | Convert to camelCase (default: true) |
| `parallel` | bool | Enable parallel parsing |
| `num_workers` | int | Number of worker processes |
| `c_mode` | bool | Parse as C instead of C++ |

## CLI vs Config File

All options can be specified via CLI:

```bash
# Using config file
cpp2nim_cli all --config=myconfig.json *.h

# Using CLI options
cpp2nim_cli all \
  --output=bindings \
  --namespace=MyLib \
  --rename=OldName:NewName \
  --ignore-type=InternalType \
  -I/usr/include \
  -DDEBUG \
  *.h
```

CLI options override config file settings.

## Pipeline Commands

```bash
# Full pipeline (parse + analyze + generate)
cpp2nim_cli all *.h

# Individual steps
cpp2nim_cli parse *.h -o parsed.json
cpp2nim_cli analyze parsed.json -o analysis.json
cpp2nim_cli generate parsed.json analysis.json -o bindings/
```
