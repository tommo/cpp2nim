# Auto-generated Nim bindings for upstream/include/LDtkLoader/Level.hpp
# Generated: 2026-01-12T09:31:55+08:00

import shared_types, World

type
  BgImage* {.header: "Level.hpp", importcpp: "ldtk::Level::BgImage".} = object
    path*: cint
    pos*: cint
    scale*: cint
    crop*: cint

proc assign*(self: ptr Level, a00: Level) {.importcpp: "# = #".}
proc allLayers*(self: ptr Level): cint {.importcpp: "allLayers".}
proc getLayer*(self: ptr Level): cint {.importcpp: "getLayer".}
proc hasBgImage*(self: ptr Level): bool {.importcpp: "hasBgImage".}
proc getBgImage*[B](self: ptr Level): var BgImage {.importcpp: "getBgImage".}
proc allNeighbours*(self: ptr Level): cint {.importcpp: "allNeighbours".}
proc getNeighbours*(self: ptr Level): cint {.importcpp: "getNeighbours".}
proc getNeighbourDirection*(self: ptr Level): cint {.importcpp: "getNeighbourDirection".}
proc newLevel*(a00: Level): Level {.constructor,importcpp: "ldtk::Level(@)".}
proc newLevel*(j: cint, w: ptr World): Level {.constructor,importcpp: "ldtk::Level(@)".}
