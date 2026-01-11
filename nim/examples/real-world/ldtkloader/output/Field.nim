# Auto-generated Nim bindings for upstream/include/LDtkLoader/Field.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types

type
  IField* {.header: "Field.hpp", importcpp: "ldtk::IField".} = object of RootObj
  Field*[T] {.header: "Field.hpp", incompleteStruct, importcpp: "ldtk::Field".} = object of IField
  ArrayField*[T] {.header: "Field.hpp", incompleteStruct, importcpp: "ldtk::ArrayField".} = object of IField
  value_type* {.header: "Field.hpp", importcpp: "ldtk::Field::value_type".} = T
  value_type* {.header: "Field.hpp", importcpp: "ldtk::ArrayField::value_type".} = T

proc assign*(self: ptr IField, a00: IField) {.importcpp: "# = #".}
proc is_null*(self: ptr Field): bool {.importcpp: "is_null".}
proc newIField*(): IField {.constructor,importcpp: "ldtk::IField".}
proc newIField*(a00: IField): IField {.constructor,importcpp: "ldtk::IField(@)".}
proc newArrayField*[T](): ArrayField {.constructor,importcpp: "ldtk::ArrayField".}
proc newArrayField*[T](vals: cint): ArrayField {.constructor,importcpp: "ldtk::ArrayField(@)".}
