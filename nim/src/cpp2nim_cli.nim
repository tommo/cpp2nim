## cpp2nim - C++ to Nim binding generator
##
## Command-line interface for generating Nim bindings from C++ headers.

import std/[os, strutils, parseopt, tables, sets, json, times, terminal, options]
import cpp2nim/[models, config, analyzer, generator, parser, postprocess, cache]


const
  Version = "0.1.0"

  HelperTypes* = """  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*
  ConstPtr*[T] = ptr T  ## const T* return type
"""

  Usage = """
cpp2nim - C++ to Nim binding generator

Usage:
  cpp2nim [config.json] [options]           Run with config file (recommended)
  cpp2nim <command> [options] [inputs...]   Run specific command

Commands:
  all         Run complete pipeline (default if config.json provided)
  init        Create example cpp2nim.json config file
  parse       Parse C++ headers to JSON (advanced)
  analyze     Analyze dependencies (advanced)
  generate    Generate from parsed JSON (advanced)
  help        Show this help message

Options:
  -c, --config=FILE     Load configuration from JSON file
  -o, --output=DIR      Output directory (default: current dir)
  -I, --include=PATH    Add include search path
  -D, --define=MACRO    Add preprocessor define
  -v, --verbose         Enable verbose output
  -q, --quiet           Suppress non-error output
  --c-mode              Parse as C instead of C++
  --no-camel            Disable camelCase conversion
  --namespace=NS        Root namespace to strip
  -f, --force           Force regeneration

Quick Start:
  1. Create config:    cpp2nim init
  2. Edit cpp2nim.json with your headers and options
  3. Generate:         cpp2nim cpp2nim.json

Examples:
  cpp2nim cpp2nim.json                  # Use config file (recommended)
  cpp2nim cpp2nim.json --force          # Force regenerate
  cpp2nim mylib/*.h -o src/ --c-mode    # Direct CLI usage
"""

  ProjectStructureHelp = """
Recommended Project Structure:
  myproject/
  ├── cpp2nim.json          # Config file (run: cpp2nim init)
  ├── myproject.nimble      # Nim package file
  ├── src/
  │   ├── myproject.nim     # Main module (re-exports bindings)
  │   ├── shared_types.nim  # [generated] Types used across files
  │   ├── header1.nim       # [generated] Bindings for header1.h
  │   └── header2.nim       # [generated] Bindings for header2.h
  └── vendor/               # C/C++ library headers/sources

Example myproject.nim (main module):
  import ./shared_types
  export shared_types
  import ./header1, ./header2
  export header1, header2

Example cpp2nim.json:
  {
    "headers": ["vendor/mylib/include/*.h"],
    "output_dir": "src",
    "search_paths": ["vendor/mylib/include"],
    "c_mode": true
  }
"""

  ExampleConfig = """{
  "headers": ["vendor/include/*.h"],
  "output_dir": "src",
  "search_paths": ["vendor/include"],
  "c_mode": false,
  "camel_case": true,
  "defines": [],
  "ignore_files": [],
  "ignore_types": [],
  "type_renames": {},
  "post_fixes": {}
}
"""

type
  Command = enum
    cmdNone, cmdParse, cmdAnalyze, cmdGenerate, cmdAll, cmdHelp, cmdVersion, cmdInit

  CliOptions = object
    command: Command
    inputs: seq[string]
    configFile: string
    outputDir: string
    includePaths: seq[string]
    defines: seq[string]
    verbose: bool
    quiet: bool
    cMode: bool
    camelCase: bool
    rootNamespace: string
    renames: Table[string, string]
    ignoreTypes: seq[string]
    ignoreFiles: seq[string]
    parallel: bool
    numWorkers: int
    force: bool


# Logging utilities

proc log(opts: CliOptions, msg: string) =
  if not opts.quiet:
    echo msg

proc logVerbose(opts: CliOptions, msg: string) =
  if opts.verbose and not opts.quiet:
    echo "  ", msg

proc logError(msg: string) =
  styledWriteLine(stderr, fgRed, "Error: ", resetStyle, msg)

