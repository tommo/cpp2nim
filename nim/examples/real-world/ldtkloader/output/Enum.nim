# Auto-generated Nim bindings for upstream/include/LDtkLoader/Enum.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, Tileset

type
  EnumValue* {.header: "Enum.hpp", importcpp: "ldtk::EnumValue".} = object
    name*: cstring
    color*: cint
    `type`*: Enum
    id*: cint
    tile_rect*: cint
  Enum* {.header: "Enum.hpp", importcpp: "ldtk::Enum", byref.} = object
    name*: cstring
    uid*: cint

proc hasIcon*[E](self: ptr EnumValue): bool {.importcpp: "hasIcon".}
proc getIconTileset*[E, T](self: ptr EnumValue): var Tileset {.importcpp: "getIconTileset".}
proc getIconTextureRect*[E](self: ptr EnumValue): cint {.importcpp: "getIconTextureRect".}
proc assign*[E](self: ptr Enum, a00: Enum) {.importcpp: "# = #".}
proc `[]`*[E](self: ptr Enum, val_name: cstring): var EnumValue {.importcpp: "#[#]".}
proc hasIcons*[E](self: ptr Enum): bool {.importcpp: "hasIcons".}
proc getIconsTileset*[E, T](self: ptr Enum): var Tileset {.importcpp: "getIconsTileset".}
proc newEnumValue*(name: cstring, id: cint, tile_rect: cint, color: cint, enum_type: Enum): EnumValue {.constructor,importcpp: "ldtk::EnumValue(@)".}
proc newEnum*(a00: Enum): Enum {.constructor,importcpp: "ldtk::Enum(@)".}
proc newEnum*(j: cint): Enum {.constructor,importcpp: "ldtk::Enum(@)".}
