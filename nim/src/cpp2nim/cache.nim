## Cache system for cpp2nim.
##
## Provides hash-based caching to enable lazy reparsing. When only generation
## config changes (e.g., post_fixes), parsing can be skipped using cached AST.

import std/[os, json, hashes, options, tables]
import ./config
import ./postprocess

type
  CacheEntry* = object
    ## Cache entry storing parse hash, generation hash, and cached AST.
    parseHash*: string      ## Hash of headers + parse config
    genHash*: string        ## Hash of generation config
    parsedData*: JsonNode   ## Cached parsed result

proc hashParseConfig*(cfg: Config, headerFiles: seq[string]): string =
  ## Hash inputs that affect parsing stage.
  var h: Hash = 0
  # Hash header file contents
  for f in headerFiles:
    if fileExists(f):
      h = h !& hash(readFile(f))
      h = h !& hash(f)
  # Hash parse-related config
  for p in cfg.searchPaths: h = h !& hash(p)
  for d in cfg.defines: h = h !& hash(d)
  for a in cfg.extraArgs: h = h !& hash(a)
  h = h !& hash(cfg.cMode)
  for p in cfg.preIncludeHeaders: h = h !& hash(p)
  for f in cfg.ignoreFiles: h = h !& hash(f)
  result = $(!$h)

proc hashGenConfig*(cfg: Config): string =
  ## Hash inputs that affect generation stage (but not parsing).
  var h: Hash = 0
  h = h !& hash(cfg.camelCase)
  if cfg.rootNamespace.isSome: h = h !& hash(cfg.rootNamespace.get)
  for k, v in cfg.typeRenames: h = h !& hash(k & ":" & v)
  for t in cfg.ignoreTypes: h = h !& hash(t)
  for f in cfg.ignoreFields: h = h !& hash(f)
  for t in cfg.inheritableTypes: h = h !& hash(t)
  for f in cfg.varargsFunctions: h = h !& hash(f)
  for t in cfg.forceSharedTypes: h = h !& hash(t)
  for s in cfg.stripTypeSuffixes: h = h !& hash(s)
  for k, v in cfg.patchFiles: h = h !& hash(k & ":" & v)
  # Hash post_fixes
  for rule in cfg.postFixes.rules:
    h = h !& hash(rule.filePattern)
    for r in rule.replacements:
      h = h !& hash(r.pattern & r.replacement & $r.mode)
  result = $(!$h)

proc loadCache*(cacheFile: string): CacheEntry =
  ## Load cache from file. Returns empty entry if file doesn't exist or is invalid.
  if fileExists(cacheFile):
    try:
      let j = parseJson(readFile(cacheFile))
      result.parseHash = j{"parse_hash"}.getStr("")
      result.genHash = j{"gen_hash"}.getStr("")
      result.parsedData = j{"parsed_data"}
    except:
      discard

proc saveCache*(cacheFile: string, entry: CacheEntry) =
  ## Save cache to file.
  let j = %*{
    "parse_hash": entry.parseHash,
    "gen_hash": entry.genHash,
    "parsed_data": entry.parsedData
  }
  writeFile(cacheFile, $j)
