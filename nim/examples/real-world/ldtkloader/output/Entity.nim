# Auto-generated Nim bindings for upstream/include/LDtkLoader/Entity.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types, DataTypes

proc assign*[E](self: ptr Entity, a00: Entity) {.importcpp: "# = #".}
proc getName*[E](self: ptr Entity): var cstring {.importcpp: "getName".}
proc getSize*[E](self: ptr Entity): var IntPoint {.importcpp: "getSize".}
proc getColor*[C, E](self: ptr Entity): var Color {.importcpp: "getColor".}
proc getPosition*[E](self: ptr Entity): var IntPoint {.importcpp: "getPosition".}
proc getGridPosition*[E](self: ptr Entity): var IntPoint {.importcpp: "getGridPosition".}
proc getWorldPosition*[E](self: ptr Entity): IntPoint {.importcpp: "getWorldPosition".}
proc getPivot*[E](self: ptr Entity): var FloatPoint {.importcpp: "getPivot".}
proc hasSprite*[E](self: ptr Entity): bool {.importcpp: "hasSprite".}
proc getTexturePath*[E](self: ptr Entity): var cstring {.importcpp: "getTexturePath".}
proc getTextureRect*[E](self: ptr Entity): var IntRect {.importcpp: "getTextureRect".}
proc hasNineSlice*[E](self: ptr Entity): bool {.importcpp: "hasNineSlice".}
proc getNineSliceBorders*[E, N](self: ptr Entity): var NineSliceBorders {.importcpp: "getNineSliceBorders".}
proc hasTag*[E](self: ptr Entity, tag: cstring): bool {.importcpp: "hasTag".}
proc allTags*[E](self: ptr Entity): cint {.importcpp: "allTags".}
proc allFields*[E](self: ptr Entity): cint {.importcpp: "allFields".}
proc newEntity*(a00: Entity): Entity {.constructor,importcpp: "ldtk::Entity(@)".}
proc newEntity*(j: cint, w: ptr World, l: ptr Layer): Entity {.constructor,importcpp: "ldtk::Entity(@)".}
