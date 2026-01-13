## Configuration for cpp2nim.
##
## Centralized configuration to replace scattered function parameters.

import std/[json, options, tables, os, cpuinfo]
import postprocess

type
  Config* = object
    ## Configuration for cpp2nim parsing and generation.
    ##
    ## Example:
    ##   let config = initConfig(
    ##     searchPaths = @["/usr/include"],
    ##     extraArgs = @["-std=c++17"],
    ##     outputDir = "bindings"
    ##   )

    # Input files
    headers*: seq[string]          ## Header files/globs to process (e.g., ["src/*.h"])

    # Parsing options
    searchPaths*: seq[string]      ## Include directories for clang (-I paths)
    extraArgs*: seq[string]        ## Additional clang compiler arguments
    defines*: seq[string]          ## Preprocessor defines (e.g., "DEBUG", "VERSION=2")
    cMode*: bool                   ## Parse as C instead of C++ (-x c vs -x c++)
    enumToConst*: seq[string]      ## Enum names to treat as constants
    ignoreFiles*: seq[string]      ## Files to skip during parsing
    preIncludeHeaders*: seq[string]  ## Headers to force-include before parsing each file (for C libs with typedef deps)

    # Output options
    outputDir*: string             ## Directory for generated output
    rootNamespace*: Option[string] ## Root namespace to strip from names
    camelCase*: bool               ## Convert identifiers to camelCase

    # Type handling
    typeRenames*: Table[string, string]  ## Manual type rename mappings
    ignoreTypes*: seq[string]            ## Types to skip during generation
    ignoreFields*: seq[string]           ## Fields to exclude from structs/classes
    inheritableTypes*: seq[string]       ## Types marked as inheritable
    varargsFunctions*: seq[string]       ## Functions to mark as varargs
    forceSharedTypes*: seq[string]       ## Types to force into shared types file
    stripTypeSuffixes*: seq[string]      ## Suffixes to strip from type names (e.g., ["_", "_t", "_s"])

    # Performance
    parallel*: bool          ## Enable parallel parsing
    numWorkers*: Option[int] ## Number of worker processes (none = cpu_count)

    # Post-processing
    postFixes*: PostProcessor  ## Text replacements after generation
    patchFiles*: Table[string, string]  ## Patch files to prepend (output_file -> patch_file_path)


proc initConfig*(
  headers: seq[string] = @[],
  searchPaths: seq[string] = @[],
  extraArgs: seq[string] = @[],
  defines: seq[string] = @[],
  cMode = false,
  enumToConst: seq[string] = @[],
  ignoreFiles: seq[string] = @[],
  preIncludeHeaders: seq[string] = @[],
  outputDir = ".",
  rootNamespace = none(string),
  camelCase = true,
  typeRenames: Table[string, string] = initTable[string, string](),
  ignoreTypes: seq[string] = @[],
  ignoreFields: seq[string] = @[],
  inheritableTypes: seq[string] = @[],
  varargsFunctions: seq[string] = @[],
  forceSharedTypes: seq[string] = @[],
  stripTypeSuffixes: seq[string] = @[],
  parallel = true,
  numWorkers = none(int),
  postFixes = initPostProcessor(),
  patchFiles: Table[string, string] = initTable[string, string]()
): Config =
  ## Create a Config with specified values and defaults.
  Config(
    headers: headers,
    searchPaths: searchPaths,
    extraArgs: extraArgs,
    defines: defines,
    cMode: cMode,
    enumToConst: enumToConst,
    ignoreFiles: ignoreFiles,
    preIncludeHeaders: preIncludeHeaders,
    outputDir: outputDir,
    rootNamespace: rootNamespace,
    camelCase: camelCase,
    typeRenames: typeRenames,
    ignoreTypes: ignoreTypes,
    ignoreFields: ignoreFields,
    inheritableTypes: inheritableTypes,
    varargsFunctions: varargsFunctions,
    forceSharedTypes: forceSharedTypes,
    stripTypeSuffixes: stripTypeSuffixes,
    parallel: parallel,
    numWorkers: numWorkers,
    postFixes: postFixes,
    patchFiles: patchFiles
  )


