# Auto-generated Nim bindings for upstream/include/LDtkLoader/Project.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types, World, EntityDef, Enum, Tileset, LayerDef, DataTypes

proc assign*(self: ptr Project, a00: Project) {.importcpp: "# = #".}
proc loadFromFile*(self: ptr Project, filepath: cstring) {.importcpp: "loadFromFile".}
proc loadFromFile*(self: ptr Project, filepath: cstring, file_loader: cint) {.importcpp: "loadFromFile".}
proc loadFromMemory*(self: ptr Project, bytes: cint) {.importcpp: "loadFromMemory".}
proc loadFromMemory*(self: ptr Project, data: ptr cuchar, size: csize_t) {.importcpp: "loadFromMemory".}
proc getFilePath*(self: ptr Project): var FilePath {.importcpp: "getFilePath".}
proc getDefaultPivot*(self: ptr Project): var FloatPoint {.importcpp: "getDefaultPivot".}
proc getDefaultCellSize*(self: ptr Project): cint {.importcpp: "getDefaultCellSize".}
proc getBgColor*[C](self: ptr Project): var Color {.importcpp: "getBgColor".}
proc getLayerDef*(self: ptr Project, id: cint): var LayerDef {.importcpp: "getLayerDef".}
proc getLayerDef*(self: ptr Project, name: cstring): var LayerDef {.importcpp: "getLayerDef".}
proc getEntityDef*[E](self: ptr Project, id: cint): var EntityDef {.importcpp: "getEntityDef".}
proc getEntityDef*[E](self: ptr Project, name: cstring): var EntityDef {.importcpp: "getEntityDef".}
proc allTilesets*(self: ptr Project): cint {.importcpp: "allTilesets".}
proc getTileset*[T](self: ptr Project, id: cint): var Tileset {.importcpp: "getTileset".}
proc getTileset*[T](self: ptr Project, name: cstring): var Tileset {.importcpp: "getTileset".}
proc getEnum*[E](self: ptr Project, id: cint): var Enum {.importcpp: "getEnum".}
proc getEnum*[E](self: ptr Project, name: cstring): var Enum {.importcpp: "getEnum".}
proc allWorlds*(self: ptr Project): cint {.importcpp: "allWorlds".}
proc getWorld*(self: ptr Project): var World {.importcpp: "getWorld".}
proc getWorld*(self: ptr Project, name: cstring): var World {.importcpp: "getWorld".}
proc getWorld*(self: ptr Project, iid: IID): var World {.importcpp: "getWorld".}
proc allTocEntities*(self: ptr Project): cint {.importcpp: "allTocEntities".}
proc getTocEntitiesByName*(self: ptr Project): cint {.importcpp: "getTocEntitiesByName".}
proc newProject*(): Project {.constructor,importcpp: "ldtk::Project".}
proc newProject*(a00: Project): Project {.constructor,importcpp: "ldtk::Project(@)".}
