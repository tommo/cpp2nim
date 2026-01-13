## cpp2nim - C++ to Nim binding generator
##
## Command-line interface for generating Nim bindings from C++ headers.

import std/[os, strutils, parseopt, tables, sets, json, times, terminal, options, algorithm, sequtils]
import cpp2nim/[models, config, analyzer, generator, parser, postprocess]


proc applyPatchFile(code: string, outputPath: string, cfg: Config, configDir: string): string =
  ## Apply patch file if configured for this output file.
  ## Patch file content is prepended to the generated code.
  let basename = extractFilename(outputPath)
  if basename in cfg.patchFiles:
    let patchPath = if cfg.patchFiles[basename].isAbsolute:
      cfg.patchFiles[basename]
    else:
      configDir / cfg.patchFiles[basename]
    if fileExists(patchPath):
      let patchContent = readFile(patchPath)
      return patchContent & "\n" & code
    else:
      stderr.writeLine "Warning: patch file not found: " & patchPath
  return code


type
  SharedTypeEntry = object
    ## Entry for a shared type with its dependencies for topological sorting.
    name: string           ## Fully qualified name
    deps: seq[string]      ## Dependencies (types this depends on)
    kind: string           ## "enum", "struct", "class", "typedef"
    code: string           ## Generated Nim code
    isGeneric: bool        ## Has template parameters
    isBaseClass: bool      ## Is used as a base class

proc topoSortTypes(entries: seq[SharedTypeEntry]): seq[SharedTypeEntry] =
  ## Topologically sort types so dependencies come first.
  ## Generic types come before their instantiations.
  ## Base classes come before derived classes.
  var nameToEntry: Table[string, SharedTypeEntry]
  var inDegree: Table[string, int]
  var graph: Table[string, seq[string]]  # name -> types that depend on it

  # Build lookup and initialize
  for entry in entries:
    nameToEntry[entry.name] = entry
    inDegree[entry.name] = 0
    graph[entry.name] = @[]

  # Build dependency graph
  for entry in entries:
    for dep in entry.deps:
      # Check if dep matches any entry (handle namespace stripping)
      for name in nameToEntry.keys:
        if name == dep or name.endsWith("::" & dep) or dep.endsWith("::" & name.split("::")[^1]):
          if name != entry.name:
            graph[name].add(entry.name)
            inDegree[entry.name] = inDegree.getOrDefault(entry.name) + 1

  # Kahn's algorithm with priority:
  # 1. Generic types (isGeneric) first
  # 2. Base classes second
  # 3. Then by dependency order
  var ready: seq[string]
  for name, degree in inDegree:
    if degree == 0:
      ready.add(name)

  # Sort ready queue: generics first, then base classes
  ready.sort do (a, b: string) -> int:
    let ea = nameToEntry[a]
    let eb = nameToEntry[b]
    if ea.isGeneric != eb.isGeneric:
      return if ea.isGeneric: -1 else: 1
    if ea.isBaseClass != eb.isBaseClass:
      return if ea.isBaseClass: -1 else: 1
    return cmp(a, b)

  var sortedResult: seq[SharedTypeEntry]
  while ready.len > 0:
    let name = ready[0]
    ready.delete(0)
    sortedResult.add(nameToEntry[name])

    for dependent in graph.getOrDefault(name):
      inDegree[dependent] = inDegree[dependent] - 1
      if inDegree[dependent] == 0:
        # Insert maintaining sort order
        var inserted = false
        for i, r in ready:
          let er = nameToEntry[r]
          let ed = nameToEntry[dependent]
          if (ed.isGeneric and not er.isGeneric) or
             (ed.isBaseClass and not er.isBaseClass and not er.isGeneric):
            ready.insert(dependent, i)
            inserted = true
            break
        if not inserted:
          ready.add(dependent)

  # Add any remaining (cycles) at the end
  for entry in entries:
    if entry.name notin sortedResult.mapIt(it.name):
      sortedResult.add(entry)

  return sortedResult

