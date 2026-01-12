# Auto-generated Nim bindings for upstream/include/LDtkLoader/DataTypes.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, Entity, Tileset

type
  WorldLayout* {.size:sizeof(cint), header: "DataTypes.hpp", importcpp: "ldtk::WorldLayout", pure.} = enum
    Free = 0,
    GridVania = 1,
    LinearHorizontal = 2,
    LinearVertical = 3

  LayerType* {.size:sizeof(cint), header: "DataTypes.hpp", importcpp: "ldtk::LayerType", pure.} = enum
    IntGrid = 0,
    Entities = 1,
    Tiles = 2,
    AutoLayer = 3

  Dir* {.size:sizeof(cint), header: "DataTypes.hpp", importcpp: "ldtk::Dir", pure.} = enum
    None = 0,
    North = 1,
    NorthEast = 2,
    East = 3,
    SouthEast = 4,
    South = 5,
    SouthWest = 6,
    West = 7,
    NorthWest = 8,
    Overlap = 9,
    Over = 10,
    Under = 11

  FieldType* {.size:sizeof(cint), header: "DataTypes.hpp", importcpp: "ldtk::FieldType", pure.} = enum
    Int = 0,
    Float = 1,
    Bool = 2,
    String = 3,
    Color = 4,
    Point = 5,
    Enum = 6,
    FilePath = 7,
    Tile = 8,
    EntityRef = 9,
    ArrayInt = 10,
    ArrayFloat = 11,
    ArrayBool = 12,
    ArrayString = 13,
    ArrayColor = 14,
    ArrayPoint = 15,
    ArrayEnum = 16,
    ArrayFilePath = 17,
    ArrayTile = 18,
    ArrayEntityRef = 19

  Point*[T] {.header: "DataTypes.hpp", incompleteStruct, importcpp: "ldtk::Point".} = object
  Rect*[T] {.header: "DataTypes.hpp", incompleteStruct, importcpp: "ldtk::Rect".} = object
  NineSliceBorders* {.header: "DataTypes.hpp", importcpp: "ldtk::NineSliceBorders".} = object
    top*: cint
    right*: cint
    bottom*: cint
    left*: cint
  Color* {.header: "DataTypes.hpp", importcpp: "ldtk::Color".} = object
    r*: uint8
    g*: uint8
    b*: uint8
    a*: uint8
  Vertex* {.header: "DataTypes.hpp", importcpp: "ldtk::Vertex".} = object
    pos*: FloatPoint
    tex*: IntPoint
  IntGridValue* {.header: "DataTypes.hpp", importcpp: "ldtk::IntGridValue".} = object
    value*: cint
    name*: cstring
    color*: Color
  TileRect* {.header: "DataTypes.hpp", importcpp: "ldtk::TileRect".} = object
    bounds*: IntRect
    m_tileset*: ptr Tileset
  IID* {.header: "DataTypes.hpp", importcpp: "ldtk::IID".} = object
    m_iid*: cstring
  EntityRef* {.header: "DataTypes.hpp", importcpp: "ldtk::EntityRef".} = object
    entity_iid*: IID
    layer_iid*: IID
    level_iid*: IID
    world_iid*: IID
    `ref`*: ptr Entity
  hash* {.header: "DataTypes.hpp", importcpp: "std::__1::hash".} = object
  FilePath* {.header: "DataTypes.hpp", importcpp: "ldtk::FilePath", byref.} = object
  IntPoint* {.header: "DataTypes.hpp", importcpp: "ldtk::IntPoint".} = Point[cint]
  UIntPoint* {.header: "DataTypes.hpp", importcpp: "ldtk::UIntPoint".} = Point[cuint]
  FloatPoint* {.header: "DataTypes.hpp", importcpp: "ldtk::FloatPoint".} = Point[cfloat]
  IntRect* {.header: "DataTypes.hpp", importcpp: "ldtk::IntRect".} = Rect[cint]
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
