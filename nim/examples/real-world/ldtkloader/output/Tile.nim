# Auto-generated Nim bindings for upstream/include/LDtkLoader/Tile.hpp
# Generated: 2026-01-11T20:30:43+08:00

import shared_types, DataTypes

proc getPosition*[T](self: ptr Tile): IntPoint {.importcpp: "getPosition".}
proc getGridPosition*[T](self: ptr Tile): IntPoint {.importcpp: "getGridPosition".}
proc getWorldPosition*[T](self: ptr Tile): IntPoint {.importcpp: "getWorldPosition".}
proc getTextureRect*[T](self: ptr Tile): IntRect {.importcpp: "getTextureRect".}
proc getVertices*[T, V](self: ptr Tile): array[4, Vertex] {.importcpp: "getVertices".}
proc newTile*(l: ptr Layer, pos: IntPoint, coord_id: cint, tile_id: cint, flips: cint, a: cfloat): Tile {.constructor,importcpp: "ldtk::Tile(@)".}
