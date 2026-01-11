# MicroPather Example

[MicroPather](https://github.com/leethomason/MicroPather) is a path finder and A* solver written in platform independent C++.

## Features Tested
- Virtual interface (`Graph` class with pure virtual methods)
- Templates (internal use)
- C++ namespaces
- Nested classes

## Usage

```bash
# 1. Clone upstream repository
./setup.sh

# 2. Generate Nim bindings
./generate.sh

# 3. (Optional) Clean generated files
./clean.sh
```

## Files

- `setup.sh` - Clones/updates the upstream repository
- `generate.sh` - Runs cpp2nim to generate bindings
- `clean.sh` - Removes generated files
- `config.json` - cpp2nim configuration
- `output/` - Generated Nim bindings (after running generate.sh)
