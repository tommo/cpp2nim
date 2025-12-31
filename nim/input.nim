# Auto-generated Nim bindings for examples/simple/input.h
# Generated: 2025-12-31T12:51:39+08:00

type
  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*

type
  Color* {.size:sizeof(cint), header: "input.h", importcpp: "Graphics::Color", pure.} = enum
    Red = 0,
    Green = 1,
    Blue = 2,
    Alpha = 3

  Point* {.header: "input.h", importcpp: "Graphics::Point".} = object of RootObj
    x*: cfloat
    y*: cfloat
  Rectangle* {.header: "input.h", importcpp: "Graphics::Rectangle".} = object of RootObj
    topLeft*: Point
    bottomRight*: Point
    fillColor*: Color

proc distance*(self: ptr Point): cfloat {.importcpp: "distance".}
proc area*(self: ptr Rectangle): cfloat {.importcpp: "area".}
proc contains*(self: ptr Rectangle, p: Point): bool {.importcpp: "contains".}
proc newPoint*(x: cfloat, y: cfloat): Point {.constructor,importcpp: "Graphics::Point(@)".}
proc newRectangle*(tl: Point, br: Point, color: Color): Rectangle {.constructor,importcpp: "Graphics::Rectangle(@)".}