proc logWarning(msg: string) =
  styledWriteLine(stderr, fgYellow, "Warning: ", resetStyle, msg)

proc logSuccess(msg: string) =
  styledWriteLine(stdout, fgGreen, "✓ ", resetStyle, msg)


# Helper utilities

proc getHeaderIncludePath(filename: string, searchPaths: seq[string]): string =
  ## Get the proper include path for a header file.
  ## Strips search path prefix if present, otherwise returns just the basename.
  for searchPath in searchPaths:
    let prefix = if searchPath.endsWith("/"): searchPath else: searchPath & "/"
    if filename.startsWith(prefix):
      return filename[prefix.len..^1]
  return extractFilename(filename)

proc expandGlobs(patterns: seq[string]): seq[string] =
  ## Expand glob patterns to actual file paths.
  for pattern in patterns:
    if "*" in pattern or "?" in pattern:
      for file in walkPattern(pattern):
        if file notin result:
          result.add(file)
    elif fileExists(pattern):
      if pattern notin result:
        result.add(pattern)
    else:
      logWarning("File not found: " & pattern)

proc applyPatchFile(code: string, outputPath: string, cfg: Config, configDir: string): string =
  ## Apply patch file if configured for this output file.
  let basename = extractFilename(outputPath)
  if basename in cfg.patchFiles:
    let patchPath = if cfg.patchFiles[basename].isAbsolute:
      cfg.patchFiles[basename]
    else:
      configDir / cfg.patchFiles[basename]
    if fileExists(patchPath):
      return readFile(patchPath) & "\n" & code
    else:
      stderr.writeLine "Warning: patch file not found: " & patchPath
  return code

proc isSharedType(fullyQualified: string, sharedTypes: HashSet[string]): bool =
  ## Check if a type should be in shared_types.nim
  fullyQualified in sharedTypes


# Argument parsing

proc parseArgs(): CliOptions =
  result = CliOptions(command: cmdNone, camelCase: true, numWorkers: 0)
  var p = initOptParser()
  var cmdFound = false

  proc getVal(optName: string): string =
    if p.val.len > 0:
      return p.val
    p.next()
    if p.kind == cmdArgument:
      return p.key
    else:
      logError("Option " & optName & " requires a value")
      quit(1)

  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key.toLowerAscii()
      of "c", "config": result.configFile = getVal("-c/--config")
      of "o", "output": result.outputDir = getVal("-o/--output")
      of "i", "include": result.includePaths.add(getVal("-I/--include"))
      of "d", "define": result.defines.add(getVal("-D/--define"))
      of "v", "verbose": result.verbose = true
      of "q", "quiet": result.quiet = true
      of "c-mode": result.cMode = true
      of "no-camel": result.camelCase = false
      of "namespace": result.rootNamespace = getVal("--namespace")
      of "rename":
        let parts = getVal("--rename").split(":")
        if parts.len == 2:
          result.renames[parts[0]] = parts[1]
        else:
          logWarning("Invalid rename format, expected OLD:NEW")
      of "ignore-type": result.ignoreTypes.add(getVal("--ignore-type"))
      of "ignore-file": result.ignoreFiles.add(getVal("--ignore-file"))
      of "parallel": result.parallel = true
      of "workers": result.numWorkers = parseInt(getVal("--workers"))
      of "f", "force": result.force = true
      of "h", "help": result.command = cmdHelp; return
      of "version": result.command = cmdVersion; return
      else: logWarning("Unknown option: " & p.key)

    of cmdArgument:
      if not cmdFound:
        cmdFound = true
        case p.key.toLowerAscii()
        of "parse": result.command = cmdParse
        of "analyze": result.command = cmdAnalyze
        of "generate": result.command = cmdGenerate
        of "all": result.command = cmdAll
        of "init": result.command = cmdInit
        of "help": result.command = cmdHelp
        of "version": result.command = cmdVersion
        else:
          if p.key.endsWith(".json") and result.configFile.len == 0:
            result.configFile = p.key
            result.command = cmdAll
          else:
            result.inputs.add(p.key)
            result.command = cmdAll
      else:
        result.inputs.add(p.key)


