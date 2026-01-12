# Auto-generated Nim bindings for upstream/include/LDtkLoader/Layer.hpp
# Generated: 2026-01-11T20:30:43+08:00

import shared_types, Entity, Tile, Tileset, DataTypes

proc assign*(self: ptr Layer, a00: Layer) {.importcpp: "# = #".}
proc getType*(self: ptr Layer): var LayerType {.importcpp: "getType".}
proc getName*(self: ptr Layer): var cstring {.importcpp: "getName".}
proc isVisible*(self: ptr Layer): bool {.importcpp: "isVisible".}
proc getCellSize*(self: ptr Layer): cint {.importcpp: "getCellSize".}
proc getGridSize*(self: ptr Layer): var IntPoint {.importcpp: "getGridSize".}
proc getOffset*(self: ptr Layer): var IntPoint {.importcpp: "getOffset".}
proc getOpacity*(self: ptr Layer): cfloat {.importcpp: "getOpacity".}
proc hasTileset*(self: ptr Layer): bool {.importcpp: "hasTileset".}
proc getTileset*[T](self: ptr Layer): var Tileset {.importcpp: "getTileset".}
proc allTiles*(self: ptr Layer): cint {.importcpp: "allTiles".}
proc getTile*[T](self: ptr Layer, grid_x: cint, grid_y: cint): var Tile {.importcpp: "getTile".}
proc getTilesByEnumTag*(self: ptr Layer): cint {.importcpp: "getTilesByEnumTag".}
proc getIntGridVal*(self: ptr Layer, grid_x: cint, grid_y: cint): var IntGridValue {.importcpp: "getIntGridVal".}
proc getIntGridValPositions*(self: ptr Layer): cint {.importcpp: "getIntGridValPositions".}
proc hasEntity*(self: ptr Layer, entity_name: cstring): bool {.importcpp: "hasEntity".}
proc allEntities*(self: ptr Layer): cint {.importcpp: "allEntities".}
proc getEntitiesByName*(self: ptr Layer): cint {.importcpp: "getEntitiesByName".}
proc getEntitiesByTag*(self: ptr Layer): cint {.importcpp: "getEntitiesByTag".}
proc getEntity*[E](self: ptr Layer, entity_iid: IID): var Entity {.importcpp: "getEntity".}
proc getCoordIdAt*(self: ptr Layer, grid_x: cint, grid_y: cint): cint {.importcpp: "getCoordIdAt".}
proc getGridPositionFromCoordId*(self: ptr Layer, coord_id: cint): IntPoint {.importcpp: "getGridPositionFromCoordId".}
proc newLayer*(a00: Layer): Layer {.constructor,importcpp: "ldtk::Layer(@)".}
proc newLayer*(j: cint, w: ptr World, l: ptr Level): Layer {.constructor,importcpp: "ldtk::Layer(@)".}