proc defaultConfig*(): Config =
  ## Create a Config with all default values.
  initConfig()


proc effectiveWorkers*(c: Config): int =
  ## Get the effective number of workers (resolves none to CPU count).
  if c.numWorkers.isSome:
    c.numWorkers.get
  else:
    countProcessors()


# JSON serialization (for IPC)

proc optToJson(opt: Option[string]): JsonNode =
  if opt.isSome: %opt.get else: newJNull()

proc optIntToJson(opt: Option[int]): JsonNode =
  if opt.isSome: %opt.get else: newJNull()

proc jsonToOptStr(node: JsonNode): Option[string] =
  if node.isNil or node.kind == JNull: none(string) else: some(node.getStr)

proc jsonToOptInt(node: JsonNode): Option[int] =
  if node.isNil or node.kind == JNull: none(int) else: some(node.getInt)

proc `%`*(c: Config): JsonNode =
  ## Serialize Config to JSON for IPC.
  var renames = newJObject()
  for k, v in c.typeRenames:
    renames[k] = %v

  %*{
    "search_paths": c.searchPaths,
    "extra_args": c.extraArgs,
    "defines": c.defines,
    "c_mode": c.cMode,
    "enum_to_const": c.enumToConst,
    "ignore_files": c.ignoreFiles,
    "pre_include_headers": c.preIncludeHeaders,
    "output_dir": c.outputDir,
    "root_namespace": optToJson(c.rootNamespace),
    "camel_case": c.camelCase,
    "type_renames": renames,
    "ignore_types": c.ignoreTypes,
    "ignore_fields": c.ignoreFields,
    "inheritable_types": c.inheritableTypes,
    "varargs_functions": c.varargsFunctions,
    "force_shared_types": c.forceSharedTypes,
    "strip_type_suffixes": c.stripTypeSuffixes,
    "parallel": c.parallel,
    "num_workers": optIntToJson(c.numWorkers)
  }


proc jsonToStrSeq(node: JsonNode, key: string): seq[string] =
  ## Safely extract a string sequence from JSON.
  if node.hasKey(key) and node[key].kind == JArray:
    for item in node[key]:
      result.add(item.getStr)

proc parsePostFixes(node: JsonNode): PostProcessor =
  ## Parse post_fixes from JSON config.
  ## Format: {"file_pattern": [{"pattern": "...", "replacement": "...", "mode": "regex|plain"}]}
  result = initPostProcessor()

  # Support both snake_case and camelCase
  let postFixesNode = if node.hasKey("post_fixes"): node["post_fixes"]
                      elif node.hasKey("postFixes"): node["postFixes"]
                      else: return
  if postFixesNode.kind != JObject:
    return

  for filePattern, rules in postFixesNode:
    if rules.kind != JArray:
      continue
    var replacements: seq[Replacement]
    for rule in rules:
      if rule.kind != JObject:
        continue
      let pattern = rule{"pattern"}.getStr("")
      let replacement = rule{"replacement"}.getStr("")
      let modeStr = rule{"mode"}.getStr("regex")
      let mode = case modeStr
        of "plain": rmPlain
        of "plain_one": rmPlainOne
        of "regex_one": rmRegexOne
        else: rmRegex
      if pattern.len > 0:
        replacements.add(Replacement(pattern: pattern, replacement: replacement, mode: mode))
    if replacements.len > 0:
      result.addRule(filePattern, replacements)