proc buildConfig(opts: CliOptions): Config =
  ## Build Config from CLI options, optionally loading from file first.
  if opts.configFile.len > 0:
    if not fileExists(opts.configFile):
      logError("Config file not found: " & opts.configFile)
      quit(1)
    result = loadConfigFromJson(opts.configFile)
    opts.log("Loaded config from " & opts.configFile)
  else:
    result = defaultConfig()

  if opts.includePaths.len > 0:
    result.searchPaths = result.searchPaths & opts.includePaths
  for d in opts.defines:
    result.defines.add(d)
  if opts.outputDir.len > 0:
    result.outputDir = opts.outputDir
  if opts.cMode:
    result.cMode = true
  result.camelCase = opts.camelCase
  if opts.rootNamespace.len > 0:
    result.rootNamespace = some(opts.rootNamespace)
  for k, v in opts.renames:
    result.typeRenames[k] = v
  result.ignoreTypes = result.ignoreTypes & opts.ignoreTypes
  result.ignoreFiles = result.ignoreFiles & opts.ignoreFiles
  if opts.parallel:
    result.parallel = true
  if opts.numWorkers > 0:
    result.numWorkers = some(opts.numWorkers)


# Pipeline stages

proc parseHeaders(files: seq[string], cfg: Config, opts: CliOptions): ParseResult =
  ## Parse C++ headers into ParseResult.
  let p = initCppHeaderParser(cfg)
  result = initParseResult()
  for file in files:
    opts.logVerbose("Parsing: " & file)
    let header = p.parseFile(file)
    result.headers[file] = header
    result.allDependencies[file] = header.dependencies
    result.allProvides[file] = header.provides
    result.allMissing[file] = header.missing

proc buildRenames(parseResult: ParseResult, cfg: Config,
                  analysisRenames: Table[string, string]): Table[string, string] =
  ## Build complete rename table from analysis and config.
  result = cfg.typeRenames
  for k, v in analysisRenames:
    result[k] = v

  # Add typedef aliases for template instantiations
  for filename, header in parseResult.headers:
    for typedef in header.typedefs:
      if "<" in typedef.underlying:
        let nimName = typedef.name.split("::")[^1]
        result[typedef.fullyQualified] = nimName
        let underlyingNim = getNimType(typedef.underlying, result)
        if underlyingNim != nimName:
          result[underlyingNim] = nimName

  # Add suffix-stripped type renames
  for suffix in cfg.stripTypeSuffixes:
    for filename, header in parseResult.headers:
      for typedef in header.typedefs:
        if typedef.structData.isSome:
          let structName = typedef.structData.get.name
          if structName.endsWith(suffix) and structName.len > suffix.len:
            let strippedName = structName[0 ..< structName.len - suffix.len]
            result[structName] = strippedName
            result[typedef.structData.get.fullyQualified] = strippedName
      for s in header.structs:
        if s.name.endsWith(suffix) and s.name.len > suffix.len:
          let strippedName = s.name[0 ..< s.name.len - suffix.len]
          result[s.name] = strippedName
          result[s.fullyQualified] = strippedName

