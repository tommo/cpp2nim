# Auto-generated Nim bindings for upstream/include/LDtkLoader/Project.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types

proc assign*(self: ptr Project, a00: Project) {.importcpp: "# = #".}
proc loadFromFile*(self: ptr Project, filepath: cstring) {.importcpp: "loadFromFile".}
proc loadFromFile*(self: ptr Project, filepath: cstring, file_loader: cint) {.importcpp: "loadFromFile".}
proc loadFromMemory*(self: ptr Project, bytes: cint) {.importcpp: "loadFromMemory".}
proc loadFromMemory*(self: ptr Project, data: ptr cuchar, size: csize_t) {.importcpp: "loadFromMemory".}
proc getFilePath*(self: ptr Project): cint {.importcpp: "getFilePath".}
proc getDefaultPivot*(self: ptr Project): cint {.importcpp: "getDefaultPivot".}
proc getDefaultCellSize*(self: ptr Project): cint {.importcpp: "getDefaultCellSize".}
proc getBgColor*(self: ptr Project): cint {.importcpp: "getBgColor".}
proc getLayerDef*(self: ptr Project): cint {.importcpp: "getLayerDef".}
proc getEntityDef*(self: ptr Project): cint {.importcpp: "getEntityDef".}
proc allTilesets*(self: ptr Project): cint {.importcpp: "allTilesets".}
proc getTileset*(self: ptr Project): cint {.importcpp: "getTileset".}
proc getEnum*(self: ptr Project): cint {.importcpp: "getEnum".}
proc allWorlds*(self: ptr Project): cint {.importcpp: "allWorlds".}
proc getWorld*(self: ptr Project): cint {.importcpp: "getWorld".}
proc allTocEntities*(self: ptr Project): cint {.importcpp: "allTocEntities".}
proc getTocEntitiesByName*(self: ptr Project): cint {.importcpp: "getTocEntitiesByName".}
proc newProject*(): Project {.constructor,importcpp: "ldtk::Project".}
proc newProject*(a00: Project): Project {.constructor,importcpp: "ldtk::Project(@)".}
