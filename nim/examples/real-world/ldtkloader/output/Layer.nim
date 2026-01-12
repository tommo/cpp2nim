# Auto-generated Nim bindings for upstream/include/LDtkLoader/Layer.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, World, Level

proc assign*(self: ptr Layer, a00: Layer) {.importcpp: "# = #".}
proc getType*(self: ptr Layer): cint {.importcpp: "getType".}
proc getName*(self: ptr Layer): var cstring {.importcpp: "getName".}
proc isVisible*(self: ptr Layer): bool {.importcpp: "isVisible".}
proc getCellSize*(self: ptr Layer): cint {.importcpp: "getCellSize".}
proc getGridSize*(self: ptr Layer): cint {.importcpp: "getGridSize".}
proc getOffset*(self: ptr Layer): cint {.importcpp: "getOffset".}
proc getOpacity*(self: ptr Layer): cfloat {.importcpp: "getOpacity".}
proc hasTileset*(self: ptr Layer): bool {.importcpp: "hasTileset".}
proc getTileset*(self: ptr Layer): cint {.importcpp: "getTileset".}
proc allTiles*(self: ptr Layer): cint {.importcpp: "allTiles".}
proc getTile*(self: ptr Layer): cint {.importcpp: "getTile".}
proc getTilesByEnumTag*(self: ptr Layer): cint {.importcpp: "getTilesByEnumTag".}
proc getIntGridVal*(self: ptr Layer): cint {.importcpp: "getIntGridVal".}
proc getIntGridValPositions*(self: ptr Layer): cint {.importcpp: "getIntGridValPositions".}
proc hasEntity*(self: ptr Layer, entity_name: cstring): bool {.importcpp: "hasEntity".}
proc allEntities*(self: ptr Layer): cint {.importcpp: "allEntities".}
proc getEntitiesByName*(self: ptr Layer): cint {.importcpp: "getEntitiesByName".}
proc getEntitiesByTag*(self: ptr Layer): cint {.importcpp: "getEntitiesByTag".}
proc getEntity*(self: ptr Layer): cint {.importcpp: "getEntity".}
proc getCoordIdAt*(self: ptr Layer, grid_x: cint, grid_y: cint): cint {.importcpp: "getCoordIdAt".}
proc getGridPositionFromCoordId*(self: ptr Layer): cint {.importcpp: "getGridPositionFromCoordId".}
proc newLayer*(a00: Layer): Layer {.constructor,importcpp: "ldtk::Layer(@)".}
proc newLayer*(j: cint, w: ptr World, l: ptr Level): Layer {.constructor,importcpp: "ldtk::Layer(@)".}
