# Auto-generated Nim bindings for upstream/include/LDtkLoader/World.hpp
# Generated: 2026-01-11T20:30:43+08:00

import shared_types, EntityDef, Enum, Tileset, LayerDef, DataTypes, Level

proc assign*(self: ptr World, a00: World) {.importcpp: "# = #".}
proc getName*(self: ptr World): var cstring {.importcpp: "getName".}
proc getDefaultPivot*(self: ptr World): var FloatPoint {.importcpp: "getDefaultPivot".}
proc getDefaultCellSize*(self: ptr World): cint {.importcpp: "getDefaultCellSize".}
proc getBgColor*[C](self: ptr World): var Color {.importcpp: "getBgColor".}
proc getLayout*(self: ptr World): var WorldLayout {.importcpp: "getLayout".}
proc getLayerDef*(self: ptr World, id: cint): var LayerDef {.importcpp: "getLayerDef".}
proc getLayerDef*(self: ptr World, name: cstring): var LayerDef {.importcpp: "getLayerDef".}
proc getEntityDef*[E](self: ptr World, id: cint): var EntityDef {.importcpp: "getEntityDef".}
proc getEntityDef*[E](self: ptr World, name: cstring): var EntityDef {.importcpp: "getEntityDef".}
proc allTilesets*(self: ptr World): cint {.importcpp: "allTilesets".}
proc getTileset*[T](self: ptr World, id: cint): var Tileset {.importcpp: "getTileset".}
proc getTileset*[T](self: ptr World, name: cstring): var Tileset {.importcpp: "getTileset".}
proc getEnum*[E](self: ptr World, id: cint): var Enum {.importcpp: "getEnum".}
proc getEnum*[E](self: ptr World, name: cstring): var Enum {.importcpp: "getEnum".}
proc allLevels*(self: ptr World): cint {.importcpp: "allLevels".}
proc getLevel*(self: ptr World, id: cint): var Level {.importcpp: "getLevel".}
proc getLevel*(self: ptr World, name: cstring): var Level {.importcpp: "getLevel".}
proc getLevel*(self: ptr World, iid: IID): var Level {.importcpp: "getLevel".}
proc newWorld*(a00: World): World {.constructor,importcpp: "ldtk::World(@)".}
proc newWorld*(j: cint, p: ptr Project, file_loader: cint, external_levels: bool): World {.constructor,importcpp: "ldtk::World(@)".}
