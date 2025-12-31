# Simple Example

Basic cpp2nim usage with a single header file containing enums, structs, and methods.

## Input

`input.h` contains:
- `Color` enum (Red, Green, Blue, Alpha)
- `Point` struct with x/y coordinates and methods
- `Rectangle` struct with two points and a color

## Configuration

`config.json` demonstrates:
- `output_dir`: Where to place generated bindings
- `root_namespace`: Strip "Graphics" from type names
- `type_renames`: Rename Point→Point2D, Rectangle→Rect
- `camel_case`: Convert identifiers to camelCase
- `extra_args`: Pass compiler flags to clang

## Running

```bash
# From the examples/simple directory:
cd examples/simple

# Run cpp2nim with config
../../cpp2nim_cli all --config=config.json input.h

# Or with CLI options (equivalent):
../../cpp2nim_cli all \
  --output=output \
  --namespace=Graphics \
  --rename=Point:Point2D \
  --rename=Rectangle:Rect \
  input.h
```

> Note: The CLI currently uses JSON config files. See `config.json`.

## Expected Output

Generated `output/input.nim`:

```nim
# Auto-generated Nim bindings for input.h

type
  Color* {.importcpp: "Graphics::Color", header: "input.h".} = enum
    red = 0
    green = 1
    blue = 2
    alpha = 3

type
  Point2D* {.importcpp: "Graphics::Point", header: "input.h".} = object
    x*: cfloat
    y*: cfloat

proc init*(self: var Point2D; x, y: cfloat)
  {.importcpp: "Graphics::Point(@)", header: "input.h".}

proc distance*(self: Point2D): cfloat
  {.importcpp: "#.distance()", header: "input.h".}

type
  Rect* {.importcpp: "Graphics::Rectangle", header: "input.h".} = object
    topLeft*: Point2D
    bottomRight*: Point2D
    fillColor*: Color

proc init*(self: var Rect; tl, br: Point2D; color: Color)
  {.importcpp: "Graphics::Rectangle(@)", header: "input.h".}

proc area*(self: Rect): cfloat
  {.importcpp: "#.area()", header: "input.h".}

proc contains*(self: Rect; p: Point2D): bool
  {.importcpp: "#.contains(@)", header: "input.h".}
```