const
  Version = "0.1.0"
  Usage = """
cpp2nim - C++ to Nim binding generator

Usage:
  cpp2nim <command> [options] [inputs...]

Commands:
  parse       Parse C++ headers to JSON
  analyze     Analyze dependencies between headers
  generate    Generate Nim bindings from parsed JSON
  all         Run complete pipeline (parse + analyze + generate)
  help        Show this help message
  version     Show version

Options:
  -c, --config=FILE     Load configuration from JSON file
  -o, --output=DIR      Output directory (default: current dir)
  -I, --include=PATH    Add include search path (can be repeated)
  -D, --define=MACRO    Add preprocessor define (can be repeated)
  -v, --verbose         Enable verbose output
  -q, --quiet           Suppress non-error output
  --c-mode              Parse as C instead of C++
  --no-camel            Disable camelCase conversion
  --namespace=NS        Root namespace to strip
  --rename=OLD:NEW      Add type rename (can be repeated)
  --ignore-type=TYPE    Ignore type (can be repeated)
  --ignore-file=FILE    Ignore file pattern (can be repeated)
  --parallel            Enable parallel parsing
  --workers=N           Number of parallel workers
  -f, --force           Force regeneration even if outputs are up to date

Examples:
  cpp2nim parse -I/usr/include mylib/*.h -o parsed.json
  cpp2nim analyze parsed.json -o analysis.json
  cpp2nim generate parsed.json analysis.json -o bindings/
  cpp2nim all -I/usr/include -o bindings/ mylib/*.h
  cpp2nim all --config=cpp2nim.json mylib/*.h
"""

type
  Command = enum
    cmdNone, cmdParse, cmdAnalyze, cmdGenerate, cmdAll, cmdHelp, cmdVersion

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
    force: bool  ## Force regeneration even if outputs are up to date


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

proc getHeaderIncludePath(filename: string, searchPaths: seq[string]): string =
  ## Get the proper include path for a header file.
  ## Strips search path prefix if present, otherwise returns just the basename.
  ## Example: "include/RmlUi/Core/Element.h" with searchPath "include" -> "RmlUi/Core/Element.h"
  for searchPath in searchPaths:
    let prefix = if searchPath.endsWith("/"): searchPath else: searchPath & "/"
    if filename.startsWith(prefix):
      return filename[prefix.len..^1]
  # No search path matched - return just the filename
  return extractFilename(filename)

proc needsRegeneration(inputFiles: seq[string], configFile: string, outputDir: string): bool =
  ## Check if any input file or config is newer than the oldest output file.
  ## Returns true if regeneration is needed, false if outputs are up to date.
  if not dirExists(outputDir):
    return true

  # Find the oldest output .nim file
  var oldestOutput = high(Time)
  var hasOutputs = false
  for file in walkDir(outputDir):
    if file.kind == pcFile and file.path.endsWith(".nim"):
      hasOutputs = true
      let mtime = getLastModificationTime(file.path)
      if mtime < oldestOutput:
        oldestOutput = mtime

  if not hasOutputs:
    return true

  # Check if config file is newer than oldest output
  if configFile.len > 0 and fileExists(configFile):
    if getLastModificationTime(configFile) > oldestOutput:
      return true

  # Check if any input header is newer than oldest output
  for inputFile in inputFiles:
    if fileExists(inputFile):
      if getLastModificationTime(inputFile) > oldestOutput:
        return true

  return false


proc parseArgs(): CliOptions =
  result = CliOptions(
    command: cmdNone,
    camelCase: true,
    numWorkers: 0
  )

  var p = initOptParser()
  var cmdFound = false

  # Helper to get option value - handles both -c=value and -c value forms
  proc getVal(optName: string): string =
    if p.val.len > 0:
      return p.val
    # Check if next token is an argument (not another option)
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
      of "c", "config":
        result.configFile = getVal("-c/--config")
      of "o", "output":
        result.outputDir = getVal("-o/--output")
      of "i", "include":
        result.includePaths.add(getVal("-I/--include"))
      of "d", "define":
        result.defines.add(getVal("-D/--define"))
      of "v", "verbose":
        result.verbose = true
      of "q", "quiet":
        result.quiet = true
      of "c-mode":
        result.cMode = true
      of "no-camel":
        result.camelCase = false
      of "namespace":
        result.rootNamespace = getVal("--namespace")
      of "rename":
        let parts = getVal("--rename").split(":")
        if parts.len == 2:
          result.renames[parts[0]] = parts[1]
        else:
          logWarning("Invalid rename format, expected OLD:NEW")
      of "ignore-type":
        result.ignoreTypes.add(getVal("--ignore-type"))
      of "ignore-file":
        result.ignoreFiles.add(getVal("--ignore-file"))
      of "parallel":
        result.parallel = true
      of "workers":
        result.numWorkers = parseInt(getVal("--workers"))
      of "f", "force":
        result.force = true
      of "h", "help":
        result.command = cmdHelp
        return
      of "version":
        result.command = cmdVersion
        return
      else:
        logWarning("Unknown option: " & p.key)

    of cmdArgument:
      if not cmdFound:
        cmdFound = true
        case p.key.toLowerAscii()
        of "parse":
          result.command = cmdParse
        of "analyze":
          result.command = cmdAnalyze
        of "generate":
          result.command = cmdGenerate
        of "all":
          result.command = cmdAll
        of "help":
          result.command = cmdHelp
        of "version":
          result.command = cmdVersion
        else:
          result.inputs.add(p.key)
          result.command = cmdAll  # Default to 'all' if files given without command
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

  # Override with CLI options
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


