# Auto-generated Nim bindings for upstream/include/LDtkLoader/DataTypes.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types, Entity, Tileset

type
  Vertex* {.header: "DataTypes.hpp", importcpp: "ldtk::Vertex".} = object
    pos*: FloatPoint
    tex*: IntPoint
  hash* {.header: "DataTypes.hpp", importcpp: "std::__1::hash".} = object
  UIntPoint* {.header: "DataTypes.hpp", importcpp: "ldtk::UIntPoint".} = Point[cuint]
  UIntRect* {.header: "DataTypes.hpp", importcpp: "ldtk::UIntRect".} = Rect[cuint]
  FloatRect* {.header: "DataTypes.hpp", importcpp: "ldtk::FloatRect".} = Rect[cfloat]

proc directory*(self: ptr FilePath): cstring {.importcpp: "directory".}
proc filename*(self: ptr FilePath): cstring {.importcpp: "filename".}
proc extension*(self: ptr FilePath): cstring {.importcpp: "extension".}
proc getTileset*[T](self: ptr TileRect): var Tileset {.importcpp: "getTileset".}
proc str*(self: ptr IID): var cstring {.importcpp: "str".}
proc `->`*[C, E](self: ptr EntityRef): ConstPtr[Entity] {.importcpp: "# -> #".}
proc newPoint*[T](): Point {.constructor,importcpp: "ldtk::Point".}
proc newPoint*[T](x: T, y: T): Point {.constructor,importcpp: "ldtk::Point(@)".}
proc newRect*[T](): Rect {.constructor,importcpp: "ldtk::Rect".}
proc newRect*[T](x: T, y: T, w: T, h: T): Rect {.constructor,importcpp: "ldtk::Rect(@)".}
proc newRect*[T](pos: Point[T], size: Point[T]): Rect {.constructor,importcpp: "ldtk::Rect(@)".}
proc newColor*(): Color {.constructor,importcpp: "ldtk::Color".}
proc newColor*(hex: cstring): Color {.constructor,importcpp: "ldtk::Color(@)".}
proc newColor*(hex: cint): Color {.constructor,importcpp: "ldtk::Color(@)".}
proc newColor*(red: cuint, green: cuint, blue: cuint, alpha: cuint): Color {.constructor,importcpp: "ldtk::Color(@)".}
proc newFilePath*(): FilePath {.constructor,importcpp: "ldtk::FilePath".}
proc newFilePath*(str: cstring): FilePath {.constructor,importcpp: "ldtk::FilePath(@)".}
proc newTileRect*(tileset: Tileset, bounds: IntRect): TileRect {.constructor,importcpp: "ldtk::TileRect(@)".}
proc newIID*(): IID {.constructor,importcpp: "ldtk::IID".}
proc newIID*(iid: cstring): IID {.constructor,importcpp: "ldtk::IID(@)".}
proc newEntityRef*(ent: IID, layer: IID, level: IID, world: IID): EntityRef {.constructor,importcpp: "ldtk::EntityRef(@)".}