proc collectSharedTypeEntries(parseResult: ParseResult, analysis: AnalysisResult,
                               gen: NimCodeGenerator, cfg: Config,
                               opts: CliOptions): seq[SharedTypeEntry] =
  ## Collect shared types into entries for topological sorting.
  for filename, header in parseResult.headers:
    let incl = getHeaderIncludePath(filename, cfg.searchPaths)

    for e in header.enums:
      if opts.verbose:
        echo "  Enum: ", e.fullyQualified, " shared=", isSharedType(e.fullyQualified, analysis.sharedTypes)
      if isSharedType(e.fullyQualified, analysis.sharedTypes):
        result.add(initSharedTypeEntry(
          name = e.fullyQualified,
          deps = @[],
          kind = "enum",
          code = gen.generateEnum(e, incl),
          isGeneric = false,
          isBaseClass = false
        ))

    for s in header.structs:
      if isSharedType(s.fullyQualified, analysis.sharedTypes):
        result.add(initSharedTypeEntry(
          name = s.fullyQualified,
          deps = s.underlyingDeps & s.baseTypes,
          kind = "struct",
          code = gen.generateStruct(s, incl),
          isGeneric = s.templateParams.len > 0,
          isBaseClass = s.fullyQualified in analysis.baseClasses or
                       s.name in analysis.baseClasses
        ))

    for c in header.classes:
      if isSharedType(c.fullyQualified, analysis.sharedTypes):
        result.add(initSharedTypeEntry(
          name = c.fullyQualified,
          deps = c.baseTypes,
          kind = "class",
          code = gen.generateClass(c, incl),
          isGeneric = c.templateParams.len > 0,
          isBaseClass = c.fullyQualified in analysis.baseClasses or
                       c.name in analysis.baseClasses
        ))

    for t in header.typedefs:
      if t.enumData.isSome:
        let enumData = t.enumData.get
        if isSharedType(enumData.fullyQualified, analysis.sharedTypes):
          result.add(initSharedTypeEntry(
            name = enumData.fullyQualified,
            deps = @[],
            kind = "enum",
            code = gen.generateEnum(enumData, incl),
            isGeneric = false,
            isBaseClass = false
          ))
      elif isSharedType(t.fullyQualified, analysis.sharedTypes):
        let td = gen.generateTypedef(t, incl)
        if td.len > 0:
          result.add(initSharedTypeEntry(
            name = t.fullyQualified,
            deps = t.underlyingDeps,
            kind = "typedef",
            code = td,
            isGeneric = false,
            isBaseClass = false
          ))

proc generateSharedTypesFile(entries: seq[SharedTypeEntry], outputDir: string,
                              cfg: Config, configDir: string, opts: CliOptions): int =
  ## Generate shared_types.nim file. Returns 1 if file was generated.
  if entries.len == 0:
    return 0

  let sharedPath = outputDir / "shared_types.nim"
  var code = "# Auto-generated shared types for cpp2nim\n"
  code.add("# Generated: " & $now() & "\n\n")
  code.add("type\n")
  code.add(HelperTypes)
  code.add("\n")

  let sorted = topoSortTypes(entries)
  if sorted.len > 0:
    code.add("type\n")
    for entry in sorted:
      code.add(entry.code)

  let patched = applyPatchFile(code, sharedPath, cfg, configDir)
  let processed = cfg.postFixes.processFile(sharedPath, patched)
  writeFile(sharedPath, processed)
  opts.logVerbose("Generated: " & sharedPath)
  return 1

