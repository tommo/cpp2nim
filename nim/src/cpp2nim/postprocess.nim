# Post-processing for generated Nim code.
# Text replacement utilities for fixing up generated code.

import std/[re, os, strutils, tables]

type
  ReplacementMode* = enum
    rmRegex      ## Regex replacement (all occurrences)
    rmPlain      ## Literal string replacement (all occurrences)
    rmRegexOne   ## Regex replacement (first occurrence only)
    rmPlainOne   ## Literal string replacement (first occurrence only)

  Replacement* = object
    pattern*: string
    replacement*: string
    mode*: ReplacementMode

  PostProcessConfig* = object
    filePattern*: string  ## Glob pattern for files to apply rules to
    replacements*: seq[Replacement]

  PostProcessor* = object
    rules*: seq[PostProcessConfig]


proc initReplacement*(pattern, replacement: string,
                      mode = rmRegex): Replacement =
  Replacement(pattern: pattern, replacement: replacement, mode: mode)

proc initPostProcessConfig*(filePattern: string,
                            replacements: seq[Replacement] = @[]): PostProcessConfig =
  PostProcessConfig(filePattern: filePattern, replacements: replacements)

proc initPostProcessor*(rules: seq[PostProcessConfig] = @[]): PostProcessor =
  PostProcessor(rules: rules)


proc addRule*(pp: var PostProcessor, filePattern: string,
              replacements: seq[Replacement]) =
  pp.rules.add(PostProcessConfig(filePattern: filePattern,
                                  replacements: replacements))

proc matchGlob(filename, pattern: string): bool =
  ## Simple glob matching for file patterns
  if pattern == "*":
    return true
  if pattern.startsWith("*."):
    let ext = pattern[1..^1]
    return filename.endsWith(ext)
  if pattern.endsWith("*"):
    let prefix = pattern[0..^2]
    return filename.startsWith(prefix)
  return filename == pattern

proc applyReplacement(content: string, repl: Replacement): string =
  case repl.mode
  of rmPlain:
    result = content.replace(repl.pattern, repl.replacement)
  of rmPlainOne:
    let pos = content.find(repl.pattern)
    if pos >= 0:
      result = content[0..<pos] & repl.replacement &
               content[pos + repl.pattern.len..^1]
    else:
      result = content
  of rmRegex:
    result = content.replacef(re(repl.pattern), repl.replacement)
  of rmRegexOne:
    result = content.replacef(re(repl.pattern), repl.replacement)
    # Note: Nim's replacef replaces all by default
    # For single replacement, we need manual handling
    let regex = re(repl.pattern)
    let (first, last) = content.findBounds(regex)
    if first >= 0:
      let matched = content[first..last]
      let replaced = matched.replacef(regex, repl.replacement)
      result = content[0..<first] & replaced & content[last+1..^1]
    else:
      result = content

proc processFile*(pp: PostProcessor, filename, content: string): string =
  result = content
  let basename = extractFilename(filename)

  for rule in pp.rules:
    if not matchGlob(basename, rule.filePattern):
      continue
    for repl in rule.replacements:
      result = applyReplacement(result, repl)

proc processAll*(pp: PostProcessor,
                 files: Table[string, string]): Table[string, string] =
  result = initTable[string, string]()
  for name, content in files:
    result[name] = pp.processFile(name, content)


# Legacy format support

proc fromLegacyFormat*(replacements: seq[(string, string)],
                       defaultMode = rmRegex): PostProcessor =
  var rules: seq[Replacement]
  for (pattern, replacement) in replacements:
    rules.add(Replacement(pattern: pattern, replacement: replacement,
                          mode: defaultMode))
  result = PostProcessor(rules: @[PostProcessConfig(filePattern: "*",
                                                     replacements: rules)])

proc fromLegacyFormat*(replacements: seq[(string, string, ReplacementMode)]): PostProcessor =
  var rules: seq[Replacement]
  for (pattern, replacement, mode) in replacements:
    rules.add(Replacement(pattern: pattern, replacement: replacement, mode: mode))
  result = PostProcessor(rules: @[PostProcessConfig(filePattern: "*",
                                                     replacements: rules)])


# File operations (backward-compatible)

proc subInFile*(filename: string,
                oldToNew: seq[(string, string)],
                defaultMode = rmRegex) =
  let bakFile = filename & ".bak"
  let newFile = filename & ".new"

  moveFile(filename, bakFile)
  let content = readFile(bakFile)

  let processor = fromLegacyFormat(oldToNew, defaultMode)
  let processed = processor.processFile(filename, content)

  writeFile(newFile, processed)
  moveFile(newFile, filename)
  removeFile(bakFile)

proc appendToFile*(filename, text: string) =
  let f = open(filename, fmAppend)
  defer: f.close()
  f.write(text)
