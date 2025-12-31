## C++ to Nim type conversion.
##
## This module handles the conversion of C++ type names to their Nim equivalents.

import std/[strutils, tables, options]

const
  BasicTypeMap* = {
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
    "std::size_t": "csize_t",
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
  }.toTable


proc normalizePtrType*(cType: string): string =
  ## Normalize pointer type spacing.
  ##
  ## Returns normalized type string with consistent spacing.
  result = cType.strip()
  # Add space before * if preceded by word char (simple replacement)
  var i = 0
  var normalized = ""
  while i < result.len:
    if i > 0 and result[i] == '*' and result[i-1].isAlphaNumeric:
      normalized.add(" *")
    else:
      normalized.add(result[i])
    inc i
  result = normalized
  # Collapse multiple const
  while "const const " in result:
    result = result.replace("const const ", "const ")


proc getNimArrayType*(cType: string, rename: Table[string, string] = initTable[string, string]()): string

proc getNimProcType*(cType: string, rename: Table[string, string] = initTable[string, string](),
                     isConst: bool = false): string

proc getNimType*(cType: string, rename: Table[string, string] = initTable[string, string](),
                 returnType: bool = false): string


proc getNimArrayType*(cType: string, rename: Table[string, string] = initTable[string, string]()): string =
  ## Convert a C++ array type to Nim.
  ##
  ## Example:
  ##   getNimArrayType("int[10]") => "array[10,cint]"
  ##   getNimArrayType("char[]") => "ptr cchar"
  # Parse: type[count] or type[]
  let bracketIdx = cType.find('[')
  if bracketIdx < 0:
    return cType

  let closeBracket = cType.find(']', bracketIdx)
  if closeBracket < 0:
    return cType

  let etype = cType[0..<bracketIdx].strip()
  let count = cType[bracketIdx+1..<closeBracket].strip()

  if count == "":
    return "ptr " & getNimType(etype, rename)
  return "array[" & count & "," & getNimType(etype, rename) & "]"


proc getNimProcType*(cType: string, rename: Table[string, string] = initTable[string, string](),
                     isConst: bool = false): string =
  ## Convert a C++ function pointer type to Nim proc type.
  # Parse: returnType (params) *
  # Find the opening paren for params
  let parenOpen = cType.find('(')
  if parenOpen < 0:
    return cType

  let parenClose = cType.find(')', parenOpen)
  if parenClose < 0:
    return cType

  # Check for trailing *
  if not cType[parenClose..^1].contains('*'):
    return cType

  let rtype = cType[0..<parenOpen].strip()
  let inner = cType[parenOpen+1..<parenClose].strip()
  result = "proc("
  var count = 0

  if inner.len > 0:
    for x in inner.split(","):
      if count > 0:
        result.add(',')
      result.add("arg_" & $count & ":" & getNimType(x.strip(), rename, returnType = true))
      inc count

  if rtype != "void":
    var rtypeFixed = rtype
    if isConst:
      rtypeFixed = "const " & rtypeFixed
    result.add("):" & getNimType(rtypeFixed, rename, returnType = true) & "{.cdecl}")
  else:
    result.add("){.cdecl}")