proc cmdParseHeaders(opts: CliOptions, cfg: Config): int =
  ## Parse C++ headers to JSON.
  let files = expandGlobs(opts.inputs)
  if files.len == 0:
    logError("No input files specified")
    return 1

  opts.log("Parsing " & $files.len & " header(s)...")

  let p = initCppHeaderParser(cfg)
  var parseResult = initParseResult()

  for file in files:
    opts.logVerbose("Parsing: " & file)
    let header = p.parseFile(file)
    parseResult.headers[file] = header
    parseResult.allDependencies[file] = header.dependencies
    parseResult.allProvides[file] = header.provides
    parseResult.allMissing[file] = header.missing

  # Determine output path - use -o value directly if it ends with .json
  let outputPath = if opts.outputDir.len > 0:
    if opts.outputDir.endsWith(".json"):
      opts.outputDir
    else:
      opts.outputDir / "parsed.json"
  else:
    "parsed.json"

  let jsonContent = $(%parseResult)
  let parentPath = parentDir(outputPath)
  if parentPath.len > 0:
    createDir(parentPath)
  writeFile(outputPath, jsonContent)

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

  # Load parse result
  let content = readFile(inputPath)
  let node = parseJson(content)
  let parseResult = toParseResult(node)

  # Run analysis
  let analyzer = initDependencyAnalyzer(cfg)
  let analysis = analyzer.analyze(parseResult)

  opts.logVerbose("Found " & $analysis.sharedTypes.len & " shared types")
  opts.logVerbose("Generated " & $analysis.typeRenames.len & " renames")

  # Write output
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

  # Load parse result
  let content = readFile(parsedPath)
  let node = parseJson(content)
  let parseResult = toParseResult(node)

  # Load analysis if provided
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

    # Generate enums
    for e in header.enums:
      code.add(gen.generateEnum(e, incl))

    # Generate structs
    for s in header.structs:
      code.add(gen.generateStruct(s, incl))

    # Generate classes
    for c in header.classes:
      code.add(gen.generateClass(c, incl))

    # Generate typedefs
    for t in header.typedefs:
      code.add(gen.generateTypedef(t, incl))

    # Generate methods
    var visited: HashSet[string]
    for m in header.methods:
      let methodCode = gen.generateMethod(m, visited, cfg.varargsFunctions)
      if methodCode.len > 0:
        code.add(methodCode)

    # Generate constructors
    var dupTracker: Table[string, bool]
    for c in header.constructors:
      code.add(gen.generateConstructor(c, dupTracker))

    # Generate constants
    for c in header.constants:
      code.add(gen.generateConst(c))

    writeFile(outputPath, code)
    opts.logVerbose("Generated: " & outputPath)
    inc filesGenerated

  logSuccess("Generated " & $filesGenerated & " binding file(s) in " & outputDir)
  return 0


proc isSharedType(fullyQualified: string, sharedTypes: HashSet[string]): bool =
  ## Check if a type should be in shared_types.nim
  result = fullyQualified in sharedTypes

