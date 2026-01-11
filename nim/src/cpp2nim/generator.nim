## Nim code generator for cpp2nim.
##
## Generates Nim binding code from parsed and analyzed C++ headers.

import std/[tables, strutils, sequtils, algorithm, options, sets, re]
import models, utils, config

# C++ to Nim basic type mapping
const BasicTypeMap* = {
  "void": "void",
  "void *": "pointer",
  "const void *": "ConstPointer",
  "const char *": "ccstring",
  "_Bool": "bool",
  "bool": "bool",
  "long": "clong",
  "unsigned long": "culong",
  "unsigned int": "cuint",
  "unsigned short": "cushort",
  "short": "cshort",
  "int": "cint",
  "size_t": "csize_t",
  "ptrdiff_t": "int",  # platform-sized signed int
  "long long": "clonglong",
  "long double": "clongdouble",
  "float": "cfloat",
  "double *": "ptr cdouble",
  "double": "cdouble",
  "char *": "cstring",
  "char": "cchar",
  "signed char": "cschar",
  "unsigned char": "uint8",
  "unsigned long long": "culonglong",
  "char**": "cstringArray",
  # stdint.h types
  "int8_t": "int8",
  "int16_t": "int16",
  "int32_t": "int32",
  "int64_t": "int64",
  "uint8_t": "uint8",
  "uint16_t": "uint16",
  "uint32_t": "uint32",
  "uint64_t": "uint64",
  "uintptr_t": "uint",  # pointer-sized unsigned int
  "intptr_t": "int",    # pointer-sized signed int
  # std:: prefixed stdint types
  "std::int8_t": "int8",
  "std::int16_t": "int16",
  "std::int32_t": "int32",
  "std::int64_t": "int64",
  "std::uint8_t": "uint8",
  "std::uint16_t": "uint16",
  "std::uint32_t": "uint32",
  "std::uint64_t": "uint64",
  "std::size_t": "csize_t",
  "std::ptrdiff_t": "int",
  # unsigned types
  "unsigned int": "cuint",
  "unsigned char": "cuchar",
  "unsigned short": "cushort",
  "unsigned long": "culong",
  "unsigned long long": "culonglong",
  "signed char": "cschar",
}.toTable

let templatePattern = re"([^<]+)[<]*([^>]*)[>]*"


proc normalizePtrType*(cType: string): string =
  ## Normalize pointer type spacing.
  result = cType.strip()
  result = result.replacef(re"(\w)\*", "$1 *")
  result = result.replacef(re"const (const )*", "const ")


proc getNimArrayType*(cType: string, rename: Table[string, string]): string

proc getNimProcType*(cType: string, rename: Table[string, string], isConst: bool = false): string

