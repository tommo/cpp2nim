# Auto-generated Nim bindings for upstream/include/LDtkLoader/containers/TagsContainer.hpp
# Generated: 2026-01-11T20:30:43+08:00

import shared_types

proc hasTag*[T](self: ptr TagsContainer, tag: cstring): bool {.importcpp: "hasTag".}
proc allTags*[T](self: ptr TagsContainer): cint {.importcpp: "allTags".}
proc newTagsContainer*(j: cint): TagsContainer {.constructor,importcpp: "ldtk::TagsContainer(@)".}