proc cmdRunAll(opts: CliOptions, cfg: Config): int =
  ## Run complete pipeline: parse + analyze + generate.
  # Use config headers if no CLI inputs provided
  let inputs = if opts.inputs.len > 0: opts.inputs else: cfg.headers
  let files = expandGlobs(inputs)
  if files.len == 0:
    logError("No input files specified (use --config with 'headers' or pass files on command line)")
    return 1

  let outputDir = if cfg.outputDir != ".": cfg.outputDir else: "."

  # Check if regeneration is needed (unless --force is specified)
  if not opts.force and not needsRegeneration(files, opts.configFile, outputDir):
    logSuccess("Outputs are up to date (use --force to regenerate)")
    return 0

  let startTime = cpuTime()
  opts.log("Running cpp2nim pipeline on " & $files.len & " file(s)...")

  # Step 1: Parse
  opts.log("\n[1/3] Parsing headers...")
  let p = initCppHeaderParser(cfg)
  var parseResult = initParseResult()
  for file in files:
    opts.logVerbose("Parsing: " & file)
    let header = p.parseFile(file)
    parseResult.headers[file] = header
    parseResult.allDependencies[file] = header.dependencies
    parseResult.allProvides[file] = header.provides
    parseResult.allMissing[file] = header.missing

  # Step 2: Analyze
  opts.log("\n[2/3] Analyzing dependencies...")
  let analyzer = initDependencyAnalyzer(cfg)
  let analysis = analyzer.analyze(parseResult)
  opts.logVerbose("Shared types: " & $analysis.sharedTypes.len)
  opts.logVerbose("Type renames: " & $analysis.typeRenames.len)

  # Merge renames
  var renames = cfg.typeRenames
  for k, v in analysis.typeRenames:
    renames[k] = v

  # Add typedef aliases to renames - this prevents double template params
  # e.g., "math::Vec3f" -> "Vec3f" so that "math::Vec3f<float>" becomes just "Vec3f"
  for filename, header in parseResult.headers:
    for typedef in header.typedefs:
      if "<" in typedef.underlying:  # Only for template instantiation aliases
        let nimName = typedef.name.split("::")[ ^1]
        renames[typedef.fullyQualified] = nimName
        # Also add reverse mapping: underlying type -> typedef name
        # This allows recognizing expanded types like "color_t[cfloat,4]" as "color_rgba_t"
        let underlyingNim = getNimType(typedef.underlying, renames)
        if underlyingNim != nimName:
          renames[underlyingNim] = nimName

  # Add suffix-stripped type renames (e.g., mjData_ -> mjData)
  # This ensures field types and other references use the stripped name
  for suffix in cfg.stripTypeSuffixes:
    for filename, header in parseResult.headers:
      for typedef in header.typedefs:
        if typedef.structData.isSome:
          let structName = typedef.structData.get.name
          if structName.endsWith(suffix) and structName.len > suffix.len:
            let strippedName = structName[0 ..< structName.len - suffix.len]
            # Map original name to stripped name for type lookups
            renames[structName] = strippedName
            renames[typedef.structData.get.fullyQualified] = strippedName
      for s in header.structs:
        if s.name.endsWith(suffix) and s.name.len > suffix.len:
          let strippedName = s.name[0 ..< s.name.len - suffix.len]
          renames[s.name] = strippedName
          renames[s.fullyQualified] = strippedName

  # Step 3: Generate
  opts.log("\n[3/3] Generating bindings...")
  opts.logVerbose("Base classes: " & $analysis.baseClasses.len)
  let gen = initNimCodeGenerator(cfg, renames, analysis.baseClasses)
  let configDir = if opts.configFile.len > 0: parentDir(opts.configFile) else: getCurrentDir()
  createDir(outputDir)

  var filesGenerated = 0

  # Generate shared_types.nim if there are shared types
  if analysis.sharedTypes.len > 0:
    let sharedPath = outputDir / "shared_types.nim"
    var sharedCode = "# Auto-generated shared types for cpp2nim\n"
    sharedCode.add("# Generated: " & $now() & "\n\n")
    sharedCode.add("type\n")
    sharedCode.add("  ccstring* = cstring  ## const char*\n")
    sharedCode.add("  ConstPointer* = pointer  ## const void*\n")
    sharedCode.add("  ConstPtr*[T] = ptr T  ## const T* return type\n")
    sharedCode.add("\n")

    # Collect shared types into entries for sorting
    var entries: seq[SharedTypeEntry]

    for filename, header in parseResult.headers:
      let incl = getHeaderIncludePath(filename, cfg.searchPaths)

      for e in header.enums:
        if opts.verbose:
          echo "  Enum: ", e.fullyQualified, " shared=", isSharedType(e.fullyQualified, analysis.sharedTypes)
        if isSharedType(e.fullyQualified, analysis.sharedTypes):
          entries.add(SharedTypeEntry(
            name: e.fullyQualified,
            deps: @[],
            kind: "enum",
            code: gen.generateEnum(e, incl),
            isGeneric: false,
            isBaseClass: false
          ))

      for s in header.structs:
        if isSharedType(s.fullyQualified, analysis.sharedTypes):
          entries.add(SharedTypeEntry(
            name: s.fullyQualified,
            deps: s.underlyingDeps & s.baseTypes,
            kind: "struct",
            code: gen.generateStruct(s, incl),
            isGeneric: s.templateParams.len > 0,
            isBaseClass: s.fullyQualified in analysis.baseClasses or
                         s.name in analysis.baseClasses
          ))

      for c in header.classes:
        if isSharedType(c.fullyQualified, analysis.sharedTypes):
          entries.add(SharedTypeEntry(
            name: c.fullyQualified,
            deps: c.baseTypes,
            kind: "class",
            code: gen.generateClass(c, incl),
            isGeneric: c.templateParams.len > 0,
            isBaseClass: c.fullyQualified in analysis.baseClasses or
                         c.name in analysis.baseClasses
          ))

      for t in header.typedefs:
        # Check if typedef has an embedded enum that's a shared type
        if t.enumData.isSome:
          let enumData = t.enumData.get
          if isSharedType(enumData.fullyQualified, analysis.sharedTypes):
            entries.add(SharedTypeEntry(
              name: enumData.fullyQualified,
              deps: @[],
              kind: "enum",
              code: gen.generateEnum(enumData, incl),
              isGeneric: false,
              isBaseClass: false
            ))
        elif isSharedType(t.fullyQualified, analysis.sharedTypes):
          let td = gen.generateTypedef(t, incl)
          if td.len > 0:
            entries.add(SharedTypeEntry(
              name: t.fullyQualified,
              deps: t.underlyingDeps,
              kind: "typedef",
              code: td,
              isGeneric: false,
              isBaseClass: false
            ))

    # Sort types topologically
    let sorted = topoSortTypes(entries)

    # Generate code from sorted entries
    if sorted.len > 0:
      sharedCode.add("type\n")
      for entry in sorted:
        sharedCode.add(entry.code)

    # Apply patch file and post-processing
    let patchedShared = applyPatchFile(sharedCode, sharedPath, cfg, configDir)
    let processedShared = cfg.postFixes.processFile(sharedPath, patchedShared)
    writeFile(sharedPath, processedShared)
    opts.logVerbose("Generated: " & sharedPath)
    inc filesGenerated

  # Generate individual files
  for filename, header in parseResult.headers:
    let basename = extractFilename(filename).changeFileExt(".nim")
    let outputPath = outputDir / basename

    var code = "# Auto-generated Nim bindings for " & filename & "\n"
    code.add("# Generated: " & $now() & "\n\n")

    # Add imports
    var imports: seq[string]

    # Import shared_types if we have shared types
    if analysis.sharedTypes.len > 0:
      imports.add("shared_types")

    # Add imports from import graph
    if filename in analysis.importGraph:
      for imp in analysis.importGraph[filename]:
        if imp notin imports and imp != basename.changeFileExt(""):
          imports.add(imp)

    if imports.len > 0:
      code.add("import " & imports.join(", ") & "\n\n")

    # Helper types (only if no shared_types)
    if analysis.sharedTypes.len == 0:
      code.add("type\n")
      code.add("  ccstring* = cstring  ## const char*\n")
      code.add("  ConstPointer* = pointer  ## const void*\n")
      code.add("  ConstPtr*[T] = ptr T  ## const T* return type\n")
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
      # Skip if typedef itself is shared, or if it contains a shared enum
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

    # Apply patch file and post-processing
    let patchedCode = applyPatchFile(code, outputPath, cfg, configDir)
    let processedCode = cfg.postFixes.processFile(outputPath, patchedCode)
    writeFile(outputPath, processedCode)
    opts.logVerbose("Generated: " & outputPath)
    inc filesGenerated

  let elapsed = cpuTime() - startTime
  opts.log("")
  logSuccess("Pipeline complete in " & formatFloat(elapsed, ffDecimal, 2) & "s")
  logSuccess("Generated " & $filesGenerated & " binding file(s) in " & outputDir)
  return 0


proc main(): int =
  let opts = parseArgs()

  case opts.command
  of cmdHelp:
    echo Usage
    return 0

  of cmdVersion:
    echo "cpp2nim version ", Version
    return 0

  of cmdNone, cmdParse, cmdAnalyze, cmdGenerate, cmdAll:
    discard

  let cfg = buildConfig(opts)

  # Show usage if no command and no inputs (from CLI or config)
  if opts.command == cmdNone and opts.inputs.len == 0 and cfg.headers.len == 0:
    echo Usage
    return 0

  # Validate config if not quiet
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
