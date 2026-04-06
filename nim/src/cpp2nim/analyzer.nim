## Dependency analysis for cpp2nim.
##
## Analyzes dependencies between parsed headers and determines which types
## should be moved to shared type files.

import std/[sets, tables, options, os, strutils, algorithm, sequtils]
import ./config
import ./models
import ./utils

type
  AnalysisResult* = object
    ## Result of dependency analysis.
    ##
    ## Fields:
    ##   fileRelationships: For each file, maps other files to the types they provide.
    ##   sharedTypes: Types that should be in the shared types file.
    ##   typeRenames: Mapping of types that need renaming to avoid conflicts.
    ##   importGraph: For each file, the files it needs to import.
    ##   baseClasses: Classes that are used as base classes (need of RootObj).
    fileRelationships*: Table[string, Table[string, HashSet[string]]]
    sharedTypes*: HashSet[string]
    typeRenames*: Table[string, string]
    importGraph*: Table[string, HashSet[string]]
    baseClasses*: HashSet[string]

  DependencyAnalyzer* = object
    ## Analyze dependencies between parsed headers.
    ##
    ## Determines which types are shared between files and need to be
    ## moved to a common types file.
    ##
    ## Example:
    ##   let analyzer = initDependencyAnalyzer(config)
    ##   let result = analyzer.analyze(parseResult)
    ##   echo result.sharedTypes
    config*: Config


proc initAnalysisResult*(): AnalysisResult =
  ## Create an empty AnalysisResult.
  AnalysisResult()


proc initDependencyAnalyzer*(config: Config = defaultConfig()): DependencyAnalyzer =
  ## Initialize a dependency analyzer.
  DependencyAnalyzer(config: config)


proc computeRelationships(self: DependencyAnalyzer, parseResult: ParseResult): Table[string, Table[string, HashSet[string]]] =
  ## Compute which files provide which types to which other files.
  var filenames: HashSet[string]
  for k in parseResult.headers.keys:
    filenames.incl(k)

  for filename in filenames:
    let missing = parseResult.allMissing.getOrDefault(filename)
    var fileDeps: Table[string, HashSet[string]]

    for otherFile in filenames:
      if otherFile == filename:
        continue

      let provides = parseResult.allProvides.getOrDefault(otherFile)

      # Direct matches
      var found: HashSet[string]
      for m in missing:
        if m in provides:
          found.incl(m)

      # Note: Python version handles (value, enum) tuples for enum values
      # In Nim models, enums are tracked differently - this may need adjustment
      # based on how the parser populates provides/missing sets

      if found.len > 0:
        fileDeps[otherFile] = found

    result[filename] = fileDeps


proc resolveShortName(shortName: string, allNames: seq[string]): string =
  ## Resolve a short type name to its fully qualified form.
  ##
  ## Args:
  ##   shortName: Short type name like "Point"
  ##   allNames: All fully qualified names like "ldtk::Point"
  ##
  ## Returns:
  ##   Fully qualified name if found, otherwise empty string.
  if shortName in allNames:
    return shortName

  # Try to find a match ending with ::shortName
  let suffix = "::" & shortName
  for name in allNames:
    if name.endsWith(suffix):
      return name

  return ""


proc getFieldDeps(fields: seq[FieldDecl]): seq[string] =
  ## Extract type dependencies from struct/class fields.
  for field in fields:
    let deps = getTemplateDependencies(field.typeName)
    for dep in deps:
      result.add(dep)


proc findTypeDependencies(self: DependencyAnalyzer, typeName: string, parseResult: ParseResult,
                          visited: var HashSet[string]): HashSet[string] =
  ## Find all types that a given type depends on.
  ##
  ## Args:
  ##   typeName: The type to find dependencies for.
  ##   parseResult: Parsed header data.
  ##   visited: Already visited types (for cycle detection).
  ##
  ## Returns:
  ##   Set of dependent type names.
  if typeName in visited:
    return

  visited.incl(typeName)

  # Collect all types from all headers
  var allClasses: seq[tuple[fullyQualified: string, underlyingDeps: seq[string]]]
  var allEnums: seq[string]

  for header in parseResult.headers.values:
    for s in header.structs:
      # Include both underlyingDeps and field type dependencies
      let fieldDeps = getFieldDeps(s.fields)
      allClasses.add((s.fullyQualified, s.underlyingDeps & s.baseTypes & fieldDeps))
    for c in header.classes:
      # Include base types and field type dependencies for classes
      let fieldDeps = getFieldDeps(c.fields)
      allClasses.add((c.fullyQualified, c.baseTypes & fieldDeps))
    for t in header.typedefs:
      # Include field dependencies if typedef has embedded struct
      var deps = t.underlyingDeps
      if t.structData.isSome:
        let fieldDeps = getFieldDeps(t.structData.get.fields)
        deps = deps & fieldDeps
      allClasses.add((t.fullyQualified, deps))
    for e in header.enums:
      allEnums.add(e.fullyQualified)

  var classesFully: seq[string]
  for c in allClasses:
    classesFully.add(c.fullyQualified)

  # Find the type and its dependencies
  for (fullyQualified, underlyingDeps) in allClasses:
    if fullyQualified != typeName:
      continue

    for dep in underlyingDeps:
      # Try to resolve short names to fully qualified names
      let resolvedDep = resolveShortName(dep, classesFully)
      let resolvedEnum = resolveShortName(dep, allEnums)

      if resolvedEnum.len > 0:
        result.incl(resolvedEnum)
      elif resolvedDep.len > 0:
        if resolvedDep notin result:
          let newDeps = self.findTypeDependencies(resolvedDep, parseResult, visited)
          result.incl(resolvedDep)
          for d in newDeps:
            result.incl(d)