proc generatePerFileBindings(parseResult: ParseResult, analysis: AnalysisResult,
                              gen: NimCodeGenerator, cfg: Config,
                              configDir: string, outputDir: string,
                              opts: CliOptions): int =
  ## Generate individual binding files. Returns count of files generated.
  var filesGenerated = 0

  for filename, header in parseResult.headers:
    let basename = extractFilename(filename).changeFileExt(".nim")
    let outputPath = outputDir / basename

    var code = "# Auto-generated Nim bindings for " & filename & "\n"
    code.add("# Generated: " & $now() & "\n\n")

    # Add imports
    var imports: seq[string]
    if analysis.sharedTypes.len > 0:
      imports.add("shared_types")
    if filename in analysis.importGraph:
      for imp in analysis.importGraph[filename]:
        if imp notin imports and imp != basename.changeFileExt(""):
          imports.add(imp)
    if imports.len > 0:
      code.add("import " & imports.join(", ") & "\n\n")

    # Helper types (only if no shared_types)
    if analysis.sharedTypes.len == 0:
      code.add("type\n")
      code.add(HelperTypes)
      code.add("\n")

    let incl = getHeaderIncludePath(filename, cfg.searchPaths)

    # Collect types (excluding shared types)
    var typeCode = ""
    for e in header.enums:
      if not isSharedType(e.fullyQualified, analysis.sharedTypes):
        typeCode.add(gen.generateEnum(e, incl))

    for s in header.structs:
      if not isSharedType(s.fullyQualified, analysis.sharedTypes):
        typeCode.add(gen.generateStruct(s, incl))

    for c in header.classes:
      if not isSharedType(c.fullyQualified, analysis.sharedTypes):
        typeCode.add(gen.generateClass(c, incl))

    for t in header.typedefs:
      let isEmbeddedEnumShared = t.enumData.isSome and
        isSharedType(t.enumData.get.fullyQualified, analysis.sharedTypes)
      if not isSharedType(t.fullyQualified, analysis.sharedTypes) and not isEmbeddedEnumShared:
        typeCode.add(gen.generateTypedef(t, incl))

    if typeCode.len > 0:
      code.add("type\n")
      code.add(typeCode)
      code.add("\n")

    # Collect procs
    var visited: HashSet[string]
    for m in header.methods:
      let methodCode = gen.generateMethod(m, visited, cfg.varargsFunctions)
      if methodCode.len > 0:
        code.add(methodCode)

    var dupTracker: Table[string, bool]
    for c in header.constructors:
      code.add(gen.generateConstructor(c, dupTracker))

    # Collect constants
    var constCode = ""
    for c in header.constants:
      constCode.add(gen.generateConst(c))
    if constCode.len > 0:
      code.add("const\n")
      code.add(constCode)

    let patched = applyPatchFile(code, outputPath, cfg, configDir)
    let processed = cfg.postFixes.processFile(outputPath, patched)
    writeFile(outputPath, processed)
    opts.logVerbose("Generated: " & outputPath)
    inc filesGenerated

  return filesGenerated

proc showPostGenerationTips(parseResult: ParseResult, outputDir: string,
                            opts: CliOptions, filesGenerated: int) =
  ## Show helpful tips for first-time users.
  if opts.quiet or filesGenerated == 0:
    return

  let sharedExists = fileExists(outputDir / "shared_types.nim")
  echo ""
  echo "Tip: Create a main module to re-export bindings:"
  echo "  # " & outputDir & "/mylib.nim"
  if sharedExists:
    echo "  import ./shared_types"
    echo "  export shared_types"
  for filename, _ in parseResult.headers:
    let modName = extractFilename(filename).changeFileExt("")
    echo "  import ./" & modName
    echo "  export " & modName
    break
  if parseResult.headers.len > 1:
    echo "  # ... (import/export other modules)"


# Command implementations

proc cmdParseHeaders(opts: CliOptions, cfg: Config): int =
  ## Parse C++ headers to JSON.
  let files = expandGlobs(opts.inputs)
  if files.len == 0:
    logError("No input files specified")
    return 1

  opts.log("Parsing " & $files.len & " header(s)...")
  let parseResult = parseHeaders(files, cfg, opts)

  let outputPath = if opts.outputDir.len > 0:
    if opts.outputDir.endsWith(".json"): opts.outputDir
    else: opts.outputDir / "parsed.json"
  else:
    "parsed.json"

  let parentPath = parentDir(outputPath)
  if parentPath.len > 0:
    createDir(parentPath)
  writeFile(outputPath, $(%parseResult))

  logSuccess("Wrote parse results to " & outputPath)
  return 0


proc cmdAnalyzeDeps(opts: CliOptions, cfg: Config): int =
  ## Analyze dependencies between parsed headers.
  if opts.inputs.len == 0:
    logError("No input JSON file specified")
    return 1

  let inputPath = opts.inputs[0]
  if not fileExists(inputPath):
    logError("Input file not found: " & inputPath)
    return 1

  opts.log("Analyzing dependencies...")

  let parseResult = toParseResult(parseJson(readFile(inputPath)))
  let analyzer = initDependencyAnalyzer(cfg)
  let analysis = analyzer.analyze(parseResult)

  opts.logVerbose("Found " & $analysis.sharedTypes.len & " shared types")
  opts.logVerbose("Generated " & $analysis.typeRenames.len & " renames")

  let outputPath = if opts.outputDir.len > 0:
    opts.outputDir / "analysis.json"
  else:
    "analysis.json"

  var outputJson = newJObject()
  var sharedArr = newJArray()
  for t in analysis.sharedTypes:
    sharedArr.add(%t)
  outputJson["shared_types"] = sharedArr

  var renamesObj = newJObject()
  for k, v in analysis.typeRenames:
    renamesObj[k] = %v
  outputJson["type_renames"] = renamesObj

  var importsObj = newJObject()
  for k, v in analysis.importGraph:
    var arr = newJArray()
    for imp in v:
      arr.add(%imp)
    importsObj[k] = arr
  outputJson["imports"] = importsObj

  createDir(parentDir(outputPath))
  writeFile(outputPath, $outputJson)

  logSuccess("Wrote analysis to " & outputPath)
  return 0


