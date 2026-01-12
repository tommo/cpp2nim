# Auto-generated Nim bindings for upstream/include/LDtkLoader/Utils.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types

proc getLayerTypeFromString*(): cint {.importc: "ldtk::getLayerTypeFromString".}
proc getWorldLayoutFromString*(): cint {.importc: "ldtk::getWorldLayoutFromString".}
proc getDirFromString*(): cint {.importc: "ldtk::getDirFromString".}
proc getFieldTypeFromString*(): cint {.importc: "ldtk::getFieldTypeFromString".}
proc print_error*(fn: cstring, msg: cstring) {.importc: "ldtk::print_error".}
proc print_json_error*(msg: cstring) {.importc: "ldtk::print_json_error".}
