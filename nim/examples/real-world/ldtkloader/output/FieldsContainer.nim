# Auto-generated Nim bindings for upstream/include/LDtkLoader/containers/FieldsContainer.hpp
# Generated: 2026-01-11T20:30:43+08:00

import shared_types

proc newFieldsContainer*(): FieldsContainer {.constructor,importcpp: "ldtk::FieldsContainer".}
proc newFieldsContainer*(j: cint, w: ptr World): FieldsContainer {.constructor,importcpp: "ldtk::FieldsContainer(@)".}
