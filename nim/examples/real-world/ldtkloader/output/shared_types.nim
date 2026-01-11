# Auto-generated shared types for cpp2nim
# Generated: 2026-01-11T16:20:12+08:00

type
  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*
  ConstPtr*[T] = ptr T  ## const T* return type

  # Forward declarations / Base types
  FieldsContainer* {.header: "FieldsContainer.hpp", importcpp: "ldtk::FieldsContainer", inheritable, byref.} = object
  TagsContainer* {.header: "TagsContainer.hpp", importcpp: "ldtk::TagsContainer", inheritable, byref.} = object

  # Generic types (must be defined before instantiations)
  Point*[T] {.header: "DataTypes.hpp", importcpp: "ldtk::Point".} = object
    x*: T
    y*: T
  Rect*[T] {.header: "DataTypes.hpp", importcpp: "ldtk::Rect".} = object
    x*: T
    y*: T
    width*: T
    height*: T
  IID* {.header: "DataTypes.hpp", importcpp: "ldtk::IID".} = object
    m_iid*: cstring
  Project* {.header: "Project.hpp", importcpp: "ldtk::Project", byref.} = object
    iid*: IID

type
  Layer* {.header: "Layer.hpp", importcpp: "ldtk::Layer", byref.} = object
    level*: ptr Level
    iid*: IID
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
  IntGridValue* {.header: "DataTypes.hpp", importcpp: "ldtk::IntGridValue".} = object
    value*: cint
    name*: cstring
    color*: Color
  TileRect* {.header: "DataTypes.hpp", importcpp: "ldtk::TileRect".} = object
    bounds*: IntRect
    m_tileset*: ptr Tileset
  EntityRef* {.header: "DataTypes.hpp", importcpp: "ldtk::EntityRef".} = object
    entity_iid*: IID
    layer_iid*: IID
    level_iid*: IID
    world_iid*: IID
    `ref`*: ptr Entity
  FilePath* {.header: "DataTypes.hpp", importcpp: "ldtk::FilePath", byref.} = object
  IntPoint* {.header: "DataTypes.hpp", importcpp: "ldtk::IntPoint".} = Point[cint]
  FloatPoint* {.header: "DataTypes.hpp", importcpp: "ldtk::FloatPoint".} = Point[cfloat]
  IntRect* {.header: "DataTypes.hpp", importcpp: "ldtk::IntRect".} = Rect[cint]
  EntityDef* {.header: "EntityDef.hpp", importcpp: "ldtk::EntityDef", byref.} = object of TagsContainer
    name*: cstring
    uid*: cint
    size*: IntPoint
    color*: Color
    pivot*: FloatPoint
    tileset*: ptr Tileset
    texture_rect*: IntRect
    fields*: cint
    nine_slice_borders*: NineSliceBorders
  Tile* {.header: "Tile.hpp", importcpp: "ldtk::Tile", byref.} = object
    layer*: ptr Layer
    coordId*: cint
    tileId*: cint
    flipX*: bool
    flipY*: bool
    alpha*: cfloat
  Entity* {.header: "Entity.hpp", importcpp: "ldtk::Entity", byref.} = object of FieldsContainer
    layer*: ptr Layer
    iid*: IID
  Level* {.header: "Level.hpp", importcpp: "ldtk::Level", byref.} = object of FieldsContainer
    world*: ptr World
    name*: cstring
    iid*: IID
    uid*: cint
    size*: IntPoint
    position*: IntPoint
    bg_color*: Color
    depth*: cint
  Tileset* {.header: "Tileset.hpp", importcpp: "ldtk::Tileset", byref.} = object of TagsContainer
    name*: cstring
    uid*: cint
    path*: cstring
    texture_size*: IntPoint
    tile_size*: cint
    spacing*: cint
    padding*: cint
  World* {.header: "World.hpp", importcpp: "ldtk::World", byref.} = object
    iid*: IID
  EnumValue* {.header: "Enum.hpp", importcpp: "ldtk::EnumValue".} = object
    name*: cstring
    color*: Color
    `type`*: Enum
    id*: cint
    tile_rect*: IntRect
  Enum* {.header: "Enum.hpp", importcpp: "ldtk::Enum", byref.} = object of TagsContainer
    name*: cstring
    uid*: cint
  LayerDef* {.header: "LayerDef.hpp", importcpp: "ldtk::LayerDef", byref.} = object
    `type`*: LayerType
    name*: cstring
    uid*: cint
    cell_size*: cint
    opacity*: cfloat
    offset*: IntPoint
    tile_pivot*: FloatPoint
