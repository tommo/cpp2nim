# Auto-generated Nim bindings for upstream/include/LDtkLoader/Utils.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types, DataTypes

proc getLayerTypeFromString*(type_name: cstring): LayerType {.importc: "ldtk::getLayerTypeFromString".}
proc getWorldLayoutFromString*(layout_name: cstring): WorldLayout {.importc: "ldtk::getWorldLayoutFromString".}
proc getDirFromString*[D](dir_name: cstring): Dir {.importc: "ldtk::getDirFromString".}
proc getFieldTypeFromString*(fieldtype_name: cstring): FieldType {.importc: "ldtk::getFieldTypeFromString".}
proc print_error*(fn: cstring, msg: cstring) {.importc: "ldtk::print_error".}
proc print_json_error*(msg: cstring) {.importc: "ldtk::print_json_error".}