proc computeSharedTypes(self: DependencyAnalyzer, parseResult: ParseResult,
                        relationships: Table[string, Table[string, HashSet[string]]]): HashSet[string] =
  ## Determine which types should be in the shared types file.
  var shared: HashSet[string]

  # Types needed by multiple files
  for deps in relationships.values:
    for types in deps.values:
      for t in types:
        shared.incl(t)

  # Add dependencies of shared types
  var allShared = shared
  for typeName in shared:
    var visited: HashSet[string]
    let deps = self.findTypeDependencies(typeName, parseResult, visited)
    for d in deps:
      allShared.incl(d)

  # Auto-promote types that appear in multiple files to avoid duplicate definitions
  var typeFiles: Table[string, int]  # fullyQualified -> file count
  for _, header in parseResult.headers:
    for s in header.structs:
      typeFiles.mgetOrPut(s.fullyQualified, 0).inc
    for e in header.enums:
      typeFiles.mgetOrPut(e.fullyQualified, 0).inc
    for t in header.typedefs:
      typeFiles.mgetOrPut(t.fullyQualified, 0).inc
  for typeName, count in typeFiles:
    if count > 1:
      allShared.incl(typeName)

  # Add forced shared types from config
  for t in self.config.forceSharedTypes:
    allShared.incl(t)

  result = allShared


proc getNewName(self: DependencyAnalyzer, fullName: string, existingNames: seq[string],
                rootNamespace: Option[string]): string =
  ## Generate a new unique name for a type.
  ##
  ## Args:
  ##   fullName: Fully qualified C++ name.
  ##   existingNames: Names already in use.
  ##   rootNamespace: Root namespace to strip.
  ##
  ## Returns:
  ##   New unique name.
  let parts = fullName.split("::")
  if rootNamespace.isSome and parts.len > 0 and parts[0] == rootNamespace.get:
    return parts[1..^1].join("_")
  return flattenNamespace(fullName)


proc computeRenames(self: DependencyAnalyzer, parseResult: ParseResult,
                    sharedTypes: HashSet[string]): Table[string, string] =
  ## Generate new names for types that would otherwise conflict.
  # Find types in shared that have the same short name
  var shortNames: Table[string, seq[string]]

  for typeName in sharedTypes:
    let short = typeName.split("::")[^1]
    if short notin shortNames:
      shortNames[short] = @[]
    shortNames[short].add(typeName)

  # Rename types with conflicting short names
  let rootNamespace = self.config.rootNamespace

  for short, fullNames in shortNames:
    if fullNames.len > 1:
      for full in fullNames:
        var existingNames: seq[string]
        for v in result.values:
          existingNames.add(v)
        let newName = self.getNewName(full, existingNames, rootNamespace)
        result[full] = newName


proc computeImports(self: DependencyAnalyzer, parseResult: ParseResult,
                    relationships: Table[string, Table[string, HashSet[string]]]): Table[string, HashSet[string]] =
  ## Build the import graph for generated files.
  for filename, deps in relationships:
    var fileImports: HashSet[string]
    for depFile in deps.keys:
      # Convert path to module name (replace dashes for valid Nim identifiers)
      let moduleName = extractFilename(depFile).changeFileExt("").replace("-", "_")
      fileImports.incl(moduleName)
    result[filename] = fileImports


