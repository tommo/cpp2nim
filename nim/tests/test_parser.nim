## Parser tests for cpp2nim.
##
## These tests require libclang. Run with:
##   nim c -d:useLibclang -r tests/test_parser.nim

import std/[unittest, os, sets, tables, options, strutils, sequtils]
import ../src/cpp2nim/[parser, models, config]

const FixturesDir = currentSourcePath().parentDir / "fixtures"

suite "CppHeaderParser - Enums":
  let cfg = defaultConfig()
  let p = initCppHeaderParser(cfg)
  let header = p.parseFile(FixturesDir / "sample_enums.h")

  test "parses simple enum":
    var found = false
    for e in header.enums:
      if e.name == "Color":
        found = true
        check e.items.len == 3
        check e.items[0].name == "RED"
        check e.items[0].value == 0
        check e.items[1].name == "GREEN"
        check e.items[2].name == "BLUE"
    check found

  test "parses enum class":
    var found = false
    for e in header.enums:
      if e.name == "Status":
        found = true
        check e.items.len == 3
        check e.items[0].name == "OK"
        check e.items[1].name == "ERROR"
        check e.items[2].name == "PENDING"
    check found

  test "parses enum with explicit underlying type":
    var found = false
    for e in header.enums:
      if e.name == "Flags":
        found = true
        check e.items.len == 4
        check e.items[0].name == "FLAG_NONE"
        check e.items[0].value == 0
        check e.items[3].name == "FLAG_EXEC"
        check e.items[3].value == 4
    check found

  test "anonymous enums become constants":
    # Anonymous enums should be in constants, not enums
    check header.constants.len >= 1
    var foundMax = false
    var foundMin = false
    for c in header.constants:
      for item in c.items:
        if item.name == "MAX_SIZE":
          foundMax = true
          check item.value == 1024
        if item.name == "MIN_SIZE":
          foundMin = true
          check item.value == 64
    check foundMax
    check foundMin


suite "CppHeaderParser - Structs":
  let cfg = defaultConfig()
  let p = initCppHeaderParser(cfg)
  let header = p.parseFile(FixturesDir / "sample_structs.h")

  test "parses simple struct":
    var found = false
    for s in header.structs:
      if s.name == "Point":
        found = true
        check s.fields.len == 2
        check s.fields[0].name == "x"
        check s.fields[0].typeName.contains("float")
        check s.fields[1].name == "y"
    check found

  test "parses struct with methods":
    var found = false
    for s in header.structs:
      if s.name == "Vector3":
        found = true
        check s.fields.len == 3
    check found
    # Methods should be extracted
    var hasLength = false
    var hasNormalized = false
    for m in header.methods:
      if m.name == "length" and m.className == "Vector3":
        hasLength = true
        check m.isConst
        check m.returnType.contains("float")
      if m.name == "normalized" and m.className == "Vector3":
        hasNormalized = true
    check hasLength
    check hasNormalized

  test "parses struct with inheritance":
    var found = false
    for s in header.structs:
      if s.name == "ColorPoint":
        found = true
        check s.baseTypes.len >= 1
        check s.baseTypes[0].contains("Point")
        check s.fields.len >= 4  # r, g, b, a
    check found

  test "parses union":
    var found = false
    for s in header.structs:
      if s.name == "Data":
        found = true
        check s.isUnion
        check s.fields.len >= 2
    check found

  test "parses namespaced struct":
    var found = false
    for s in header.structs:
      if s.name == "Matrix4x4":
        found = true
        check s.fullyQualified.contains("math")
        check s.fields.len >= 1
    check found

  test "fullyQualified does not contain file path":
    for s in header.structs:
      check not s.fullyQualified.contains("/")
      check not s.fullyQualified.endsWith(".h")

  test "parses template struct":
    # TODO: Template structs not yet extracted - see card #28
    var found = false
    for s in header.structs:
      if s.name == "Container":
        found = true
        check s.templateParams.len == 1
        check s.templateParams[0].name == "T"
        check s.fields.len >= 1
    check found