proc toConfig*(node: JsonNode): Config =
  ## Deserialize Config from JSON (for IPC).
  ## Supports both snake_case and camelCase keys.

  # Known config keys (snake_case canonical, camelCase aliases)
  const knownKeys = [
    "search_paths", "searchPaths",
    "extra_args", "extraArgs",
    "defines",
    "c_mode", "cMode",
    "enum_to_const", "enumToConst",
    "ignore_files", "ignoreFiles",
    "pre_include_headers", "preIncludeHeaders",
    "output_dir", "outputDir",
    "root_namespace", "rootNamespace",
    "camel_case", "camelCase",
    "type_renames", "typeRenames",
    "ignore_types", "ignoreTypes",
    "ignore_fields", "ignoreFields",
    "inheritable_types", "inheritableTypes",
    "varargs_functions", "varargsFunctions",
    "force_shared_types", "forceSharedTypes",
    "strip_type_suffixes", "stripTypeSuffixes",
    "parallel",
    "num_workers", "numWorkers",
    "post_fixes", "postFixes",
    "patch_files", "patchFiles",
    # Meta fields (not config options but allowed in config files)
    "name", "headers", "includeDirs", "include_dirs"
  ]

  # Warn about unknown keys
  if node.kind == JObject:
    for key in node.keys:
      if key notin knownKeys:
        stderr.writeLine "Warning: unknown config key '" & key & "' (did you mean snake_case?)"

  # Helper to get value with camelCase fallback
  proc getWithAlias(n: JsonNode, snake, camel: string): JsonNode =
    if n.hasKey(snake): n[snake]
    elif n.hasKey(camel): n[camel]
    else: newJNull()

  proc getStrSeqWithAlias(n: JsonNode, snake, camel: string): seq[string] =
    let val = n.getWithAlias(snake, camel)
    if val.kind == JArray:
      for item in val:
        result.add(item.getStr)

  var typeRenames: Table[string, string]
  let renamesNode = node.getWithAlias("type_renames", "typeRenames")
  if renamesNode.kind == JObject:
    for k, v in renamesNode:
      typeRenames[k] = v.getStr

  let headers = jsonToStrSeq(node, "headers")
  let searchPaths = node.getStrSeqWithAlias("search_paths", "searchPaths")
  let extraArgs = node.getStrSeqWithAlias("extra_args", "extraArgs")
  let defines = jsonToStrSeq(node, "defines")
  let enumToConst = node.getStrSeqWithAlias("enum_to_const", "enumToConst")
  let ignoreFiles = node.getStrSeqWithAlias("ignore_files", "ignoreFiles")
  let preIncludeHeaders = node.getStrSeqWithAlias("pre_include_headers", "preIncludeHeaders")
  let ignoreTypes = node.getStrSeqWithAlias("ignore_types", "ignoreTypes")
  let ignoreFields = node.getStrSeqWithAlias("ignore_fields", "ignoreFields")
  let inheritableTypes = node.getStrSeqWithAlias("inheritable_types", "inheritableTypes")
  let varargsFunctions = node.getStrSeqWithAlias("varargs_functions", "varargsFunctions")
  let forceSharedTypes = node.getStrSeqWithAlias("force_shared_types", "forceSharedTypes")
  let stripTypeSuffixes = node.getStrSeqWithAlias("strip_type_suffixes", "stripTypeSuffixes")
  let postFixes = parsePostFixes(node)

  # Parse patch_files: {"output_file.nim": "patch_file.nim"}
  var patchFiles: Table[string, string]
  let patchNode = node.getWithAlias("patch_files", "patchFiles")
  if patchNode.kind == JObject:
    for k, v in patchNode:
      patchFiles[k] = v.getStr

  Config(
    headers: headers,
    searchPaths: searchPaths,
    extraArgs: extraArgs,
    defines: defines,
    cMode: node.getWithAlias("c_mode", "cMode").getBool(false),
    enumToConst: enumToConst,
    ignoreFiles: ignoreFiles,
    preIncludeHeaders: preIncludeHeaders,
    outputDir: node.getWithAlias("output_dir", "outputDir").getStr("."),
    rootNamespace: jsonToOptStr(node.getWithAlias("root_namespace", "rootNamespace")),
    camelCase: node.getWithAlias("camel_case", "camelCase").getBool(true),
    typeRenames: typeRenames,
    ignoreTypes: ignoreTypes,
    ignoreFields: ignoreFields,
    inheritableTypes: inheritableTypes,
    varargsFunctions: varargsFunctions,
    forceSharedTypes: forceSharedTypes,
    stripTypeSuffixes: stripTypeSuffixes,
    parallel: node{"parallel"}.getBool(true),
    numWorkers: jsonToOptInt(node.getWithAlias("num_workers", "numWorkers")),
    postFixes: postFixes,
    patchFiles: patchFiles
  )