proc getNimType*(cType: string, rename: Table[string, string] = initTable[string, string](),
                 returnType: bool = false): string =
  ## Convert a C++ type to its Nim equivalent.
  var cType = normalizePtrType(cType)

  # Handle C arrays first (but NOT C++ templates like vector<int>)
  # C arrays: int[10], char[], etc. - have [] without <>
  # C++ templates: vector<int> - have <> which should NOT be treated as arrays
  if cType.endsWith("]") and "<" notin cType:
    cType = getNimArrayType(cType, rename)

  var isVar = true
  var isConst = false

  # Special cases
  if cType == "const void *":
    return "ConstPointer"
  if cType == "const char *":
    return "ccstring"

  # Handle trailing const pointer (const *)
  if cType.endsWith("const *"):
    isConst = true
    cType = cType[0..^8] & "*"

  # Handle const pointer (*const) - pointer itself is const, points to non-const
  # e.g., "Level *const" -> "ptr Level"
  if cType.endsWith(" *const") or cType.endsWith("*const"):
    cType = cType.replace(" *const", " *").replace("*const", "*")

  # Strip class prefix
  if cType.startsWith("class "):
    cType = cType[5..^1].strip()

  # Handle const prefix
  while cType.startsWith("const "):
    cType = cType[5..^1].strip()
    isConst = true
    isVar = false

  # Handle rvalue references (&&) - treat as pass by value
  if cType.endsWith("&&"):
    cType = cType[0..^3].strip()
    isVar = false
  # Handle lvalue references (&) - treat as var
  elif cType.endsWith("&"):
    cType = cType[0..^2].strip()
    # isVar stays true
  else:
    isVar = false

  cType = cType.strip()

  # Check basic type mapping
  if cType in BasicTypeMap:
    result = BasicTypeMap[cType]
    if isVar and not isConst:
      result = "var " & result
    return result

  # Handle char* with const/var
  if cType == "char *":
    if isVar:
      return "cstring"
    return if isConst: "ccstring" else: "cstring"

  # Strip enum/struct prefixes
  cType = cType.replace("enum ", "")
  cType = cType.replace("struct ", "")

  # Handle function pointers
  if ")*" in cType:
    return getNimProcType(cType, rename, isConst)

  # Handle template types with namespaces (xxxx::yyyy<zzzzz>)
  if "::" in cType:
    var matches: array[3, string]
    if cType.match(templatePattern, matches):
      let rawBase = matches[0].strip()
      let isPtr = rawBase.endsWith("*")
      let base = rawBase.strip(chars = {'*'})
      let baseName = base.split("::")[^1].strip().strip(chars = {'*'})
      # Check for utility types early - before template processing
      if baseName == "Span" or baseName == "span":
        return "pointer"
      if baseName == "function":
        return "pointer"
      if baseName == "string_view":
        return "cstring"
      if baseName == "string" or baseName == "basic_string":
        return "cstring"
      if baseName == "pair":
        return "pointer"  # std::pair simplified to pointer
      let templateParams = matches[1]
      result = baseName

      # Check for rename - if base is a typedef alias, use the alias directly
      var isTypedefAlias = false
      for somename, renamed in rename:
        # Check full name, or short name matches
        if somename.endsWith(base) or somename == base or somename == baseName:
          result = renamed
          isTypedefAlias = true
          break

      # Handle pointers (from original type)
      if isPtr:
        result = "ptr " & result

      # Handle template parameters - but NOT if this is a typedef alias
      # (typedef aliases like Vec3f are already concrete instantiations)
      if templateParams.len > 0 and not isTypedefAlias:
        var params = templateParams.split(", ")
        # Filter out empty params and convert
        var nimParams: seq[string]
        for p in params:
          let stripped = p.strip()
          if stripped.len > 0:
            var nimParam = getNimType(stripped, rename)
            if nimParam.endsWith("*"):
              nimParam = "ptr " & nimParam[0..^2].strip()
            nimParams.add(nimParam)
        if nimParams.len > 0:
          let paramsStr = nimParams.join(",")
          result = result & "[" & paramsStr & "]"

      # Result is already fully processed (namespace stripped, template converted to [])
      # Don't recursively call getNimType - that would misinterpret Foo[Bar] as a C array
      cType = result

      if isVar and not isConst:
        cType = "var " & cType

      if returnType and isConst:
        if cType.startsWith("ptr "):
          return "ConstPtr[" & cType[4..^1] & "]"

      return cType

  # Map std:: and Ray:: utility types to simpler equivalents BEFORE template conversion
  if cType.startsWith("Span<") or cType.startsWith("Ray::Span<"):
    return "pointer"
  if cType.startsWith("std::function<") or cType.startsWith("function<"):
    return "pointer"
  if cType.startsWith("std::pair<") or cType.startsWith("pair<"):
    return "pointer"
  if cType == "string_view" or cType == "std::string_view":
    return "cstring"
  # Handle std::string and basic_string
  if cType == "string" or cType == "std::string":
    return "cstring"
  if cType.startsWith("basic_string") or cType.startsWith("std::basic_string"):
    return "cstring"

  # Handle simple templates (no namespace prefix)
  if "<" in cType and ">" in cType:
    let ltPos = cType.find('<')
    let gtPos = cType.rfind('>')
    if ltPos > 0 and gtPos > ltPos:
      let baseName = cType[0..<ltPos].strip()
      let templateParams = cType[ltPos+1..<gtPos]
      var nimParams: seq[string]
      for p in templateParams.split(","):
        let stripped = p.strip()
        if stripped.len > 0:
          nimParams.add(getNimType(stripped, rename))
      if nimParams.len > 0:
        cType = baseName & "[" & nimParams.join(",") & "]"
      else:
        cType = baseName

  cType = cType.strip()

  # Handle pointers
  if cType.len > 0:
    while cType.endsWith("*"):
      var inner = cType[0..^2]
      inner = getNimType(inner, rename)
      cType = "ptr " & inner

  # Final type fixups
  if cType.startsWith("ptr float"):
    cType = "ptr cfloat"
  if cType.startsWith("ptr Char"):
    cType = "cstring"
  if cType.startsWith("ptr void"):
    cType = "pointer"
  if cType.startsWith("ptr ptr void"):
    cType = "ptr pointer"
  if cType.contains("const "):
    # Remove stray const in type params
    cType = cType.replace("const ", "")

  # Handle const return type
  if returnType and isConst:
    if cType.startsWith("ptr "):
      var innerType = cType[4..^1]
      # Apply rename to inner type if applicable
      if innerType in rename:
        innerType = rename[innerType]
      return "ConstPtr[" & innerType & "]"

  # Handle var modifier (avoid var var duplication)
  if isVar and not isConst:
    if not cType.startsWith("var "):
      cType = "var " & cType

  # Check for reverse typedef alias mapping (e.g., "color_t[cfloat,4]" -> "color_rgba_t")
  var baseType = cType
  if baseType.startsWith("var "):
    baseType = baseType[4..^1]
  if baseType in rename:
    let aliased = rename[baseType]
    if isVar and not isConst:
      result = "var " & aliased
    else:
      result = aliased
  else:
    result = cType


