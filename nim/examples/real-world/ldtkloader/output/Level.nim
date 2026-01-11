# Auto-generated Nim bindings for upstream/include/LDtkLoader/Level.hpp
# Generated: 2026-01-11T16:20:12+08:00

import shared_types, DataTypes, Layer

type
  BgImage* {.header: "Level.hpp", importcpp: "ldtk::Level::BgImage".} = object
    path*: FilePath
    pos*: IntPoint
    scale*: FloatPoint
    crop*: IntRect

proc assign*(self: ptr Level, a00: Level) {.importcpp: "# = #".}
proc allLayers*(self: ptr Level): cint {.importcpp: "allLayers".}
proc getLayer*(self: ptr Level, layer_name: cstring): var Layer {.importcpp: "getLayer".}
proc getLayer*(self: ptr Level, iid: IID): var Layer {.importcpp: "getLayer".}
proc hasBgImage*(self: ptr Level): bool {.importcpp: "hasBgImage".}
proc getBgImage*[B](self: ptr Level): var BgImage {.importcpp: "getBgImage".}
proc allNeighbours*(self: ptr Level): cint {.importcpp: "allNeighbours".}
proc getNeighbours*(self: ptr Level): cint {.importcpp: "getNeighbours".}
proc getNeighbourDirection*[D](self: ptr Level, level: Level): Dir {.importcpp: "getNeighbourDirection".}
proc newLevel*(a00: Level): Level {.constructor,importcpp: "ldtk::Level(@)".}
proc newLevel*(j: cint, w: ptr World): Level {.constructor,importcpp: "ldtk::Level(@)".}