proc computeBaseClasses(self: DependencyAnalyzer, parseResult: ParseResult): HashSet[string] =
  ## Find all classes that are used as base classes.
  ## These need `of RootObj` pragma for inheritance to work.
  for header in parseResult.headers.values:
    for cls in header.classes:
      for baseType in cls.baseTypes:
        # Clean the base type name (remove const, &, etc.)
        var baseName = baseType.strip()
        if baseName.startsWith("const "):
          baseName = baseName[6..^1].strip()
        # Remove template params for matching
        let bracketIdx = baseName.find('<')
        if bracketIdx >= 0:
          baseName = baseName[0..<bracketIdx]
        result.incl(baseName)

    for struct in header.structs:
      for baseType in struct.baseTypes:
        var baseName = baseType.strip()
        if baseName.startsWith("const "):
          baseName = baseName[6..^1].strip()
        let bracketIdx = baseName.find('<')
        if bracketIdx >= 0:
          baseName = baseName[0..<bracketIdx]
        result.incl(baseName)

  # Also include types from config.inheritableTypes
  for t in self.config.inheritableTypes:
    result.incl(t)


proc analyze*(self: DependencyAnalyzer, parseResult: ParseResult): AnalysisResult =
  ## Perform full dependency analysis.
  ##
  ## Args:
  ##   parseResult: The result from parsing headers.
  ##
  ## Returns:
  ##   AnalysisResult with dependency information.
  result = initAnalysisResult()

  # Compute file relationships
  result.fileRelationships = self.computeRelationships(parseResult)

  # Identify shared types
  result.sharedTypes = self.computeSharedTypes(parseResult, result.fileRelationships)

  # Find base classes that need of RootObj
  result.baseClasses = self.computeBaseClasses(parseResult)

  # Base classes should be shared types (they're used by multiple derived classes)
  for baseClass in result.baseClasses:
    result.sharedTypes.incl(baseClass)

  # Compute type renames
  result.typeRenames = self.computeRenames(parseResult, result.sharedTypes)

  # Build import graph
  result.importGraph = self.computeImports(parseResult, result.fileRelationships)


# Legacy format support functions

proc legacyRelationships*(data: seq[tuple[filename: string, idx: int, kind: string, extra: string]],
                          provides: Table[string, HashSet[string]],
                          missing: Table[string, HashSet[string]]): Table[string, Table[string, HashSet[string]]] =
  ## Compute file relationships from legacy format.
  var filenames: HashSet[string]
  for item in data:
    filenames.incl(item.filename)

  for filename in filenames:
    let fileMissing = missing.getOrDefault(filename)
    var fileDeps: Table[string, HashSet[string]]

    for other in filenames:
      if other == filename:
        continue

      let fileProvides = provides.getOrDefault(other)
      var found: HashSet[string]
      for m in fileMissing:
        if m in fileProvides:
          found.incl(m)

      if found.len > 0:
        fileDeps[other] = found

    result[filename] = fileDeps


proc findDependenciesLegacy*(obj: string, classesInfo: seq[tuple[fullyQualified: string, underlyingDeps: seq[string]]],
                             enumsFully: seq[string], classesFully: seq[string],
                             visited: var HashSet[string]): HashSet[string] =
  ## Find all dependencies of a type (simplified interface).
  ##
  ## Args:
  ##   obj: Type name to find dependencies for.
  ##   classesInfo: Sequence of (fullyQualified, underlyingDeps) for classes/structs/typedefs.
  ##   enumsFully: Sequence of fully qualified enum names.
  ##   classesFully: Sequence of fully qualified class names.
  ##   visited: Recursion tracking set.
  ##
  ## Returns:
  ##   Set of dependency type names.
  if obj in visited:
    return

  visited.incl(obj)

  for (fullyQualified, underlyingDeps) in classesInfo:
    if fullyQualified != obj:
      continue

    for dep in underlyingDeps:
      if dep in enumsFully:
        result.incl(dep)
      elif dep in classesFully:
        if dep notin result:
          let newDeps = findDependenciesLegacy(dep, classesInfo, enumsFully, classesFully, visited)
          result.incl(dep)
          for d in newDeps:
            result.incl(d)


proc collectSharedObjects*(relationships: Table[string, Table[string, HashSet[string]]],
                           forceShared: seq[string] = @[]): HashSet[string] =
  ## Collect objects that need to be moved to shared types file.
  ##
  ## Args:
  ##   relationships: File relationship mapping.
  ##   forceShared: Types to force into shared file.
  ##
  ## Returns:
  ##   Set of type names to move to shared file.
  for deps in relationships.values:
    for typeSet in deps.values:
      for t in typeSet:
        result.incl(t)

  for t in forceShared:
    result.incl(t)


proc topoSortTypes*(entries: seq[SharedTypeEntry]): seq[SharedTypeEntry] =
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