proc getNimArrayType*(cType: string, rename: Table[string, string]): string =
  ## Convert a C++ array type to Nim.
  let mo = cType.match(re"(.*)\[\s*(\w*)\s*\]")
  if not mo:
    return cType

  var matches: array[3, string]
  discard cType.match(re"(.*)\[\s*(\w*)\s*\]", matches)
  let etype = matches[0].strip()
  let count = matches[1]

  if count == "":
    return "ptr " & getNimType(etype, rename)

  # Check if count is a number or a template parameter
  var isNumeric = true
  for c in count:
    if c notin '0'..'9':
      isNumeric = false
      break

  if isNumeric:
    return "array[" & count & "," & getNimType(etype, rename) & "]"
  else:
    # Template parameter - use it directly as the size
    return "array[" & count & ", " & getNimType(etype, rename) & "]"


proc getNimProcType*(cType: string, rename: Table[string, string], isConst: bool = false): string =
  ## Convert a C++ function pointer type to Nim proc type.
  var matches: array[3, string]
  if not cType.match(re"(.*)\s*\((.*)\)\s*\*", matches):
    return cType

  var rtype = matches[0]
  let inner = matches[1]
  result = "proc("
  var count = 0

  if inner.len > 0:
    for x in inner.split(","):
      if count > 0:
        result.add(",")
      result.add("arg_" & $count & ":" & getNimType(x.strip(), rename, returnType=true))
      inc count

  if rtype.strip() != "void":
    if isConst:
      rtype = "const " & rtype
    result.add("):" & getNimType(rtype.strip(), rename, returnType=true) & "{.cdecl}")
  else:
    result.add("){.cdecl}")


type
  TypeConverter* = object
    ## Type converter with configuration support.
    rename*: Table[string, string]

proc initTypeConverter*(rename: Table[string, string] = initTable[string, string]()): TypeConverter =
  TypeConverter(rename: rename)

proc toNim*(tc: TypeConverter, cType: string, returnType: bool = false): string =
  getNimType(cType, tc.rename, returnType)

proc addRename*(tc: var TypeConverter, cppName, nimName: string) =
  tc.rename[cppName] = nimName


type
  NimCodeGenerator* = object
    ## Generate Nim bindings from analyzed C++ headers.
    config*: Config
    rename*: Table[string, string]
    typeConverter*: TypeConverter
    baseClasses*: HashSet[string]  ## Classes used as base classes (need of RootObj)
    ignoreTypes*: HashSet[string]  ## Types to skip during generation


proc initNimCodeGenerator*(config: Config = defaultConfig(),
                           rename: Table[string, string] = initTable[string, string](),
                           baseClasses: HashSet[string] = initHashSet[string](),
                           ignoreTypes: seq[string] = @[]): NimCodeGenerator =
  var ignoreSet: HashSet[string]
  for t in ignoreTypes:
    ignoreSet.incl(t)
  for t in config.ignoreTypes:
    ignoreSet.incl(t)
  NimCodeGenerator(
    config: config,
    rename: rename,
    typeConverter: initTypeConverter(rename),
    baseClasses: baseClasses,
    ignoreTypes: ignoreSet
  )