suite "CppHeaderParser - Functions and Methods":
  let cfg = defaultConfig()
  let p = initCppHeaderParser(cfg)
  let header = p.parseFile(FixturesDir / "sample_functions.h")

  test "parses simple function":
    var found = false
    for m in header.methods:
      if m.name == "add" and m.isPlainFunction:
        found = true
        check m.params.len == 2
        check m.params[0].name == "a"
        check m.params[1].name == "b"
        check m.returnType.contains("int")
    check found

  test "parses function with pointer params":
    var found = false
    for m in header.methods:
      if m.name == "processBuffer" and m.isPlainFunction:
        found = true
        check m.params.len == 2
        check m.params[0].typeName.contains("char")
        check m.params[0].typeName.contains("*") or m.params[0].typeName.contains("pointer")
    check found

  test "parses void function":
    var found = false
    for m in header.methods:
      if m.name == "doNothing" and m.isPlainFunction:
        found = true
        check m.returnType == "void" or m.returnType == ""
        check m.params.len == 0
    check found

  test "parses namespaced function":
    var found = false
    for m in header.methods:
      if m.name == "clamp" and m.isPlainFunction:
        found = true
        check m.fullyQualified.contains("utils")
        check m.params.len == 3
    check found

  test "parses class constructor":
    var found = false
    for c in header.constructors:
      if c.className == "Widget":
        found = true
        check c.params.len == 2
        check c.params[0].name == "width"
        check c.params[1].name == "height"
    check found

  test "parses class methods":
    var hasGetWidth = false
    var hasSetWidth = false
    for m in header.methods:
      if m.className == "Widget":
        if m.name == "getWidth":
          hasGetWidth = true
          check m.isConst
          check m.returnType.contains("int")
        if m.name == "setWidth":
          hasSetWidth = true
          check not m.isConst
          check m.params.len == 1
    check hasGetWidth
    check hasSetWidth

  test "skips private methods":
    for m in header.methods:
      if m.className == "Widget":
        # m_width and m_height are private fields, shouldn't appear
        check m.name != "m_width"
        check m.name != "m_height"

  test "parses static methods":
    var found = false
    for m in header.methods:
      if m.className == "Widget" and m.name == "create":
        found = true
        check m.isStatic
        check not m.isConst
        check m.params.len == 2
    check found


suite "CppHeaderParser - Typedefs":
  let cfg = defaultConfig()
  let p = initCppHeaderParser(cfg)
  let header = p.parseFile(FixturesDir / "sample_functions.h")

  test "parses function pointer typedef":
    var found = false
    for t in header.typedefs:
      if t.name == "Callback":
        found = true
        check t.typedefKind.isSome
        check t.typedefKind.get == "function"
    check found


suite "CppHeaderParser - Anonymous Typedef Structs":
  # Use C-only file to avoid C++ parse errors in C mode
  var cfg = defaultConfig()
  cfg.cMode = true
  let p = initCppHeaderParser(cfg)
  let header = p.parseFile(FixturesDir / "sample_c_structs.h")

  test "parses anonymous typedef struct with function pointers":
    var found = false
    for t in header.typedefs:
      if t.name == "IoCallbacks":
        found = true
        check t.typedefKind.isSome
        check t.typedefKind.get == "struct"
        check t.structData.isSome
        check t.structData.get.fields.len == 3
        check t.structData.get.fields[0].name == "read"
        check t.structData.get.fields[1].name == "skip"
        check t.structData.get.fields[2].name == "eof"
    check found

  test "parses simple anonymous typedef struct":
    var found = false
    for t in header.typedefs:
      if t.name == "SimplePoint":
        found = true
        check t.typedefKind.isSome
        check t.typedefKind.get == "struct"
        check t.structData.isSome
        check t.structData.get.fields.len == 2
        check t.structData.get.fields[0].name == "x"
        check t.structData.get.fields[1].name == "y"
    check found


suite "CppHeaderParser - Dependencies":
  let cfg = defaultConfig()
  let p = initCppHeaderParser(cfg)
  let header = p.parseFile(FixturesDir / "sample_structs.h")

  test "tracks dependencies":
    # ColorPoint depends on Point
    check header.dependencies.len > 0

  test "tracks provides":
    check "Point" in header.provides or header.provides.anyIt(it.contains("Point"))


suite "CppHeaderParser - Config options":
  test "respects cMode flag":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    # C mode should still parse basic structs
    let header = p.parseFile(FixturesDir / "sample_structs.h")
    check header.structs.len >= 1

  test "respects searchPaths":
    var cfg = defaultConfig()
    cfg.searchPaths.add("/usr/include")
    let p = initCppHeaderParser(cfg)
    # Should not crash with extra search paths
    let header = p.parseFile(FixturesDir / "sample_enums.h")
    check header.enums.len >= 1


suite "ParseResult aggregation":
  let cfg = defaultConfig()
  let p = initCppHeaderParser(cfg)

  test "parseFiles aggregates multiple headers":
    var result = initParseResult()
    for fixture in ["sample_enums.h", "sample_structs.h", "sample_functions.h"]:
      let path = FixturesDir / fixture
      let header = p.parseFile(path)
      result.headers[path] = header
      result.allDependencies[path] = header.dependencies
      result.allProvides[path] = header.provides

    check result.headers.len == 3
    check result.allDependencies.len == 3
    check result.allProvides.len == 3


when isMainModule:
  echo "Running parser tests..."
  echo "Fixtures dir: ", FixturesDir