proc cmdGenerateBindings(opts: CliOptions, cfg: Config): int =
  ## Generate Nim bindings from parsed JSON.
  if opts.inputs.len < 1:
    logError("No input JSON file specified")
    return 1

  let parsedPath = opts.inputs[0]
  if not fileExists(parsedPath):
    logError("Parsed JSON not found: " & parsedPath)
    return 1

  opts.log("Generating Nim bindings...")

  let parseResult = toParseResult(parseJson(readFile(parsedPath)))

  var renames = cfg.typeRenames
  if opts.inputs.len >= 2:
    let analysisPath = opts.inputs[1]
    if fileExists(analysisPath):
      let analysisNode = parseJson(readFile(analysisPath))
      if analysisNode.hasKey("type_renames"):
        for k, v in analysisNode["type_renames"]:
          renames[k] = v.getStr

  let gen = initNimCodeGenerator(cfg, renames)
  let outputDir = if cfg.outputDir != ".": cfg.outputDir else: "."
  createDir(outputDir)

  var filesGenerated = 0
  for filename, header in parseResult.headers:
    let basename = extractFilename(filename).changeFileExt(".nim")
    let outputPath = outputDir / basename

    var code = "# Auto-generated Nim bindings for " & filename & "\n"
    code.add("# Generated: " & $now() & "\n\n")

    let incl = getHeaderIncludePath(filename, cfg.searchPaths)

    for e in header.enums:
      code.add(gen.generateEnum(e, incl))
    for s in header.structs:
      code.add(gen.generateStruct(s, incl))
    for c in header.classes:
      code.add(gen.generateClass(c, incl))
    for t in header.typedefs:
      code.add(gen.generateTypedef(t, incl))

    var visited: HashSet[string]
    for m in header.methods:
      let methodCode = gen.generateMethod(m, visited, cfg.varargsFunctions)
      if methodCode.len > 0:
        code.add(methodCode)

    var dupTracker: Table[string, bool]
    for c in header.constructors:
      code.add(gen.generateConstructor(c, dupTracker))

    for c in header.constants:
      code.add(gen.generateConst(c))

    writeFile(outputPath, code)
    opts.logVerbose("Generated: " & outputPath)
    inc filesGenerated

  logSuccess("Generated " & $filesGenerated & " binding file(s) in " & outputDir)
  return 0