proc getNimType*(cType: string, rename: Table[string, string] = initTable[string, string](),
                 returnType: bool = false): string =
  ## Convert a C++ type to its Nim equivalent.
  ##
  ## This is the main type conversion function that handles all C++ types
  ## including pointers, references, templates, arrays, and function pointers.
  ##
  ## Example:
  ##   getNimType("int") => "cint"
  ##   getNimType("const char *") => "ccstring"
  ##   getNimType("std::vector<int>") => "vector[cint]"
  var ct = normalizePtrType(cType)

  # Handle arrays first
  if ct.endsWith("]"):
    ct = getNimArrayType(ct, rename)

  var isVar = true
  var isConst = false

  # Special cases
  if ct == "const void *":
    return "ConstPointer"

  if ct == "const char *":
    return "ccstring"

  # Handle trailing const pointer
  if ct.endsWith("const *"):
    isConst = true
    ct = ct[0..^8] & "*"

  # Strip class prefix
  if ct.startsWith("class "):
    ct = ct[6..^1].strip()

  # Handle const prefix
  while ct.startsWith("const "):
    ct = ct[6..^1].strip()
    isConst = true
    isVar = false

  # Handle references
  if not ct.endsWith("&"):
    isVar = false
  else:
    ct = ct[0..^2]

  ct = ct.strip()

  # Check basic type mapping
  if ct in BasicTypeMap:
    result = BasicTypeMap[ct]
    if isVar and not isConst:
      result = "var " & result
    return result

  # Handle char* with const/var
  if ct == "char *":
    if isVar:
      return "cstring"
    return if isConst: "ccstring" else: "cstring"

  # Strip enum/struct prefixes
  ct = ct.replace("enum ", "")
  ct = ct.replace("struct ", "")

  # Handle function pointers
  if ")*" in ct:
    return getNimProcType(ct, rename, isConst)

  # Handle template types with namespaces (xxxx::yyyy<zzzzz>)
  if "::" in ct:
    var base: string
    var templateParams: string

    if '<' in ct:
      let ltIdx = ct.find('<')
      base = ct[0..<ltIdx]
      if ct.endsWith(">"):
        templateParams = ct[ltIdx+1..^2]
    else:
      base = ct

    var resultType = base.split("::")[^1]

    # Check for rename
    for somename, renamed in rename.pairs:
      if somename.endsWith(base):
        resultType = renamed
        break

    # Handle pointers
    while resultType.endsWith("*"):
      let inner = resultType[0..^2]
      resultType = "ptr " & inner

    # Handle template parameters
    if templateParams.len > 0:
      var params: seq[string]
      for p in templateParams.split(", "):
        var param = getNimType(p.strip(), rename)
        if param.endsWith("*"):
          param = "ptr " & param[0..^2].strip()
        params.add(param)
      let paramsStr = params.join(",")
      resultType = resultType & "[" & paramsStr & "]"

    ct = getNimType(resultType, rename, true)

    if isVar and not isConst:
      ct = "var " & ct

    if returnType and isConst:
      if ct.startsWith("ptr "):
        return "ConstPtr[" & ct[4..^1] & "]"

    return ct

  # Handle simple templates
  if "<" in ct and ">" in ct:
    ct = ct.replace("<", "[")
    ct = ct.replace(">", "]")

  ct = ct.strip()

  # Handle pointers
  if ct.len > 0:
    while ct.endsWith("*"):
      let inner = ct[0..^2]
      let innerNim = getNimType(inner, rename)
      ct = "ptr " & innerNim

  # Final type fixups
  if ct.startsWith("ptr float"):
    ct = "ptr cfloat"
  if ct.startsWith("ptr Char"):
    ct = "cstring"
  if ct.startsWith("ptr void"):
    ct = "pointer"
  if ct.startsWith("ptr ptr void"):
    ct = "ptr pointer"

  # Handle const return type
  if returnType and isConst:
    if ct.startsWith("ptr "):
      return "ConstPtr[" & ct[4..^1] & "]"

  # Handle var modifier
  if isVar and not isConst:
    ct = "var " & ct

  return ct


type
  TypeConverter* = object
    ## Type converter with configuration support.
    ##
    ## This wraps the type conversion functions with a specific configuration,
    ## making it easier to apply consistent renaming across a project.
    ##
    ## Example:
    ##   var converter = initTypeConverter({"MyType": "MyNimType"}.toTable)
    ##   echo converter.toNim("MyType*")  # => "ptr MyNimType"
    rename*: Table[string, string]


proc initTypeConverter*(rename: Table[string, string] = initTable[string, string]()): TypeConverter =
  ## Initialize a type converter with optional rename mapping.
  TypeConverter(rename: rename)


proc toNim*(tc: TypeConverter, cType: string, returnType: bool = false): string =
  ## Convert a C++ type to Nim.
  getNimType(cType, tc.rename, returnType)


proc addRename*(tc: var TypeConverter, cppName, nimName: string) =
  ## Add a type rename mapping.
  tc.rename[cppName] = nimName


# Convenience functions with Option support

proc toNimOpt*(tc: TypeConverter, cType: Option[string], returnType: bool = false): Option[string] =
  ## Convert a C++ type to Nim, handling Option.
  if cType.isSome:
    some(tc.toNim(cType.get, returnType))
  else:
    none(string)
