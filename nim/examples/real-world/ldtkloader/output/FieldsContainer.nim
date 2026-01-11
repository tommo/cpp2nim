# Auto-generated Nim bindings for upstream/include/LDtkLoader/containers/FieldsContainer.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types

type
  FieldsContainer* {.header: "FieldsContainer.hpp", importcpp: "ldtk::FieldsContainer", byref.} = object of RootObj

proc newFieldsContainer*(): FieldsContainer {.constructor,importcpp: "ldtk::FieldsContainer".}
proc newFieldsContainer*(j: cint, w: ptr World): FieldsContainer {.constructor,importcpp: "ldtk::FieldsContainer(@)".}