proc shouldIgnoreType*(gen: NimCodeGenerator, typeName: string): bool =
  ## Check if a type should be ignored based on config.
  ## Only matches the BASE type, not template arguments.
  ## e.g., "VulkanDevice" matches "VulkanDevice" or "Ray::VulkanDevice"
  ## but "Span<const float>" does NOT match even if "Span" is in ignoreTypes
  ## because we want to convert Span<T> to pointer, not skip the field.
  ##
  ## Types that can be CONVERTED (like Span, Bitmask) are not filtered -
  ## only types that have NO CONVERSION should trigger ignore.
  var baseType = typeName.strip()

  # Strip pointer/reference qualifiers and const
  baseType = baseType.replace("const", "")
  baseType = baseType.replace("*", "")
  baseType = baseType.replace("&", "")
  baseType = baseType.replace("  ", " ")  # collapse double spaces
  baseType = baseType.strip()

  # Extract base type before template parameters
  let ltIdx = baseType.find('<')
  if ltIdx > 0:
    baseType = baseType[0..<ltIdx].strip()

  # Strip namespace prefixes (e.g., "Ray::VulkanDevice" -> "VulkanDevice")
  let lastColon = baseType.rfind("::")
  if lastColon >= 0:
    baseType = baseType[lastColon + 2 .. ^1]

  # Types that have conversions - don't skip them
  const convertibleTypes = ["Span", "span", "Bitmask", "function", "string_view", "pair"]
  if baseType in convertibleTypes:
    return false

  # Check exact match with ignore list
  for ignored in gen.ignoreTypes:
    if baseType == ignored:
      return true
  false


proc generateParams*(gen: NimCodeGenerator, params: seq[Parameter]): string =
  ## Generate Nim parameter list.
  var parts: seq[string]
  for i, param in params:
    var name = if param.name.len > 0: param.name else: "a" & align($i, 2, '0')
    name = cleanIdentifier(name)

    var typeStr = getNimType(param.typeName, gen.rename)

    if param.defaultValue.isSome and not typeStr.startsWith("array"):
      var default = param.defaultValue.get
      if default != "nil" and not default.startsWith("{"):
        if typeStr.endsWith("Enum") and default != "nil":
          default = typeStr & "." & default
        default = default.replace("|", " or ")
        default = default.replace("||", " or ")
        default = default.replace("&", " and ")
        default = default.replace("&&", " and ")
        typeStr = typeStr & " = " & default

    parts.add(name & ": " & typeStr)

  result = parts.join(", ")


proc generateParamsForConstructor*(gen: NimCodeGenerator, params: seq[Parameter]): seq[tuple[param: string, hasDefault: bool]] =
  ## Generate constructor parameters with default value tracking.
  for i, param in params:
    var name = if param.name.len > 0: param.name else: "a" & align($i, 2, '0')
    name = cleanIdentifier(name)

    let typeStr = getNimType(param.typeName, gen.rename)
    let hasDefault = param.defaultValue.isSome

    let prefix = if i > 0: ", " else: ""
    result.add((prefix & name & ": " & typeStr, hasDefault))


proc generateEnum*(gen: NimCodeGenerator, enumDecl: EnumDecl, incl: string = ""): string =
  ## Generate Nim enum declaration.
  var name = gen.rename.getOrDefault(enumDecl.fullyQualified, enumDecl.name.split("::")[ ^1])
  name = cleanIdentifier(name)

  let includePragma = if incl.len > 0: "header: \"" & incl & "\", " else: ""
  let typeSize = getNimType(enumDecl.underlyingType, gen.rename)
  let typePragma = "size:sizeof(" & typeSize & ")"

  # Sort items by value
  var items = enumDecl.items.sorted(proc(a, b: EnumItem): int = cmp(a.value, b.value))

  var itemsTxt = ""
  for i, item in items:
    var itemName = item.name
    # Fix identifiers starting with underscore (invalid in Nim)
    if itemName.startsWith("_"):
      itemName = "x" & itemName
    itemsTxt.add("    " & itemName & " = " & $item.value)
    if i < items.len - 1:
      itemsTxt.add(",")
    itemsTxt.add("\n")
    if item.comment.isSome:
      itemsTxt.add(formatComment(item.comment, 6))

  result = "  " & name & "* {.size:sizeof(" & typeSize & "), " & includePragma & "importcpp: \"" & enumDecl.fullyQualified & "\", pure.} = enum\n"
  if enumDecl.comment.isSome:
    result.add(formatComment(enumDecl.comment) & "\n")
  result.add(itemsTxt & "\n")


