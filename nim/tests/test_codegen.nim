## Code generation tests for cpp2nim.
##
## Tests that generated Nim code compiles with `nim check`.
## Requires libclang. Run with:
##   nim c -d:useLibclang -r tests/test_codegen.nim

import std/[unittest, os, sets, tables, osproc, times, streams]
import ../src/cpp2nim/[parser, models, config, generator]

const FixturesDir = currentSourcePath().parentDir / "fixtures"

proc generateCode(header: ParsedHeader, cfg: Config, filename: string): string =
  ## Generate Nim code from parsed header.
  let gen = initNimCodeGenerator(cfg)
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


when isMainModule:
  echo "Running codegen tests..."
  echo "Fixtures dir: ", FixturesDir
