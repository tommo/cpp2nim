## Code generation tests for cpp2nim.
##
## Tests that generated Nim code compiles with `nim check`.
## Requires libclang. Run with:
##   nim c -d:useLibclang -r tests/test_codegen.nim

import std/[unittest, os, sets, tables, osproc, times, streams, strutils, options]
import ../src/cpp2nim/[parser, models, config, generator]

const FixturesDir = currentSourcePath().parentDir / "fixtures"

proc generateCode(header: ParsedHeader, cfg: Config, filename: string): string =
  ## Generate Nim code from parsed header.
  # Pre-scan for base classes so inheritance generates correctly
  var baseClasses: HashSet[string]
  for s in header.structs:
    for bt in s.baseTypes:
      baseClasses.incl(bt)
  for c in header.classes:
    for bt in c.baseTypes:
      baseClasses.incl(bt)
  let gen = initNimCodeGenerator(cfg, baseClasses = baseClasses)
  let incl = extractFilename(filename)

  # Collect types
  var typeCode = ""
  for e in header.enums:
    typeCode.add(gen.generateEnum(e, incl))
  for s in header.structs:
    typeCode.add(gen.generateStruct(s, incl))
  for c in header.classes:
    typeCode.add(gen.generateClass(c, incl))
  for t in header.typedefs:
    typeCode.add(gen.generateTypedef(t, incl))

  result = "# Auto-generated test\n\n"
  # Helper types for C++ bindings
  result.add("type\n")
  result.add("  ccstring* = cstring  ## const char*\n")
  result.add("  ConstPointer* = pointer  ## const void*\n")
  result.add("\n")

  if typeCode.len > 0:
    result.add("type\n")
    result.add(typeCode)
    result.add("\n")

  # Collect procs
  var visited: HashSet[string]
  for m in header.methods:
    let methodCode = gen.generateMethod(m, visited, @[])
    if methodCode.len > 0:
      result.add(methodCode)

  var dupTracker: Table[string, bool]
  for c in header.constructors:
    result.add(gen.generateConstructor(c, dupTracker))

  # Collect constants
  var constCode = ""
  for c in header.constants:
    constCode.add(gen.generateConst(c))

  if constCode.len > 0:
    result.add("const\n")
    result.add(constCode)


proc nimCheck(code: string, name: string): bool =
  ## Run nim check on generated code.
  let testDir = getTempDir() / "cpp2nim_test"
  createDir(testDir)
  defer: removeDir(testDir)

  let outputPath = testDir / name.changeFileExt(".nim")
  writeFile(outputPath, code)

  # Use startProcess with timeout to avoid hanging
  let process = startProcess("nim", args = ["check", "--hints:off", outputPath], options = {poUsePath, poStdErrToStdOut})
  defer: process.close()

  # Wait max 10 seconds
  let startTime = epochTime()
  while process.running and (epochTime() - startTime) < 10.0:
    sleep(100)

  if process.running:
    process.kill()
    echo "\n=== nim check TIMEOUT for ", name, " ==="
    return false

  let exitCode = process.waitForExit()
  if exitCode != 0:
    let output = process.outputStream.readAll()
    echo "\n=== nim check FAILED for ", name, " ==="
    echo "Generated code:"
    echo code
    echo "Error:"
    echo output
  return exitCode == 0


suite "Code Generation - nim check validation":
  let cfg = defaultConfig()
  let p = initCppHeaderParser(cfg)

  test "sample_enums.h generates valid Nim":
    let header = p.parseFile(FixturesDir / "sample_enums.h")
    let code = generateCode(header, cfg, "sample_enums.h")
    check nimCheck(code, "sample_enums")

  test "sample_structs.h generates valid Nim":
    let header = p.parseFile(FixturesDir / "sample_structs.h")
    let code = generateCode(header, cfg, "sample_structs.h")
    check nimCheck(code, "sample_structs")

  test "sample_functions.h generates valid Nim":
    let header = p.parseFile(FixturesDir / "sample_functions.h")
    let code = generateCode(header, cfg, "sample_functions.h")
    check nimCheck(code, "sample_functions")

  test "examples/simple/input.h generates valid Nim":
    let inputPath = FixturesDir.parentDir.parentDir / "examples" / "simple" / "input.h"
    if fileExists(inputPath):
      let header = p.parseFile(inputPath)
      let code = generateCode(header, cfg, "input.h")
      check nimCheck(code, "input")
    else:
      skip()