proc generateStruct*(gen: NimCodeGenerator, struct: StructDecl, incl: string = "",
                     inheritable: bool = false, nofield: bool = false): string =
  ## Generate Nim struct/object declaration.
  # Skip anonymous structs/unions
  if struct.name.len == 0 or struct.name.startsWith("(anonymous"):
    return ""

  let shortName = struct.name.split("::")[ ^1]
  # Check both fullyQualified and short name in rename table
  var name = if struct.fullyQualified in gen.rename:
               gen.rename[struct.fullyQualified]
             elif shortName in gen.rename:
               gen.rename[shortName]
             else:
               shortName
  name = cleanIdentifier(name)

  let includePragma = if incl.len > 0: "header: \"" & incl & "\", " else: ""
  let unionPragma = if struct.isUnion: "union, " else: ""
  let inheritablePragma = if inheritable: "inheritable, " else: ""
  let incompletePragma = if struct.isIncomplete: "incompleteStruct, " else: ""

  # Build template parameter string if this is a template struct
  var templateStr = ""
  var templateParamNames: seq[string]
  if struct.templateParams.len > 0:
    var params: seq[string]
    for p in struct.templateParams:
      templateParamNames.add(p.name)
      if p.typeName.isSome:
        # Non-type parameter (e.g., int N)
        params.add(p.name & ": static " & getNimType(p.typeName.get, gen.rename))
      else:
        # Type parameter
        params.add(p.name)
    templateStr = "[" & params.join("; ") & "]"

  var inheritance = ""
  if struct.baseTypes.len > 0:
    let base = getNimType(struct.baseTypes[0], gen.rename)
    inheritance = " of " & base
  # Only add RootObj for types explicitly marked as base classes
  # POD structs should NOT have RootObj - it breaks C++ interop
  elif struct.name in gen.baseClasses or struct.fullyQualified in gen.baseClasses:
    inheritance = " of RootObj"

  result = "  " & name & "*" & templateStr & " {." & inheritablePragma & unionPragma & includePragma & incompletePragma & "importcpp: \"" & struct.fullyQualified & "\".} = object" & inheritance & "\n"

  # Skip fields for incomplete template structs - they use template params that
  # can't be resolved and these structs are used as opaque types anyway
  if struct.isIncomplete and struct.templateParams.len > 0:
    return

  if not nofield:
    for field in struct.fields:
      var fname = field.name
      if fname.len == 0 or fname.startsWith("_"):
        continue
      if field.typeName.startsWith("struct "):
        continue
      # Skip fields with ignored types
      if gen.shouldIgnoreType(field.typeName):
        continue

      fname = cleanIdentifier(fname)
      var tname = field.typeName

      # For template structs, check if field uses template params
      var usesTemplateParam = false
      for tp in templateParamNames:
        if tp in tname:
          usesTemplateParam = true
          break

      if usesTemplateParam:
        # Use the template parameter directly for fields
        tname = getNimType(tname, gen.rename)
      else:
        tname = getNimType(tname, gen.rename)

      if fname.endsWith("_"):
        result.add("    " & fname[0..^2] & "* {.importcpp:\"" & fname & "\".}: " & tname & "\n")
      else:
        result.add("    " & fname & "*: " & tname & "\n")

  if struct.comment.isSome:
    result.add(formatComment(struct.comment) & "\n")


