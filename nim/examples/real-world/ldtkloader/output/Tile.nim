# Auto-generated Nim bindings for upstream/include/LDtkLoader/Tile.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, Layer

type
  Tile* {.header: "Tile.hpp", importcpp: "ldtk::Tile", byref.} = object
    layer*: ptr Layer
    coordId*: cint
    tileId*: cint
    flipX*: bool
    flipY*: bool
    alpha*: cfloat

proc getPosition*[T](self: ptr Tile): cint {.importcpp: "getPosition".}
proc getGridPosition*[T](self: ptr Tile): cint {.importcpp: "getGridPosition".}
proc getWorldPosition*[T](self: ptr Tile): cint {.importcpp: "getWorldPosition".}
proc getTextureRect*[T](self: ptr Tile): cint {.importcpp: "getTextureRect".}
proc getVertices*[T](self: ptr Tile): cint {.importcpp: "getVertices".}
proc newTile*(l: ptr Layer, pos: cint, coord_id: cint, tile_id: cint, flips: cint, a: cfloat): Tile {.constructor,importcpp: "ldtk::Tile(@)".}
