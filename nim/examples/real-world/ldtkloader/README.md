# LDtkLoader Example

[LDtkLoader](https://github.com/Madour/LDtkLoader) is a C++11 loader for [LDtk](https://ldtk.io/) level files.

**Status**: In Progress - bindings generate but have known issues.

## Features Tested
- Multi-file C++ project
- C++11 `using` type aliases
- Nested structs and enums
- STL container usage (vector, map, optional)
- Template instantiation aliases

## Known Issues

The generated bindings currently have issues:

1. **Template type aliases** - `using IntPoint = Point<int>` generates duplicate struct definitions instead of proper Nim type aliases
2. **Circular dependencies** - Some modules have circular imports that need resolution
3. **Missing base classes** - `FieldsContainer`, `TagsContainer` are not being captured

These issues are being tracked for cpp2nim generator improvements.

## Usage

```bash
# 1. Clone upstream repository
./setup.sh

# 2. Generate Nim bindings
./generate.sh

# 3. Run tests (currently failing - see Known Issues)
./test.sh

# 4. (Optional) Clean generated files
./clean.sh
```

## Files

- `setup.sh` - Clones/updates the upstream repository
- `generate.sh` - Runs cpp2nim to generate bindings
- `test.sh` - Tests if bindings compile
- `clean.sh` - Removes generated files
- `config.json` - cpp2nim configuration
- `output/` - Generated Nim bindings (after running generate.sh)
