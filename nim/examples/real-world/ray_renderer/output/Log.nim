# Auto-generated Nim bindings for headers/Log.h
# Generated: 2025-12-31T16:44:49+08:00

import shared_types

type
  LogNull* {.header: "Log.h", importcpp: "Ray::LogNull", byref.} = object of ILog
  LogStdout* {.header: "Log.h", importcpp: "Ray::LogStdout", byref.} = object of ILog

proc info*(self: ptr ILog, fmt: ccstring) {.importcpp: "Info".}
proc warning*(self: ptr ILog, fmt: ccstring) {.importcpp: "Warning".}
proc error*(self: ptr ILog, fmt: ccstring) {.importcpp: "Error".}
proc info*(self: ptr LogNull, fmt: ccstring) {.importcpp: "Info".}
proc warning*(self: ptr LogNull, fmt: ccstring) {.importcpp: "Warning".}
proc error*(self: ptr LogNull, fmt: ccstring) {.importcpp: "Error".}
proc info*(self: ptr LogStdout, fmt: ccstring) {.importcpp: "Info".}
proc warning*(self: ptr LogStdout, fmt: ccstring) {.importcpp: "Warning".}
proc error*(self: ptr LogStdout, fmt: ccstring) {.importcpp: "Error".}