proc generateClass*(gen: NimCodeGenerator, cls: ClassDecl, incl: string = "",
                    byref: bool = true, inheritable: bool = false, nofield: bool = false): string =
  ## Generate Nim class/object declaration.
  var name = gen.rename.getOrDefault(cls.fullyQualified, cls.fullyQualified.split("::")[ ^1])
  name = cleanIdentifier(name)

  let includePragma = if incl.len > 0: "header: \"" & incl & "\", " else: ""
  let byrefPragma = if byref: ", byref" else: ", bycopy"
  let inheritablePragma = if inheritable: "inheritable, " else: ""

  # Check if this class is a base class (used by other classes)
  let isBaseClass = cls.fullyQualified in gen.baseClasses or
                    cls.name in gen.baseClasses or
                    name in gen.baseClasses

  var inheritance = ""
  if cls.baseTypes.len > 0:
    let base = getNimType(cls.baseTypes[0], gen.rename)
    inheritance = " of " & base
  elif isBaseClass:
    # Base classes need of RootObj for derived classes to inherit
    inheritance = " of RootObj"

  var templateStr = ""
  if cls.templateParams.len > 0:
    var params: seq[string]
    for p in cls.templateParams:
      if p.typeName.isSome:
        params.add(p.name & ":" & getNimType(p.typeName.get, gen.rename))
      else:
        params.add(p.name)
    templateStr = "[" & params.join("; ") & "]"

  result = "  " & name & "*" & templateStr & " {." & inheritablePragma & includePragma & "importcpp: \"" & cls.fullyQualified & "\"" & byrefPragma & ".} = object" & inheritance & "\n"

  if not nofield:
    for field in cls.fields:
      var fname = field.name
      if fname.len == 0 or fname.startsWith("_"):
        continue
      if field.typeName.startsWith("struct "):
        continue
      # Skip fields with ignored types
      if gen.shouldIgnoreType(field.typeName):
        continue

      fname = cleanIdentifier(fname)
      let tname = getNimType(field.typeName, gen.rename)

      if fname.endsWith("_"):
        result.add("    " & fname[0..^2] & "* {.importcpp:\"" & fname & "\".}: " & tname & "\n")
      else:
        result.add("    " & fname & "*: " & tname & "\n")

  if cls.comment.isSome:
    result.add(formatComment(cls.comment) & "\n")


proc generateConstructor*(gen: NimCodeGenerator, ctor: ConstructorDecl,
                          dupTracker: var Table[string, bool]): string =
  ## Generate Nim constructor proc.
  # Skip constructors with ignored types in parameters
  for param in ctor.params:
    if gen.shouldIgnoreType(param.typeName):
      return ""

  let paramParts = gen.generateParamsForConstructor(ctor.params)

  let classType = gen.rename.getOrDefault(ctor.fullyQualified, ctor.fullyQualified.split("::")[ ^1])
  let (methodName, templateParams) = getTemplateParameters(ctor.name)

  if paramParts.len == 0:
    # No-arg constructor
    let p = "proc new" & methodName & "*" & templateParams & "(): " & classType & " {.constructor,importcpp: \"" & ctor.fullyQualified & "\".}\n"
    result = p
    if ctor.comment.isSome:
      result.add(formatComment(ctor.comment) & "\n")
  else:
    # Generate overloads for default parameters
    let n = paramParts.len
    var added = false

    for r in countdown(n - 1, 0):
      var params = ""
      for i in 0..r:
        params.add(paramParts[i].param)
      let p = "proc new" & methodName & "*" & templateParams & "(" & params & "): " & classType & " {.constructor,importcpp: \"" & ctor.fullyQualified & "(@)\".}\n"

      if p notin dupTracker:
        dupTracker[p] = true
        result.add(p)
        added = true

      # Stop if this param doesn't have a default
      if not paramParts[r].hasDefault:
        break

    if added and ctor.comment.isSome:
      result.add(formatComment(ctor.comment) & "\n")


proc detectTemplateParams(signature: string): seq[string] =
  ## Detect single-letter template parameters (T, U, V, etc.) in a type signature.
  ## Returns list of template params found.
  var found: HashSet[string]
  # Common template parameter names
  const templateParamNames = ["T", "U", "V", "K", "N", "M", "S", "R", "E", "A", "B", "C", "D"]
  for param in templateParamNames:
    # Look for standalone param: " T", ": T", "[T", ",T", "<T" or just "T" at word boundaries
    if (" " & param) in signature or (":" & param) in signature or
       ("[" & param) in signature or ("," & param) in signature or
       (signature == param) or signature.endsWith(" " & param) or
       signature.endsWith(":" & param):
      found.incl(param)
  result = found.toSeq.sorted

