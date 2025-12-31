## Tests for config module.

import std/[unittest, json, options, tables, os, strutils]
import ../src/cpp2nim/config

suite "initConfig":
  test "default values":
    let cfg = initConfig()
    check cfg.searchPaths.len == 0
    check cfg.extraArgs.len == 0
    check cfg.cMode == false
    check cfg.outputDir == "."
    check cfg.camelCase == true
    check cfg.parallel == true
    check cfg.rootNamespace.isNone
    check cfg.numWorkers.isNone

  test "custom values":
    let cfg = initConfig(
      searchPaths = @["/usr/include"],
      extraArgs = @["-std=c++17"],
      cMode = true,
      outputDir = "/tmp/out",
      camelCase = false
    )
    check cfg.searchPaths == @["/usr/include"]
    check cfg.extraArgs == @["-std=c++17"]
    check cfg.cMode == true
    check cfg.outputDir == "/tmp/out"
    check cfg.camelCase == false

suite "defaultConfig":
  test "returns default config":
    let cfg = defaultConfig()
    check cfg.searchPaths.len == 0
    check cfg.parallel == true

suite "effectiveWorkers":
  test "uses numWorkers when set":
    let cfg = initConfig(numWorkers = some(4))
    check cfg.effectiveWorkers == 4

  test "uses cpu count when not set":
    let cfg = initConfig()
    check cfg.effectiveWorkers > 0  # Should be CPU count

suite "JSON serialization":
  test "round-trip":
    let original = initConfig(
      searchPaths = @["/usr/include", "/opt/local/include"],
      extraArgs = @["-std=c++17", "-DDEBUG"],
      cMode = true,
      outputDir = "/tmp/output",
      rootNamespace = some("mylib"),
      camelCase = false,
      typeRenames = {"OldType": "NewType"}.toTable,
      ignoreTypes = @["IgnoreMe"],
      parallel = false,
      numWorkers = some(8)
    )

    let jsonNode = %original
    let restored = toConfig(jsonNode)

    check restored.searchPaths == original.searchPaths
    check restored.extraArgs == original.extraArgs
    check restored.cMode == original.cMode
    check restored.outputDir == original.outputDir
    check restored.rootNamespace == original.rootNamespace
    check restored.camelCase == original.camelCase
    check restored.typeRenames == original.typeRenames
    check restored.ignoreTypes == original.ignoreTypes
    check restored.parallel == original.parallel
    check restored.numWorkers == original.numWorkers

  test "handles none values":
    let cfg = initConfig()
    let jsonNode = %cfg
    let restored = toConfig(jsonNode)

    check restored.rootNamespace.isNone
    check restored.numWorkers.isNone

suite "mergeWith":
  test "combines search paths":
    let base = initConfig(searchPaths = @["/usr/include"])
    let other = initConfig(searchPaths = @["/opt/include"])
    let merged = base.mergeWith(other)

    check merged.searchPaths == @["/usr/include", "/opt/include"]

  test "other overrides booleans":
    let base = initConfig(camelCase = true)
    let other = initConfig(camelCase = false)
    let merged = base.mergeWith(other)

    check merged.camelCase == false

  test "merges type renames":
    let base = initConfig(typeRenames = {"A": "B"}.toTable)
    let other = initConfig(typeRenames = {"C": "D"}.toTable)
    let merged = base.mergeWith(other)

    check merged.typeRenames["A"] == "B"
    check merged.typeRenames["C"] == "D"

  test "other overrides output dir when set":
    let base = initConfig(outputDir = "/old")
    let other = initConfig(outputDir = "/new")
    let merged = base.mergeWith(other)

    check merged.outputDir == "/new"

suite "validateOrWarn":
  test "warns on nonexistent output dir":
    let cfg = initConfig(outputDir = "/nonexistent/path/12345")
    let warnings = cfg.validateOrWarn()

    check warnings.len > 0
    check "Output directory" in warnings[0]

  test "warns on nonexistent search path":
    let cfg = initConfig(searchPaths = @["/nonexistent/include/12345"])
    let warnings = cfg.validateOrWarn()

    check warnings.len > 0
    check "Search path" in warnings[0]

  test "warns on invalid worker count":
    let cfg = initConfig(numWorkers = some(0))
    let warnings = cfg.validateOrWarn()

    check warnings.len > 0
    check "numWorkers" in warnings[0]

  test "no warnings for valid config":
    let cfg = initConfig()  # Defaults are valid
    let warnings = cfg.validateOrWarn()

    check warnings.len == 0

suite "global options":
  test "set and get":
    setGlobalOption("testKey", %"testValue")
    let value = getGlobalOption("testKey")
    check value.getStr == "testValue"

  test "get default":
    let value = getGlobalOption("nonexistent", %"default")
    check value.getStr == "default"

  test "clear":
    setGlobalOption("testKey", %"value")
    clearGlobalOptions()
    let value = getGlobalOption("testKey")
    check value.kind == JNull


when isMainModule:
  echo "Running config tests..."
