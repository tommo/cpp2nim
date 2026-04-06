## Utility functions for cpp2nim.
##
## Ported from Python utils.py - provides keyword escaping, identifier cleaning,
## type name resolution, template parsing, and formatting utilities.

import std/[strutils, sequtils, sets, options, wordwrap]

const
  NimKeywords* = [
    "addr", "and", "as", "asm", "bind", "block", "break",
    "case", "cast", "concept", "const", "continue", "converter",
    "defer", "discard", "distinct", "div", "do", "elif", "else",
    "end", "enum", "except", "export", "finally", "for", "from",
    "func", "if", "import", "in", "include", "interface", "is",
    "isnot", "iterator", "let", "macro", "method", "mixin", "mod",
    "nil", "not", "notin", "object", "of", "or", "out", "proc", "ptr",
    "raise", "ref", "return", "shl", "shr", "static", "template",
    "try", "tuple", "type", "using", "var", "when", "while", "xor",
    "yield", "array"
  ].toHashSet

  NormalTypes* = [
    "void", "long", "unsigned long", "int", "size_t", "long long", "long double",
    "float", "double", "char", "signed char", "unsigned char", "unsigned short",
    "unsigned int", "unsigned long long", "char*", "bool"
  ].toHashSet


proc escapeNimKeyword*(name: string): string =
  ## Escape a name if it's a Nim keyword.
  ##
  ## Returns the name with backticks if it's a keyword, otherwise unchanged.
  ##
  ## Example:
  ##   escapeNimKeyword("type") => "`type`"
  ##   escapeNimKeyword("myVar") => "myVar"
  if name in NimKeywords:
    result = "`" & name & "`"
  else:
    result = name


proc cleanIdentifier*(name: string): string =
  ## Clean an identifier for Nim output.
  ##
  ## Handles leading/trailing underscores and keyword escaping.
  ## Nim doesn't allow trailing underscores in identifiers.
  ##
  ## Example:
  ##   cleanIdentifier("_internal") => "v_internal"
  ##   cleanIdentifier("type") => "`type`"
  ##   cleanIdentifier("mjData_") => "mjData"
  if name.len == 0:
    return name
  var n = name
  # Strip trailing underscores (not allowed in Nim)
  while n.len > 1 and n.endsWith("_"):
    n = n[0..^2]
  if n.startsWith("_"):
    n = "v_" & n[1..^1]
  result = escapeNimKeyword(n)


proc cleanTypeName*(typeName: string): string =
  ## Remove const qualifiers and clean a C++ type name.
  ##
  ## Example:
  ##   cleanTypeName("const int &") => "int"
  ##   cleanTypeName("const char *") => "char"
  ##   cleanTypeName("const ldtk::Layer*const") => "ldtk::Layer"
  result = typeName
  # Handle trailing *const (e.g., "Type*const" or "const Type*const")
  if result.endsWith("*const"):
    result = result[0..^7]  # Remove "*const"
  # Handle trailing const* (e.g., "const Type const*")
  if result.endsWith("const *"):
    result = result[0..^8] & "*"
  # Remove leading const
  if result.startsWith("const "):
    result = result[6..^1]
  # Remove trailing & or * (and preceding space if any)
  while result.len > 0 and result[^1] in {'&', '*', ' '}:
    result = result[0..^2]
  # Remove C struct/union/enum tag prefixes
  if result.startsWith("struct "):
    result = result[7..^1]
  elif result.startsWith("union "):
    result = result[6..^1]
  elif result.startsWith("enum "):
    result = result[5..^1]
  result = result.strip()