proc mergeWith*(self, other: Config): Config =
  ## Merge another config into this one.
  ##
  ## Values from `other` override values in `self`, except for sequences
  ## which are concatenated and tables which are merged.
  var mergedRenames = self.typeRenames
  for k, v in other.typeRenames:
    mergedRenames[k] = v

  var mergedPatchFiles = self.patchFiles
  for k, v in other.patchFiles:
    mergedPatchFiles[k] = v

  Config(
    headers: self.headers & other.headers,
    searchPaths: self.searchPaths & other.searchPaths,
    extraArgs: self.extraArgs & other.extraArgs,
    defines: self.defines & other.defines,
    cMode: if other.cMode: other.cMode else: self.cMode,
    enumToConst: self.enumToConst & other.enumToConst,
    ignoreFiles: self.ignoreFiles & other.ignoreFiles,
    preIncludeHeaders: self.preIncludeHeaders & other.preIncludeHeaders,
    outputDir: if other.outputDir != ".": other.outputDir else: self.outputDir,
    rootNamespace: if other.rootNamespace.isSome: other.rootNamespace else: self.rootNamespace,
    camelCase: other.camelCase,
    typeRenames: mergedRenames,
    ignoreTypes: self.ignoreTypes & other.ignoreTypes,
    ignoreFields: self.ignoreFields & other.ignoreFields,
    inheritableTypes: self.inheritableTypes & other.inheritableTypes,
    varargsFunctions: self.varargsFunctions & other.varargsFunctions,
    forceSharedTypes: self.forceSharedTypes & other.forceSharedTypes,
    stripTypeSuffixes: self.stripTypeSuffixes & other.stripTypeSuffixes,
    parallel: other.parallel,
    numWorkers: if other.numWorkers.isSome: other.numWorkers else: self.numWorkers,
    postFixes: PostProcessor(rules: self.postFixes.rules & other.postFixes.rules),
    patchFiles: mergedPatchFiles
  )


# File loading

proc loadConfigFromJson*(path: string): Config =
  ## Load configuration from a JSON file.
  ##
  ## Raises:
  ##   IOError: If the file cannot be read.
  ##   JsonParsingError: If the JSON is invalid.
  let content = readFile(path)
  let node = parseJson(content)
  toConfig(node)


proc saveConfigToJson*(c: Config, path: string) =
  ## Save configuration to a JSON file.
  let content = $(%c)
  writeFile(path, content)


# Validation

type
  ConfigError* = object of CatchableError
    ## Configuration validation error.

proc validate*(c: Config) =
  ## Validate configuration, raising ConfigError on issues.
  if c.outputDir != "." and not dirExists(c.outputDir):
    raise newException(ConfigError, "Output directory does not exist: " & c.outputDir)

  for path in c.searchPaths:
    if not dirExists(path):
      raise newException(ConfigError, "Search path does not exist: " & path)

  if c.numWorkers.isSome and c.numWorkers.get <= 0:
    raise newException(ConfigError, "numWorkers must be positive, got: " & $c.numWorkers.get)


proc validateOrWarn*(c: Config): seq[string] =
  ## Validate configuration, returning warnings instead of raising.
  var warnings: seq[string]

  if c.outputDir != "." and not dirExists(c.outputDir):
    warnings.add("Output directory does not exist: " & c.outputDir)

  for path in c.searchPaths:
    if not dirExists(path):
      warnings.add("Search path does not exist: " & path)

  if c.numWorkers.isSome and c.numWorkers.get <= 0:
    warnings.add("numWorkers must be positive, got: " & $c.numWorkers.get)

  warnings


# Global options (for backward compatibility)

var globalOptions: Table[string, JsonNode]

proc setGlobalOption*(key: string, value: JsonNode) =
  ## Set a global option (for backward compatibility).
  globalOptions[key] = value

proc getGlobalOption*(key: string, default: JsonNode = newJNull()): JsonNode =
  ## Get a global option (for backward compatibility).
  globalOptions.getOrDefault(key, default)

proc clearGlobalOptions*() =
  ## Clear all global options.
  globalOptions.clear()
