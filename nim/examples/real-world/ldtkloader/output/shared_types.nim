# Auto-generated shared types for cpp2nim
# Generated: 2026-01-12T09:31:55+08:00

type
  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*
  ConstPtr*[T] = ptr T  ## const T* return type

type
  IField* {.header: "Field.hpp", importcpp: "ldtk::IField".} = object of RootObj
  Entity* {.header: "Entity.hpp", importcpp: "ldtk::Entity", byref.} = object
    layer*: ptr Layer
    iid*: cint
  Layer* {.header: "Layer.hpp", importcpp: "ldtk::Layer", byref.} = object
    level*: ptr Level
    iid*: cint
  Level* {.header: "Level.hpp", importcpp: "ldtk::Level", byref.} = object
    world*: ptr World
    name*: cstring
    iid*: cint
    uid*: cint
    size*: cint
    position*: cint
    bg_color*: cint
    depth*: cint
  Project* {.header: "Project.hpp", importcpp: "ldtk::Project", byref.} = object
    iid*: cint
  Tileset* {.header: "Tileset.hpp", importcpp: "ldtk::Tileset", byref.} = object
    name*: cstring
    uid*: cint
    path*: cstring
    texture_size*: cint
    tile_size*: cint
    spacing*: cint
    padding*: cint
  World* {.header: "World.hpp", importcpp: "ldtk::World", byref.} = object
    iid*: cint