proc generateMethod*(gen: NimCodeGenerator, meth: MethodDecl,
                     visited: var HashSet[string], varargs: seq[string] = @[]): string =
  ## Generate Nim method/proc declaration.
  # Skip methods with ignored types in parameters or return type
  for param in meth.params:
    if gen.shouldIgnoreType(param.typeName):
      return ""
  if gen.shouldIgnoreType(meth.returnType):
    return ""

  # Method name (lowercase first letter)
  var methodName = meth.name
  if methodName.len > 0:
    methodName = methodName[0].toLowerAscii() & methodName[1..^1]

  # Handle varargs
  var params = meth.params
  var hasValist = false
  if params.len > 0 and params[^1].typeName == "va_list":
    hasValist = true
    params = params[0..^2]

  var paramsStr = gen.generateParams(params)

  # Apply rename to class name for self parameter
  var selfClassName = meth.className
  # Check for fully qualified rename first (from fullyQualified path)
  let fullyQualifiedClass = if meth.fullyQualified.len > 0:
                              meth.fullyQualified.rsplit("::", 1)[0]
                            else:
                              ""
  if fullyQualifiedClass.len > 0 and fullyQualifiedClass in gen.rename:
    selfClassName = gen.rename[fullyQualifiedClass]
  elif meth.className in gen.rename:
    selfClassName = gen.rename[meth.className]
  else:
    # Try all rename entries that end with ::className
    for key, value in gen.rename.pairs:
      if key.endsWith("::" & meth.className):
        selfClassName = value
        break
  let className = "ptr " & selfClassName

  var importMethod: string
  var importName: string

  if not meth.isPlainFunction:
    importMethod = "importcpp"
    if meth.isStatic:
      # Static method: no self param, use fully qualified call
      importName = meth.className & "::" & meth.name & "(@)"
    else:
      # Instance method: add self param
      importName = meth.name
      if paramsStr.len > 0:
        paramsStr = "self: " & className & ", " & paramsStr
      else:
        paramsStr = "self: " & className
  else:
    importName = meth.fullyQualified
    importMethod = "importc"

  let isVararg = hasValist or (importName in varargs)

  # Return type
  var returnStr = ""
  if meth.returnType.len > 0 and meth.returnType != "void":
    var resultType = meth.returnType.strip()
    let isRef = resultType.endsWith("&")
    if isRef:
      resultType = resultType[0..^2].strip()
    resultType = getNimType(resultType, gen.rename, returnType = true)
    if isRef:
      resultType = "var " & resultType
      importMethod = "importcpp"
    returnStr = ": " & resultType

  # Handle operators
  var isOperator = false
  if importName.startsWith("`") and importName.endsWith("`"):
    importName = importName[1..^2]
    importName = "# " & importName & " #"
    isOperator = true

  var pragmas = ""
  if isVararg:
    pragmas.add(", varargs")

  methodName = cleanIdentifier(methodName)

  # Detect template parameters from the signature
  let fullSig = paramsStr & " " & returnStr
  let templateParams = detectTemplateParams(fullSig)
  var templateStr = ""
  if templateParams.len > 0:
    templateStr = "[" & templateParams.join(", ") & "]"

  # Generate proc
  var p: string
  if isOperator and methodName in ["`=`"]:
    p = "proc assign*" & templateStr & "(" & paramsStr & ") {." & importMethod & ": \"" & importName & "\"" & pragmas & ".}\n"
  elif isOperator and methodName in ["`[]`"]:
    importName = "#[#]"
    p = "proc " & methodName & "*" & templateStr & "(" & paramsStr & ")" & returnStr & " {." & importMethod & ": \"" & importName & "\"" & pragmas & ".}\n"
  elif isOperator and methodName in ["`()`"]:
    return ""  # Skip function call operator
  else:
    p = "proc " & methodName & "*" & templateStr & "(" & paramsStr & ")" & returnStr & " {." & importMethod & ": \"" & importName & "\"" & pragmas & ".}\n"

  if p in visited:
    return ""
  visited.incl(p)

  result = p
  if meth.comment.isSome:
    result.add(formatComment(meth.comment) & "\n")


