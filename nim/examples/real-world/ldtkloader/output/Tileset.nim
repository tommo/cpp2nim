# Auto-generated Nim bindings for upstream/include/LDtkLoader/Tileset.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, Project

proc getTileIdAt*[T](self: ptr Tileset, pos_x: cint, pos_y: cint): cint {.importcpp: "getTileIdAt".}
proc getTileTexturePos*[T](self: ptr Tileset): cint {.importcpp: "getTileTexturePos".}
proc getTileCustomData*[T](self: ptr Tileset, tile_id: cint): var cstring {.importcpp: "getTileCustomData".}
proc getTileEnumTags*[T](self: ptr Tileset): cint {.importcpp: "getTileEnumTags".}
proc hasEnumTags*[T](self: ptr Tileset): bool {.importcpp: "hasEnumTags".}
proc getEnumTagsEnum*[T](self: ptr Tileset): cint {.importcpp: "getEnumTagsEnum".}
proc getTilesByEnumTag*[T](self: ptr Tileset): cint {.importcpp: "getTilesByEnumTag".}
proc newTileset*(j: cint, p: ptr Project): Tileset {.constructor,importcpp: "ldtk::Tileset(@)".}
