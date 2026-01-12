# Auto-generated Nim bindings for upstream/include/LDtkLoader/Entity.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, World, Layer

proc assign*[E](self: ptr Entity, a00: Entity) {.importcpp: "# = #".}
proc getName*[E](self: ptr Entity): var cstring {.importcpp: "getName".}
proc getSize*[E](self: ptr Entity): cint {.importcpp: "getSize".}
proc getColor*[E](self: ptr Entity): cint {.importcpp: "getColor".}
proc getPosition*[E](self: ptr Entity): cint {.importcpp: "getPosition".}
proc getGridPosition*[E](self: ptr Entity): cint {.importcpp: "getGridPosition".}
proc getWorldPosition*[E](self: ptr Entity): cint {.importcpp: "getWorldPosition".}
proc getPivot*[E](self: ptr Entity): cint {.importcpp: "getPivot".}
proc hasSprite*[E](self: ptr Entity): bool {.importcpp: "hasSprite".}
proc getTexturePath*[E](self: ptr Entity): var cstring {.importcpp: "getTexturePath".}
proc getTextureRect*[E](self: ptr Entity): cint {.importcpp: "getTextureRect".}
proc hasNineSlice*[E](self: ptr Entity): bool {.importcpp: "hasNineSlice".}
proc getNineSliceBorders*[E](self: ptr Entity): cint {.importcpp: "getNineSliceBorders".}
proc hasTag*[E](self: ptr Entity, tag: cstring): bool {.importcpp: "hasTag".}
proc allTags*[E](self: ptr Entity): cint {.importcpp: "allTags".}
proc allFields*[E](self: ptr Entity): cint {.importcpp: "allFields".}
proc newEntity*(a00: Entity): Entity {.constructor,importcpp: "ldtk::Entity(@)".}
proc newEntity*(j: cint, w: ptr World, l: ptr Layer): Entity {.constructor,importcpp: "ldtk::Entity(@)".}