suite "Bug fixes - output validation":
  test "Bug 1: typedef void generates opaque object, not = void":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let code = generateCode(header, cfg, "sample_c_bugfixes.h")
    # Should contain incompleteStruct and = object, not = void
    check "incompleteStruct" in code
    check "= object" in code
    check "= void" notin code
    check nimCheck(code, "bug1_typedef_void")

  test "Bug 2: union importc uses 'union' not 'struct' (C mode)":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    let incl = "sample_c_bugfixes.h"
    for s in header.structs:
      if s.isUnion:
        let code = gen.generateStruct(s, incl)
        check "importc: \"union " in code
        check "importc: \"struct " notin code

  test "Bug 3: camelCase=false preserves first character":
    var cfg = defaultConfig()
    cfg.camelCase = false
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    var visited: HashSet[string]
    for m in header.methods:
      if m.name == "MYLIB_doSomething":
        let code = gen.generateMethod(m, visited, @[])
        # First char should be preserved when camelCase is false
        check "proc MYLIB_doSomething" in code
        check "proc mYLIB_doSomething" notin code

  test "Bug 3: camelCase=true lowercases first character":
    var cfg = defaultConfig()
    cfg.camelCase = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    var visited: HashSet[string]
    for m in header.methods:
      if m.name == "myFunc":
        let code = gen.generateMethod(m, visited, @[])
        check "proc myFunc" in code

  test "Bug 4: anonymous enum names are skipped (not invalid identifiers)":
    let cfg = defaultConfig()
    let gen = initNimCodeGenerator(cfg)
    # Simulate an anonymous enum that wasn't resolved
    let badEnum = initEnumDecl(
      "(unnamed at test.h:10:1)", "(unnamed at test.h:10:1)", "unsigned int",
      @[initEnumItem("VAL_A", 1), initEnumItem("VAL_B", 2)])
    let code = gen.generateEnum(badEnum)
    # Should produce empty output for unresolvable anonymous enums
    check code == ""

  test "Bug 4/Feature A: anonymous enum inside typedef gets typedef name":
    var cfg = defaultConfig()
    cfg.cMode = true
    let gen = initNimCodeGenerator(cfg)
    # Simulate a resolved anonymous enum (name inherited from typedef)
    let resolvedEnum = initEnumDecl(
      "RGFW_key", "RGFW_key", "unsigned char",
      @[initEnumItem("RGFW_keyA", 97), initEnumItem("RGFW_keyB", 98)])
    let code = gen.generateEnum(resolvedEnum)
    check "RGFW_key" in code
    check "(unnamed" notin code

  test "Feature C: anonymous enum fullyQualified skips importc":
    let cfg = defaultConfig()
    let gen = initNimCodeGenerator(cfg)
    # Enum with valid name but anonymous fullyQualified
    let anonEnum = initEnumDecl(
      "MyKeys", "(unnamed at test.h:5:1)", "unsigned int",
      @[initEnumItem("KEY_A", 1), initEnumItem("KEY_B", 2)])
    let code = gen.generateEnum(anonEnum)
    check code.len > 0
    check "MyKeys" in code
    # importc/importcpp should be omitted for anonymous enums
    check "importc" notin code
    check "importcpp" notin code

  test "Bug 5: ignored type fields generate padding":
    var cfg = defaultConfig()
    cfg.ignoreTypes = @["InternalData"]
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    let incl = "sample_bugfixes.h"
    for s in header.structs:
      if s.name == "MyStruct":
        let code = gen.generateStruct(s, incl)
        # Should have padding instead of InternalData field
        check "padding" in code
        check "array[" in code
        check "byte]" in code
        # Should still have non-ignored fields
        check "id" in code
        check "value" in code

  test "Bug 5: field sizeBytes is captured by parser":
    let cfg = defaultConfig()
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_bugfixes.h")
    for s in header.structs:
      if s.name == "MyStruct":
        for field in s.fields:
          if field.name == "internal":
            check field.sizeBytes > 0  # InternalData has known size


  test "Bug 12: typedef'd struct has no 'struct' prefix in importc (C mode)":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    let incl = "sample_c_bugfixes.h"
    for t in header.typedefs:
      if t.name == "CSize" and t.typedefKind.isSome and t.typedefKind.get == "struct":
        let code = gen.generateTypedef(t, incl)
        check "importc: \"CSize\"" in code
        check "importc: \"struct " notin code

  test "Bug 12: typedef'd enum has no 'enum' prefix in importc (C mode)":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    let incl = "sample_c_bugfixes.h"
    for t in header.typedefs:
      if t.name == "CMode" and t.typedefKind.isSome and t.typedefKind.get == "enum":
        let code = gen.generateTypedef(t, incl)
        check "importc: \"CMode\"" in code
        check "importc: \"enum " notin code

  test "Bug 12: non-typedef'd struct keeps 'struct' prefix in importc (C mode)":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    let incl = "sample_c_bugfixes.h"
    for s in header.structs:
      if s.name == "IgnoredInner":
        let code = gen.generateStruct(s, incl)
        check "importc: \"struct IgnoredInner\"" in code

  test "Bug 13: opaque handle typedef becomes pointer":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    let incl = "sample_c_bugfixes.h"
    for t in header.typedefs:
      if t.name == "CHandle":
        let code = gen.generateTypedef(t, incl)
        check "= pointer" in code
        check "_CHandle_t" notin code

  test "Bug 7: ptr IgnoredType in params becomes pointer":
    var cfg = defaultConfig()
    cfg.cMode = true
    cfg.ignoreTypes = @["PlatformData"]
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let gen = initNimCodeGenerator(cfg)
    var visited: HashSet[string]
    for m in header.methods:
      if m.name == "usesPlatformPtr":
        let code = gen.generateMethod(m, visited, @[])
        check "pointer" in code
        check "PlatformData" notin code

  test "Bug 15: unsigned char maps to uint8 not cuchar":
    var cfg = defaultConfig()
    cfg.cMode = true
    let p = initCppHeaderParser(cfg)
    let header = p.parseFile(FixturesDir / "sample_c_bugfixes.h")
    let code = generateCode(header, cfg, "sample_c_bugfixes.h")
    check "cuchar" notin code
    # uint8 should appear for the color fields
    check "uint8" in code


when isMainModule:
  echo "Running codegen tests..."
  echo "Fixtures dir: ", FixturesDir