proc cmdRunAll(opts: CliOptions, cfg: Config): int =
  ## Run complete pipeline: parse + analyze + generate.
  let inputs = if opts.inputs.len > 0: opts.inputs else: cfg.headers
  let files = expandGlobs(inputs)
  if files.len == 0:
    logError("No input files specified (use --config with 'headers' or pass files on command line)")
    return 1

  let outputDir = if cfg.outputDir != ".": cfg.outputDir else: "."
  let cacheFile = outputDir / ".cpp2nim_cache.json"

  # Compute hashes for cache invalidation
  let parseHash = hashParseConfig(cfg, files)
  let genHash = hashGenConfig(cfg)
  var cacheEntry = loadCache(cacheFile)

  # Check if everything is up to date
  if not opts.force and cacheEntry.parseHash == parseHash and cacheEntry.genHash == genHash:
    if dirExists(outputDir):
      var hasOutputs = false
      for file in walkDir(outputDir):
        if file.kind == pcFile and file.path.endsWith(".nim"):
          hasOutputs = true
          break
      if hasOutputs:
        logSuccess("Outputs are up to date (use --force to regenerate)")
        return 0

  let startTime = cpuTime()
  opts.log("Running cpp2nim pipeline on " & $files.len & " file(s)...")

  # Step 1: Parse (skip if parse hash matches and cache exists)
  var parseResult: ParseResult
  if cacheEntry.parseHash == parseHash and cacheEntry.parsedData != nil and not opts.force:
    opts.log("\n[1/3] Using cached parse results...")
    parseResult = toParseResult(cacheEntry.parsedData)
  else:
    opts.log("\n[1/3] Parsing headers...")
    parseResult = parseHeaders(files, cfg, opts)
    cacheEntry.parseHash = parseHash
    cacheEntry.parsedData = %parseResult

  # Step 2: Analyze
  opts.log("\n[2/3] Analyzing dependencies...")
  let analyzer = initDependencyAnalyzer(cfg)
  let analysis = analyzer.analyze(parseResult)
  opts.logVerbose("Shared types: " & $analysis.sharedTypes.len)
  opts.logVerbose("Type renames: " & $analysis.typeRenames.len)

  let renames = buildRenames(parseResult, cfg, analysis.typeRenames)

  # Step 3: Generate
  opts.log("\n[3/3] Generating bindings...")
  opts.logVerbose("Base classes: " & $analysis.baseClasses.len)
  let gen = initNimCodeGenerator(cfg, renames, analysis.baseClasses)
  let configDir = if opts.configFile.len > 0: parentDir(opts.configFile) else: getCurrentDir()
  createDir(outputDir)

  var filesGenerated = 0

  # Generate shared_types.nim
  let entries = collectSharedTypeEntries(parseResult, analysis, gen, cfg, opts)
  filesGenerated += generateSharedTypesFile(entries, outputDir, cfg, configDir, opts)

  # Generate per-file bindings
  filesGenerated += generatePerFileBindings(parseResult, analysis, gen, cfg, configDir, outputDir, opts)

  # Save cache
  cacheEntry.genHash = genHash
  saveCache(cacheFile, cacheEntry)

  let elapsed = cpuTime() - startTime
  opts.log("")
  logSuccess("Pipeline complete in " & formatFloat(elapsed, ffDecimal, 2) & "s")
  logSuccess("Generated " & $filesGenerated & " binding file(s) in " & outputDir)

  showPostGenerationTips(parseResult, outputDir, opts, filesGenerated)
  return 0


proc main(): int =
  let opts = parseArgs()

  case opts.command
  of cmdHelp:
    echo Usage
    echo ProjectStructureHelp
    return 0

  of cmdVersion:
    echo "cpp2nim version ", Version
    return 0

  of cmdInit:
    let configPath = "cpp2nim.json"
    if fileExists(configPath):
      logError(configPath & " already exists. Remove it first or edit manually.")
      return 1
    writeFile(configPath, ExampleConfig)
    logSuccess("Created " & configPath)
    echo ""
    echo "Next steps:"
    echo "  1. Edit cpp2nim.json with your headers and paths"
    echo "  2. Run: cpp2nim cpp2nim.json"
    echo ""
    echo ProjectStructureHelp
    return 0

  of cmdNone, cmdParse, cmdAnalyze, cmdGenerate, cmdAll:
    discard

  let cfg = buildConfig(opts)

  if opts.command == cmdNone and opts.inputs.len == 0 and cfg.headers.len == 0:
    echo Usage
    return 0

  if not opts.quiet:
    let warnings = validateOrWarn(cfg)
    for w in warnings:
      logWarning(w)

  case opts.command
  of cmdParse:
    return cmdParseHeaders(opts, cfg)
  of cmdAnalyze:
    return cmdAnalyzeDeps(opts, cfg)
  of cmdGenerate:
    return cmdGenerateBindings(opts, cfg)
  of cmdAll, cmdNone:
    return cmdRunAll(opts, cfg)
  else:
    return 0


when isMainModule:
  quit(main())