proc generateTypedef*(gen: NimCodeGenerator, typedef: TypedefDecl, incl: string = ""): string =
  ## Generate Nim typedef.
  if typedef.typedefKind.isSome:
    if typedef.typedefKind.get == "struct" and typedef.structData.isSome:
      var structData = typedef.structData.get
      # For template type aliases (e.g., using IntPoint = Point<int>),
      # the struct_data is incomplete - generate a type alias instead
      if structData.isIncomplete and "<" in typedef.underlying:
        # This is a template instantiation alias - generate type alias
        # IMPORTANT: Don't use gen.rename here to avoid self-reference
        # (the rename table maps Point[int] -> IntPoint, which would cause IntPoint = IntPoint)
        let underlying = typedef.underlying
        let nimType = getNimType(underlying, initTable[string, string]())  # No renames!
        let includePragma = if incl.len > 0: "header: \"" & incl & "\", " else: ""
        let name = cleanIdentifier(typedef.name)
        return "  " & name & "* {." & includePragma & "importcpp: \"" & typedef.fullyQualified & "\".} = " & nimType & "\n"
      elif structData.name.len == 0:
        # For anonymous typedef structs, use the typedef name
        structData.name = typedef.name
        structData.fullyQualified = typedef.fullyQualified
        return gen.generateStruct(structData, incl)
      else:
        # Regular struct typedef
        return gen.generateStruct(structData, incl)

    if typedef.typedefKind.get == "enum" and typedef.enumData.isSome:
      return gen.generateEnum(typedef.enumData.get, incl)

  let underlying = typedef.underlying
  let nimType = getNimType(underlying, gen.rename)

  let includePragma = if incl.len > 0: "header: \"" & incl & "\", " else: ""
  let name = cleanIdentifier(typedef.name)

  if typedef.typedefKind.isSome and typedef.typedefKind.get == "function":
    var returnStr = ""
    if typedef.resultType.isSome and typedef.resultType.get != "void":
      var resultType = typedef.resultType.get.strip()
      if resultType.endsWith("&"):
        resultType = resultType[0..^2].strip()
      resultType = getNimType(resultType, gen.rename)
      returnStr = ": " & resultType

    let paramsStr = gen.generateParams(typedef.params)
    let procType = "proc (" & paramsStr & ")" & returnStr & " {.cdecl.}"

    return "  " & name & "* {." & includePragma & "importcpp: \"" & typedef.fullyQualified & "\".} = " & procType & "\n"
  else:
    var nt = nimType
    if nt.startsWith("struct "):
      nt = nt[7..^1]

    if name == nt:  # Avoid self-reference
      return ""

    return "  " & name & "* {." & includePragma & "importcpp: \"" & typedef.fullyQualified & "\".} = " & nt & "\n"


proc generateConst*(gen: NimCodeGenerator, enumDecl: EnumDecl): string =
  ## Generate Nim const values from anonymous enum.
  for item in enumDecl.items:
    result.add("  " & item.name & "* = " & $item.value & "\n")
    if item.comment.isSome:
      result.add(formatComment(item.comment) & "\n")


# Legacy format functions for backward compatibility

proc getConstructor*(data: ConstructorDecl, rename: Table[string, string] = initTable[string, string](),
                     dup: var Table[string, bool]): string =
  let gen = initNimCodeGenerator(rename = rename)
  gen.generateConstructor(data, dup)


proc getMethod*(data: MethodDecl, rename: Table[string, string] = initTable[string, string](),
                visited: var HashSet[string], varargs: seq[string] = @[]): string =
  let gen = initNimCodeGenerator(rename = rename)
  gen.generateMethod(data, visited, varargs)


proc getTypedef*(typedef: TypedefDecl, incl: string = "",
                 rename: Table[string, string] = initTable[string, string]()): string =
  let gen = initNimCodeGenerator(rename = rename)
  gen.generateTypedef(typedef, incl)


proc getClass*(cls: ClassDecl, incl: string = "", byref: bool = true,
               rename: Table[string, string] = initTable[string, string](),
               inheritable: bool = false, nofield: bool = false): string =
  let gen = initNimCodeGenerator(rename = rename)
  gen.generateClass(cls, incl, byref, inheritable, nofield)


proc getStruct*(struct: StructDecl, incl: string = "",
                rename: Table[string, string] = initTable[string, string](),
                inheritable: bool = false, nofield: bool = false): string =
  let gen = initNimCodeGenerator(rename = rename)
  gen.generateStruct(struct, incl, inheritable, nofield)


proc getEnum*(enumDecl: EnumDecl, incl: string = "",
              rename: Table[string, string] = initTable[string, string]()): string =
  let gen = initNimCodeGenerator(rename = rename)
  gen.generateEnum(enumDecl, incl)


proc getConst*(enumDecl: EnumDecl): string =
  let gen = initNimCodeGenerator()
  gen.generateConst(enumDecl)