proc getTemplateDependencies*(typeName: string): seq[string] =
  ## Extract template parameter dependencies from a type.
  ##
  ## Example:
  ##   getTemplateDependencies("std::vector<MyClass>") => @["std::vector", "MyClass"]
  ##   getTemplateDependencies("std::map<K, V>") => @["std::map", "K", "V"]
  ##   getTemplateDependencies("mjSolverStat[4000]") => @["mjSolverStat"]
  let cleaned = cleanTypeName(typeName)

  # Handle C++ templates (type<params>)
  if '<' in cleaned and cleaned.endsWith(">"):
    let idx = cleaned.find('<')
    let base = cleaned[0..<idx].strip()
    let params = cleaned[idx+1..^2]  # Remove < and >

    result.add(base)

    var depth = 0
    var currentParam: string
    for c in params:
      case c
      of '<':
        inc depth
        currentParam.add(c)
      of '>':
        dec depth
        currentParam.add(c)
      of ',':
        if depth == 0:
          let param = currentParam.strip()
          if param.len > 0:
            result.add(getTemplateDependencies(param))
          currentParam = ""
        else:
          currentParam.add(c)
      else:
        currentParam.add(c)

    # Add last parameter
    let param = currentParam.strip()
    if param.len > 0:
      result.add(getTemplateDependencies(param))
  # Handle C arrays (type[N] or type[])
  elif '[' in cleaned and cleaned.endsWith("]"):
    let idx = cleaned.find('[')
    let base = cleaned[0..<idx].strip()
    if base.len > 0:
      result.add(getTemplateDependencies(base))
  else:
    result.add(cleaned)

  # Filter out empty strings and digits
  result = result.filterIt(it.len > 0 and not it.allIt(it in '0'..'9'))


proc flattenNamespace*(name: string): string =
  ## Convert NS1::NS2::Name to NS2_Name.
  ##
  ## Takes last two components if available.
  ##
  ## Example:
  ##   flattenNamespace("std::vector") => "std_vector"
  ##   flattenNamespace("boost::asio::ip::tcp") => "ip_tcp"
  if name.len == 0 or "::" notin name:
    return name

  let parts = name.split("::")
  if parts.len >= 2:
    result = parts[^2] & "_" & parts[^1]
  else:
    result = parts[^1]


proc getTemplateParameters*(methodName: string): tuple[name: string, params: string] =
  ## Extract template parameters from a method name.
  ##
  ## Example:
  ##   getTemplateParameters("push_back<T>") => ("push_back", "[T]")
  ##   getTemplateParameters("foo") => ("foo", "")
  if '<' in methodName and methodName.endsWith(">"):
    let idx = methodName.find('<')
    let name = methodName[0..<idx]
    let params = methodName[idx+1..^2]  # Remove < and >
    result = (name, "[" & params & "]")
  else:
    result = (methodName, "")


proc formatComment*(comment: Option[string], indent: int = 4): string =
  ## Format a comment for Nim output.
  ##
  ## Example:
  ##   formatComment(some("This is a function"), 4) => "    ## This is a function\n"
  if comment.isNone or comment.get.len == 0:
    return ""

  let spc = ' '.repeat(indent)
  let wrapped = wrapWords(comment.get, maxLineWidth = 70)
  for line in wrapped.splitLines():
    result.add(spc & "## " & line & "\n")


proc formatCommentStr*(comment: string, indent: int = 4): string =
  ## Format a comment string for Nim output (non-Option variant).
  if comment.len == 0:
    return ""
  formatComment(some(comment), indent)


proc getRootFromGlob*(pattern: string): string =
  ## Get the root directory from a glob pattern.
  ##
  ## Example:
  ##   getRootFromGlob("/usr/include/*.h") => "/usr/include/"
  ##   getRootFromGlob("/path/to/file.h") => "/path/to/"
  if "*" notin pattern and "?" notin pattern:
    let parts = pattern.split("/")
    return parts[0..^2].join("/") & "/"

  let parts = pattern.split("/")
  for part in parts:
    if "*" in part or "?" in part:
      break
    result.add(part & "/")


proc flattenList*[T](nested: seq[T]): seq[T] =
  ## Flatten a nested list structure (for compatibility).
  ## In Nim, sequences are homogeneous so this just returns the input.
  result = nested


# Clang-specific utilities are not ported as they require libclang bindings.
# get_fully_qualified_name() and get_fully_qualified_type() depend on Clang cursors.
# These will be handled in the parser module with proper Clang FFI.
