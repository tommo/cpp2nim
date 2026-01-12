# Auto-generated Nim bindings for upstream/include/LDtkLoader/World.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, Project

proc assign*(self: ptr World, a00: World) {.importcpp: "# = #".}
proc getName*(self: ptr World): var cstring {.importcpp: "getName".}
proc getDefaultPivot*(self: ptr World): cint {.importcpp: "getDefaultPivot".}
proc getDefaultCellSize*(self: ptr World): cint {.importcpp: "getDefaultCellSize".}
proc getBgColor*(self: ptr World): cint {.importcpp: "getBgColor".}
proc getLayout*(self: ptr World): cint {.importcpp: "getLayout".}
proc getLayerDef*(self: ptr World): cint {.importcpp: "getLayerDef".}
proc getEntityDef*(self: ptr World): cint {.importcpp: "getEntityDef".}
proc allTilesets*(self: ptr World): cint {.importcpp: "allTilesets".}
proc getTileset*(self: ptr World): cint {.importcpp: "getTileset".}
proc getEnum*(self: ptr World): cint {.importcpp: "getEnum".}
proc allLevels*(self: ptr World): cint {.importcpp: "allLevels".}
proc getLevel*(self: ptr World): cint {.importcpp: "getLevel".}
proc newWorld*(a00: World): World {.constructor,importcpp: "ldtk::World(@)".}
proc newWorld*(j: cint, p: ptr Project, file_loader: cint, external_levels: bool): World {.constructor,importcpp: "ldtk::World(@)".}
