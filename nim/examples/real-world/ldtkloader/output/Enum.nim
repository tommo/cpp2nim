# Auto-generated Nim bindings for upstream/include/LDtkLoader/Enum.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types, Tileset, DataTypes

proc hasIcon*[E](self: ptr EnumValue): bool {.importcpp: "hasIcon".}
proc getIconTileset*[E, T](self: ptr EnumValue): var Tileset {.importcpp: "getIconTileset".}
proc getIconTextureRect*[E](self: ptr EnumValue): var IntRect {.importcpp: "getIconTextureRect".}
proc assign*[E](self: ptr Enum, a00: Enum) {.importcpp: "# = #".}
proc `[]`*[E](self: ptr Enum, val_name: cstring): var EnumValue {.importcpp: "#[#]".}
proc hasIcons*[E](self: ptr Enum): bool {.importcpp: "hasIcons".}
proc getIconsTileset*[E, T](self: ptr Enum): var Tileset {.importcpp: "getIconsTileset".}
proc newEnumValue*(name: cstring, id: cint, tile_rect: IntRect, color: Color, enum_type: Enum): EnumValue {.constructor,importcpp: "ldtk::EnumValue(@)".}
proc newEnum*(a00: Enum): Enum {.constructor,importcpp: "ldtk::Enum(@)".}
proc newEnum*(j: cint): Enum {.constructor,importcpp: "ldtk::Enum(@)".}
