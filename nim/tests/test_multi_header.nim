## Test: Multiple header setup with dependencies
##
## Tests parsing of multiple C++ headers with cross-dependencies.

import std/[unittest, os, sets, tables, strutils]
import ../src/cpp2nim/[parser, analyzer, config, models]

const fixturesDir = currentSourcePath().parentDir / "fixtures"

suite "Multi-header dependencies":

  test "parses dependency chain correctly":
    let cfg = initConfig(searchPaths = @[fixturesDir])
    let p = initCppHeaderParser(cfg)

    # Parse all three headers
    let typesHeader = p.parseFile(fixturesDir / "dep_types.h")
    let mathHeader = p.parseFile(fixturesDir / "dep_math.h")
    let graphicsHeader = p.parseFile(fixturesDir / "dep_graphics.h")

    # dep_types.h should provide base types
    check typesHeader.provides.contains("core::EntityId")
    check typesHeader.provides.contains("core::Flags")
    check typesHeader.provides.contains("core::Result")

    # dep_math.h should provide Vec2, Vec3, Transform
    check mathHeader.provides.contains("math::Vec2")
    check mathHeader.provides.contains("math::Vec3")
    check mathHeader.provides.contains("math::Transform")

    # dep_graphics.h should provide graphics types
    check graphicsHeader.provides.contains("graphics::Color")
    check graphicsHeader.provides.contains("graphics::Vertex")
    check graphicsHeader.provides.contains("graphics::Mesh")
    check graphicsHeader.provides.contains("graphics::Renderer")

  test "tracks missing dependencies":
    let cfg = initConfig(searchPaths = @[fixturesDir])
    let p = initCppHeaderParser(cfg)

    let mathHeader = p.parseFile(fixturesDir / "dep_math.h")
    let graphicsHeader = p.parseFile(fixturesDir / "dep_graphics.h")

    # dep_math.h should have missing dependencies on core types
    # (EntityId, Flags, Result are used but not defined locally)
    check mathHeader.missing.len > 0

    # dep_graphics.h should have missing dependencies on math types
    check graphicsHeader.missing.len > 0

  test "analyzer detects shared types":
    let cfg = initConfig(searchPaths = @[fixturesDir])
    let p = initCppHeaderParser(cfg)

    var parseResult = initParseResult()
    for file in ["dep_types.h", "dep_math.h", "dep_graphics.h"]:
      let path = fixturesDir / file
      let header = p.parseFile(path)
      parseResult.headers[path] = header
      parseResult.allDependencies[path] = header.dependencies
      parseResult.allProvides[path] = header.provides
      parseResult.allMissing[path] = header.missing

    let analyzer = initDependencyAnalyzer(cfg)
    let analysis = analyzer.analyze(parseResult)

    # Should detect shared types (types used by multiple files)
    check analysis.sharedTypes.len > 0
    echo "Shared types detected: ", analysis.sharedTypes.len

  test "analyzer builds import graph":
    let cfg = initConfig(searchPaths = @[fixturesDir])
    let p = initCppHeaderParser(cfg)

    var parseResult = initParseResult()
    for file in ["dep_types.h", "dep_math.h", "dep_graphics.h"]:
      let path = fixturesDir / file
      let header = p.parseFile(path)
      parseResult.headers[path] = header
      parseResult.allDependencies[path] = header.dependencies
      parseResult.allProvides[path] = header.provides
      parseResult.allMissing[path] = header.missing

    let analyzer = initDependencyAnalyzer(cfg)
    let analysis = analyzer.analyze(parseResult)

    # Should have import relationships
    check analysis.importGraph.len > 0
    echo "Import graph entries: ", analysis.importGraph.len

    # graphics should import math (uses Vec2, Vec3, Transform)
    for path, imports in analysis.importGraph:
      if "dep_graphics" in path:
        echo "  dep_graphics imports: ", imports

  test "file relationships computed correctly":
    let cfg = initConfig(searchPaths = @[fixturesDir])
    let p = initCppHeaderParser(cfg)

    var parseResult = initParseResult()
    for file in ["dep_types.h", "dep_math.h", "dep_graphics.h"]:
      let path = fixturesDir / file
      let header = p.parseFile(path)
      parseResult.headers[path] = header
      parseResult.allDependencies[path] = header.dependencies
      parseResult.allProvides[path] = header.provides
      parseResult.allMissing[path] = header.missing

    let analyzer = initDependencyAnalyzer(cfg)
    let analysis = analyzer.analyze(parseResult)

    # dep_math should depend on dep_types
    # dep_graphics should depend on both dep_types and dep_math
    check analysis.fileRelationships.len > 0

    for file, deps in analysis.fileRelationships:
      if deps.len > 0:
        echo extractFilename(file), " depends on:"
        for depFile, types in deps:
          echo "  ", extractFilename(depFile), " for: ", types

when isMainModule:
  echo "Running multi-header dependency tests..."
  echo "Fixtures dir: ", fixturesDir
