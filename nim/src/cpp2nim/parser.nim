## C++ header parser using libclang.
##
## Automatically detects libclang location on common platforms.
## Override with CPP2NIM_LIBCLANG_PATH environment variable if needed.

import std/[sets, tables, options, strutils, re, os, sequtils, logging]

# Compile-time libclang detection
const defaultLibclangPaths = [
  # macOS Command Line Tools
  "/Library/Developer/CommandLineTools/usr/lib",
  # macOS Xcode
  "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib",
  # Homebrew LLVM (Apple Silicon)
  "/opt/homebrew/opt/llvm/lib",
  # Homebrew LLVM (Intel)
  "/usr/local/opt/llvm/lib",
  # Linux common paths
  "/usr/lib/llvm-18/lib",
  "/usr/lib/llvm-17/lib",
  "/usr/lib/llvm-16/lib",
  "/usr/lib/llvm-15/lib",
  "/usr/lib/llvm-14/lib",
  "/usr/lib/x86_64-linux-gnu",
  "/usr/lib64",
  "/usr/lib",
]

proc findLibclangPath(): string {.compileTime.} =
  ## Find libclang at compile time.
  # Check environment variable first
  let envPath = getEnv("CPP2NIM_LIBCLANG_PATH")
  if envPath.len > 0:
    return envPath
  # Search common paths
  for path in defaultLibclangPaths:
    let dylibPath = path / "libclang.dylib"
    let soPath = path / "libclang.so"
    if fileExists(dylibPath) or fileExists(soPath):
      return path
  # Fallback - let linker figure it out
  return ""

const libclangPath* = findLibclangPath()

when libclangPath.len > 0:
  {.passL: "-L" & libclangPath & " -lclang -Wl,-rpath," & libclangPath.}
else:
  {.passL: "-lclang".}

import ./vendor/clang/clang

import ./models
import ./config
import ./utils

type
  ParserContext* = object
    ## Mutable state during a parse session.
    visitedEnums*: HashSet[cuint]
    visitedStructs*: HashSet[cuint]
    fileCache*: Table[string, seq[string]]

  CppHeaderParser* = object
    ## Parse C++ headers using libclang.
    config*: Config

proc initParserContext*(): ParserContext =
  ParserContext()

proc initCppHeaderParser*(config: Config = defaultConfig()): CppHeaderParser =
  CppHeaderParser(config: config)


proc toNimStr(cxStr: CXString): string =
  let cstr = getCString(cxStr)
  if cstr != nil:
    result = $cstr
  disposeString(cxStr)

# Forward declarations
proc getFullyQualifiedName(cursor: CXCursor): string
proc getFullyQualifiedType(cursorType: CXType): string

proc getFullyQualifiedName(cursor: CXCursor): string =
  ## Get the fully qualified name of a cursor (e.g., "ns::Class::member").
  if Cursor_isNull(cursor) != 0:
    return ""
  if cursor.kind == CXCursor_TranslationUnit:
    return ""
  if isInvalid(cursor.kind) != 0:
    return ""
  let spelling = toNimStr(getCursorSpelling(cursor))
  # Skip if spelling looks like a file path (contains . or /)
  if spelling.len > 0 and ('/' in spelling or spelling.endsWith(".h") or spelling.endsWith(".hpp")):
    return ""
  let parent = getCursorSemanticParent(cursor)
  # Prevent infinite recursion: if parent equals cursor, stop
  if equalCursors(parent, cursor) != 0:
    return spelling
  let parentName = getFullyQualifiedName(parent)
  if parentName.len > 0:
    result = parentName & "::" & spelling
  else:
    result = spelling

proc getFullyQualifiedType(cursorType: CXType): string =
  ## Get fully qualified name for a type, preserving templates, const, etc.
  let constStr = if isConstQualifiedType(cursorType) != 0: "const " else: ""

  case cursorType.kind
  of CXType_FunctionProto, CXType_FunctionNoProto:
    # Function type: returnType (params)
    let resultType = getResultType(cursorType)
    let returnStr = getFullyQualifiedType(resultType)
    var params: seq[string]
    let numArgs = getNumArgTypes(cursorType)
    for i in 0..<numArgs:
      let argType = getArgType(cursorType, cuint(i))
      params.add(getFullyQualifiedType(argType))
    return returnStr & " (" & params.join(", ") & ")*"
  of CXType_Pointer:
    let pointee = getPointeeType(cursorType)
    # Check if pointer to function - handle specially
    if pointee.kind == CXType_FunctionProto or pointee.kind == CXType_FunctionNoProto:
      let resultType = getResultType(pointee)
      let returnStr = getFullyQualifiedType(resultType)
      var params: seq[string]
      let numArgs = getNumArgTypes(pointee)
      for i in 0..<numArgs:
        let argType = getArgType(pointee, cuint(i))
        params.add(getFullyQualifiedType(argType))
      return returnStr & " (" & params.join(", ") & ")*"
    return getFullyQualifiedType(pointee) & "*" & constStr.strip()
  of CXType_LValueReference:
    let refType = getPointeeType(cursorType)
    return getFullyQualifiedType(refType) & "&" & constStr.strip()
  of CXType_ConstantArray, CXType_IncompleteArray:
    let elemType = getArrayElementType(cursorType)
    var arraySize = ""
    if cursorType.kind == CXType_ConstantArray:
      arraySize = $getArraySize(cursorType)
    return getFullyQualifiedType(elemType) & "[" & arraySize & "]" & constStr.strip()
  of CXType_Unexposed:
    let decl = getTypeDeclaration(cursorType)
    if decl.kind == CXCursor_ClassTemplate:
      let numArgs = Type_getNumTemplateArguments(cursorType)
      if numArgs > 0:
        var templateArgs: seq[string]
        for i in 0..<numArgs:
          let arg = Type_getTemplateArgumentAsType(cursorType, i.cuint)
          templateArgs.add(getFullyQualifiedType(arg))
        return constStr & getFullyQualifiedName(decl) & "<" & templateArgs.join(", ") & ">"
    return constStr & toNimStr(getTypeSpelling(cursorType))
  of CXType_Typedef:
    # For typedefs, don't add template args - the typedef name is already complete
    # e.g., color_rgba_t is a typedef for color_t<float, 4>, but we want just "color_rgba_t"
    let decl = getTypeDeclaration(cursorType)
    let name = getFullyQualifiedName(decl)
    if name.len > 0:
      return constStr & name
    # Fallback to type spelling for std library types like std::size_t
    return constStr & toNimStr(getTypeSpelling(cursorType))
  of CXType_Record, CXType_Elaborated:
    let decl = getTypeDeclaration(cursorType)
    let numArgs = Type_getNumTemplateArguments(cursorType)
    let declName = getFullyQualifiedName(decl)
    if numArgs > 0:
      var templateArgs: seq[string]
      for i in 0..<numArgs:
        let arg = Type_getTemplateArgumentAsType(cursorType, i.cuint)
        templateArgs.add(getFullyQualifiedType(arg))
      return constStr & declName & "<" & templateArgs.join(", ") & ">"
    # Fallback to spelling if decl name is empty (e.g., std::size_t)
    if declName.len > 0:
      return constStr & declName
    return constStr & toNimStr(getTypeSpelling(cursorType))
  else:
    return constStr & toNimStr(getTypeSpelling(cursorType))

proc getCodeSpan(cursor: CXCursor, fileCache: var Table[string, seq[string]], debugName: string = ""): string =
  ## Extract source code text for a cursor's extent.
  let loc = getCursorLocation(cursor)
  var file: CXFile
  var line, column, offset: cuint
  getExpansionLocation(loc, addr file, addr line, addr column, addr offset)
  if file == nil:
    return ""
  let filename = toNimStr(getFileName(file))
  if filename.len == 0:
    return ""

  if filename notin fileCache:
    try:
      fileCache[filename] = readFile(filename).splitLines()
    except:
      return ""

  let lines = fileCache[filename]
  if lines.len == 0:
    return ""

  let extent = getCursorExtent(cursor)
  var startLine, startCol, endLine, endCol: cuint
  var startFile, endFile: CXFile
  var startOff, endOff: cuint
  getExpansionLocation(getRangeStart(extent), addr startFile, addr startLine, addr startCol, addr startOff)
  getExpansionLocation(getRangeEnd(extent), addr endFile, addr endLine, addr endCol, addr endOff)

  # If extent is invalid (all zeros), fall back to using cursor location
  # Get from cursor column to end of line (or semicolon)
  if startLine == 0 and startCol == 0:
    let lineIdx = int(line) - 1
    if lineIdx < 0 or lineIdx >= lines.len:
      return ""
    let lineText = lines[lineIdx]
    let col = max(0, int(column) - 1)
    if col >= lineText.len:
      return ""
    var endPos = lineText.find(';', col)
    if endPos < 0:
      endPos = lineText.len
    return lineText[col..<endPos].strip()

  let lineIdx = int(startLine) - 1
  if lineIdx < 0 or lineIdx >= lines.len:
    return ""

  let off0 = max(0, int(startCol) - 1)
  var off1 = int(endCol) - 1
  if startLine < endLine:
    off1 = -1

  let lineText = lines[lineIdx]

  if off0 >= lineText.len:
    return ""
  if off1 < 0 or off1 > lineText.len:
    return lineText[off0..^1]
  if off1 <= off0:
    return ""
  return lineText[off0..<off1]

type
  CppAstVisitor = object
    ## Visitor for extracting declarations from a Clang AST.
    filename: string
    config: Config
    ctx: ptr ParserContext
    # Accumulated declarations
    enums: seq[EnumDecl]
    structs: seq[StructDecl]
    classes: seq[ClassDecl]
    methods: seq[MethodDecl]
    constructors: seq[ConstructorDecl]
    typedefs: seq[TypedefDecl]
    constants: seq[EnumDecl]
    enumDups: seq[EnumDup]

proc initCppAstVisitor(filename: string, config: Config, ctx: ptr ParserContext): CppAstVisitor =
  CppAstVisitor(filename: filename, config: config, ctx: ctx)

proc canVisit(v: CppAstVisitor, node: CXCursor): bool =
  ## Check if a node should be visited (belongs to our file).
  let loc = getCursorLocation(node)
  var file: CXFile
  var line, column, offset: cuint
  getExpansionLocation(loc, addr file, addr line, addr column, addr offset)
  if file == nil:
    return false
  let nodePath = toNimStr(getFileName(file))
  return nodePath == v.filename

proc getParamsFromNode(node: CXCursor, fileCache: var Table[string, seq[string]]): seq[Parameter] =
  ## Extract parameters from a function/method node.
  proc childVisitor(cursor, parent: CXCursor, clientData: CXClientData): CXChildVisitResult {.cdecl.} =
    if cursor.kind != CXCursor_ParmDecl:
      return CXChildVisit_Continue

    let params = cast[ptr seq[Parameter]](clientData)
    let paramName = toNimStr(getCursorDisplayName(cursor))
    let cursorType = getCursorType(cursor)
    let paramType = getFullyQualifiedType(cursorType)

    # TODO: Extract default value (complex, requires token parsing)
    params[].add(initParameter(paramName, paramType, none(string)))
    return CXChildVisit_Continue

  discard visitChildren(node, childVisitor, addr result)

proc visitEnumDecl(v: var CppAstVisitor, node: CXCursor) =
  ## Visit an enum declaration.
  let nodeHash = hashCursor(node)
  if nodeHash in v.ctx[].visitedEnums:
    return
  if isCursorDefinition(node) == 0:
    return

  let spelling = toNimStr(getCursorSpelling(node))
  let isConst = spelling == "" or
                spelling.startsWith("(unnamed") or
                spelling.startsWith("(anonymous") or
                spelling in v.config.enumToConst

  # Collect enum items
  var items: seq[EnumItem]
  proc enumChildVisitor(cursor, parent: CXCursor, clientData: CXClientData): CXChildVisitResult {.cdecl.} =
    if cursor.kind == CXCursor_EnumConstantDecl:
      let itemsPtr = cast[ptr seq[EnumItem]](clientData)
      let name = toNimStr(getCursorSpelling(cursor))
      let value = int(getEnumConstantDeclValue(cursor))
      itemsPtr[].add(initEnumItem(name, value, none(string)))
    return CXChildVisit_Continue

  discard visitChildren(node, enumChildVisitor, addr items)

  let fullyQual = getFullyQualifiedName(node)
  let underlyingType = toNimStr(getTypeSpelling(getEnumDeclIntegerType(node)))

  let enumData = initEnumDecl(
    name = spelling,
    fullyQualified = fullyQual,
    underlyingType = underlyingType,
    items = items,
    comment = none(string)
  )

  if not isConst:
    # Sort by value and handle duplicates
    var valueSet: HashSet[int]
    var newItems: seq[EnumItem]
    var value2name: Table[int, string]

    # First pass: collect unique values
    for item in items:
      if item.value notin valueSet:
        valueSet.incl(item.value)
        newItems.add(item)
        value2name[item.value] = item.name
      else:
        # Duplicate value
        v.enumDups.add(initEnumDup(value2name[item.value], item.name))

    var sortedEnum = enumData
    sortedEnum.items = newItems
    v.enums.add(sortedEnum)
  else:
    v.constants.add(enumData)

  v.ctx[].visitedEnums.incl(nodeHash)

proc extractFunctionPointerFieldName(sourceText: string): string =
  ## Extract field name from C function pointer field declaration.
  ## Handles patterns like: return_type(CALL_CONV* field_name)(params)
  ## The field name is between the last '*' and ')' in the first parenthesized group.
  var depth = 0
  var starPos = -1
  var closePos = -1

  for i, c in sourceText:
    if c == '(':
      inc depth
    elif c == ')':
      if depth == 1 and starPos >= 0:
        closePos = i
        break
      dec depth
    elif c == '*' and depth == 1:
      starPos = i

  if starPos >= 0 and closePos > starPos:
    result = sourceText[starPos+1..<closePos].strip()
  else:
    result = ""

proc getNestedFieldsFromAnonymousStruct(fieldCursor: CXCursor): seq[FieldDecl] =
  ## Get fields from an anonymous struct/union field.
  ## For fields like `struct { int x; float y; } myfield;`, returns the nested fields (x, y).
  let fieldType = getCursorType(fieldCursor)
  let typeDecl = getTypeDeclaration(fieldType)

  if typeDecl.kind notin {CXCursor_StructDecl, CXCursor_UnionDecl}:
    return @[]

  # Visit children of the anonymous struct to get its fields
  proc nestedFieldVisitor(cursor, parent: CXCursor, clientData: CXClientData): CXChildVisitResult {.cdecl.} =
    let fieldsPtr = cast[ptr seq[FieldDecl]](clientData)
    if cursor.kind == CXCursor_FieldDecl:
      let name = toNimStr(getCursorSpelling(cursor))
      let typeName = getFullyQualifiedType(getCursorType(cursor))
      # Check if the field's TYPE is an anonymous struct/union
      let nestedTypeDecl = getTypeDeclaration(getCursorType(cursor))
      let isAnon = Cursor_isAnonymous(nestedTypeDecl) != 0
      # Recursively handle nested anonymous structs
      var nestedFields: seq[FieldDecl]
      if isAnon:
        nestedFields = getNestedFieldsFromAnonymousStruct(cursor)
      fieldsPtr[].add(initFieldDecl(name, typeName, isAnon, nestedFields))
    return CXChildVisit_Continue

  var nestedFields: seq[FieldDecl]
  discard visitChildren(typeDecl, nestedFieldVisitor, addr nestedFields)
  result = nestedFields

proc parseStructInner(v: var CppAstVisitor, node: CXCursor): StructDecl =
  ## Parse the inner content of a struct.
  var fields: seq[FieldDecl]
  var fieldCursors: seq[CXCursor]  # Keep cursors for source extraction if needed
  var deps: seq[string]
  var templateParams: seq[TemplateParam]
  var baseTypes: seq[string]

  # Visit children to get template params, fields, and base types
  proc structChildVisitor(cursor, parent: CXCursor, clientData: CXClientData): CXChildVisitResult {.cdecl.} =
    type VisitorData = object
      fields: ptr seq[FieldDecl]
      fieldCursors: ptr seq[CXCursor]
      deps: ptr seq[string]
      templateParams: ptr seq[TemplateParam]
      baseTypes: ptr seq[string]

    let data = cast[ptr VisitorData](clientData)

    case cursor.kind
    of CXCursor_TemplateTypeParameter:
      let name = toNimStr(getCursorSpelling(cursor))
      data.templateParams[].add(initTemplateParam(name, none(string)))
    of CXCursor_NonTypeTemplateParameter:
      let name = toNimStr(getCursorSpelling(cursor))
      let typeName = toNimStr(getTypeSpelling(getCursorType(cursor)))
      data.templateParams[].add(initTemplateParam(name, some(typeName)))
    of CXCursor_CXXBaseSpecifier:
      let baseType = getFullyQualifiedType(getCursorType(cursor))
      data.baseTypes[].add(baseType)
    of CXCursor_FieldDecl:
      let fieldName = toNimStr(getCursorSpelling(cursor))
      let fieldType = getFullyQualifiedType(getCursorType(cursor))
      # Check if the field's TYPE is an anonymous struct/union
      let typeDecl = getTypeDeclaration(getCursorType(cursor))
      let isAnon = Cursor_isAnonymous(typeDecl) != 0
      let fieldSize = Type_getSizeOf(getCursorType(cursor))
      let sizeBytes = if fieldSize >= 0: int(fieldSize) else: 0
      data.fields[].add(initFieldDecl(fieldName, fieldType, isAnon, sizeBytes = sizeBytes))
      data.fieldCursors[].add(cursor)
      data.deps[].add(getTemplateDependencies(fieldType))
    else:
      discard

    return CXChildVisit_Continue

  type VisitorData = object
    fields: ptr seq[FieldDecl]
    fieldCursors: ptr seq[CXCursor]
    deps: ptr seq[string]
    templateParams: ptr seq[TemplateParam]
    baseTypes: ptr seq[string]

  var visitorData = VisitorData(
    fields: addr fields,
    fieldCursors: addr fieldCursors,
    deps: addr deps,
    templateParams: addr templateParams,
    baseTypes: addr baseTypes
  )
  discard visitChildren(node, structChildVisitor, addr visitorData)

  # Post-process: fix function pointer field names where clang returns wrong name
  # This happens for C syntax like: return_type(CALL_CONV* field_name)(params)
  # Also happens with macros like ORT_API2_STATUS where clang returns garbage
  for i in 0..<fields.len:
    let fieldType = fields[i].typeName
    let name = fields[i].name
    # Check if field name looks wrong:
    # - C type names (size_t, int, etc.)
    # - Contains comma (from macro parameter list)
    # - Contains space (invalid identifier)
    # - Is empty
    # - Common parameter names that indicate clang failed to get the real name
    let looksLikeTypeName = name in ["size_t", "int", "void", "char", "short", "long", "unsigned", "signed", "float", "double"] or
                            (name.len > 2 and name.endsWith("_t"))
    let looksLikeParamName = name in ["out", "env", "options", "logid", "op", "value", "type_info", "custom_op_domain", "library_handle", "run_tag", "log_severity_level", "profile_file_prefix"]
    let looksInvalid = ',' in name or ' ' in name or name.len == 0
    # Only try to fix names that actually look wrong - not ALL function pointer types
    if looksLikeTypeName or looksInvalid or looksLikeParamName:
      # Get source text and try to extract real field name
      let sourceText = getCodeSpan(fieldCursors[i], v.ctx[].fileCache)
      if sourceText.len > 0 and "*" in sourceText and "(" in sourceText:
        let realName = extractFunctionPointerFieldName(sourceText)
        if realName.len > 0 and realName != name and ',' notin realName and ' ' notin realName:
          fields[i] = initFieldDecl(realName, fieldType, fields[i].isAnonymous, sizeBytes = fields[i].sizeBytes)

  # Post-process: capture nested fields for anonymous struct/union fields
  for i in 0..<fields.len:
    if fields[i].isAnonymous and fields[i].name.len > 0:
      let nestedFields = getNestedFieldsFromAnonymousStruct(fieldCursors[i])
      if nestedFields.len > 0:
        fields[i] = initFieldDecl(fields[i].name, fields[i].typeName, true, nestedFields, sizeBytes = fields[i].sizeBytes)

  let spelling = toNimStr(getCursorSpelling(node))
  let fullyQual = getFullyQualifiedName(node)
  let size = Type_getSizeOf(getCursorType(node))
  let isIncomplete = size < 0

  result = initStructDecl(
    name = spelling,
    fullyQualified = fullyQual,
    fields = fields,
    baseTypes = baseTypes,
    templateParams = templateParams,
    isIncomplete = isIncomplete,
    isUnion = false,
    comment = none(string),
    underlyingDeps = deps
  )

proc visitStructDecl(v: var CppAstVisitor, node: CXCursor) =
  ## Visit a struct declaration.
  let nodeHash = hashCursor(node)
  if nodeHash in v.ctx[].visitedStructs:
    return
  let access = getCXXAccessSpecifier(node)
  if access == CX_CXXPrivate:
    return
  if isCursorDefinition(node) == 0:
    return
  let spelling = toNimStr(getCursorSpelling(node))
  if spelling.startsWith("(unnamed"):
    return

  var structData = v.parseStructInner(node)
  let size = Type_getSizeOf(getCursorType(node))
  # Include if size is valid OR if it's a template (templates have size -1)
  if size >= 0 or structData.templateParams.len > 0:
    v.structs.add(structData)
  v.ctx[].visitedStructs.incl(nodeHash)

proc visitClassDecl(v: var CppAstVisitor, node: CXCursor) =
  ## Visit a class declaration.
  let access = getCXXAccessSpecifier(node)
  if access == CX_CXXPrivate or access == CX_CXXProtected:
    return
  if isCursorDefinition(node) == 0:
    return
  if not v.canVisit(node):
    return

  var fields: seq[FieldDecl]
  var fieldCursors: seq[CXCursor]
  var templateParams: seq[TemplateParam]
  var baseTypes: seq[string]

  proc classChildVisitor(cursor, parent: CXCursor, clientData: CXClientData): CXChildVisitResult {.cdecl.} =
    type VisitorData = object
      fields: ptr seq[FieldDecl]
      fieldCursors: ptr seq[CXCursor]
      templateParams: ptr seq[TemplateParam]
      baseTypes: ptr seq[string]

    let data = cast[ptr VisitorData](clientData)

    case cursor.kind
    of CXCursor_CXXBaseSpecifier:
      let baseType = getFullyQualifiedType(getCursorType(cursor))
      data.baseTypes[].add(baseType)
    of CXCursor_TemplateTypeParameter:
      let name = toNimStr(getCursorSpelling(cursor))
      data.templateParams[].add(initTemplateParam(name, none(string)))
    of CXCursor_NonTypeTemplateParameter:
      let name = toNimStr(getCursorSpelling(cursor))
      let typeName = toNimStr(getTypeSpelling(getCursorType(cursor)))
      data.templateParams[].add(initTemplateParam(name, some(typeName)))
    of CXCursor_FieldDecl:
      # Only public fields
      let fieldAccess = getCXXAccessSpecifier(cursor)
      if fieldAccess != CX_CXXPrivate:
        let fieldName = toNimStr(getCursorSpelling(cursor))
        let fieldType = getFullyQualifiedType(getCursorType(cursor))
        # Check if the field's TYPE is an anonymous struct/union
        let typeDecl = getTypeDeclaration(getCursorType(cursor))
        let isAnon = Cursor_isAnonymous(typeDecl) != 0
        let fieldSize = Type_getSizeOf(getCursorType(cursor))
        let sizeBytes = if fieldSize >= 0: int(fieldSize) else: 0
        data.fields[].add(initFieldDecl(fieldName, fieldType, isAnon, sizeBytes = sizeBytes))
        data.fieldCursors[].add(cursor)
    else:
      discard

    return CXChildVisit_Continue

  type VisitorData = object
    fields: ptr seq[FieldDecl]
    fieldCursors: ptr seq[CXCursor]
    templateParams: ptr seq[TemplateParam]
    baseTypes: ptr seq[string]

  var visitorData = VisitorData(
    fields: addr fields,
    fieldCursors: addr fieldCursors,
    templateParams: addr templateParams,
    baseTypes: addr baseTypes
  )
  discard visitChildren(node, classChildVisitor, addr visitorData)

  # Post-process: capture nested fields for anonymous struct/union fields
  for i in 0..<fields.len:
    if fields[i].isAnonymous and fields[i].name.len > 0:
      let nestedFields = getNestedFieldsFromAnonymousStruct(fieldCursors[i])
      if nestedFields.len > 0:
        fields[i] = initFieldDecl(fields[i].name, fields[i].typeName, true, nestedFields)

  let spelling = toNimStr(getCursorSpelling(node))
  let fullyQual = getFullyQualifiedName(node)

  v.classes.add(initClassDecl(
    name = spelling,
    fullyQualified = fullyQual,
    fields = fields,
    baseTypes = baseTypes,
    templateParams = templateParams,
    comment = none(string)
  ))

proc visitConstructorDecl(v: var CppAstVisitor, node: CXCursor) =
  ## Visit a constructor declaration.
  if not v.canVisit(node):
    return

  let spelling = toNimStr(getCursorSpelling(node))
  let parent = getCursorSemanticParent(node)
  let className = toNimStr(getCursorSpelling(parent))
  let fullyQual = getFullyQualifiedName(parent)
  let params = getParamsFromNode(node, v.ctx[].fileCache)

  v.constructors.add(initConstructorDecl(
    name = spelling,
    fullyQualified = fullyQual,
    className = className,
    params = params,
    comment = none(string)
  ))

proc visitCxxMethod(v: var CppAstVisitor, node: CXCursor) =
  ## Visit a C++ method.
  let access = getCXXAccessSpecifier(node)
  if access == CX_CXXPrivate:
    return
  if not v.canVisit(node):
    return

  var name = toNimStr(getCursorSpelling(node))
  if name.startsWith("operator"):
    let op = name[8..^1]
    if op.match(re"[\[\]!+\-=*\^/]+"):
      name = "`" & op & "`"
    else:
      return

  let parent = getCursorSemanticParent(node)
  let className = toNimStr(getCursorSpelling(parent))
  let fullyQual = getFullyQualifiedName(node)
  let returnType = toNimStr(getTypeSpelling(getCursorResultType(node)))
  let params = getParamsFromNode(node, v.ctx[].fileCache)
  let isConst = (CXXMethod_isConst(node) != 0)
  let isStatic = (CXXMethod_isStatic(node) != 0)

  # Get file origin
  let loc = getCursorLocation(node)
  var file: CXFile
  var line, column, offset: cuint
  getExpansionLocation(loc, addr file, addr line, addr column, addr offset)
  let fileOrigin = if file != nil: toNimStr(getFileName(file)) else: ""

  v.methods.add(initMethodDecl(
    name = name,
    fullyQualified = fullyQual,
    className = className,
    returnType = returnType,
    params = params,
    isConst = isConst,
    isStatic = isStatic,
    isPlainFunction = false,
    fileOrigin = fileOrigin,
    comment = none(string),
    resultDeps = getTemplateDependencies(returnType)
  ))

proc visitFunctionDecl(v: var CppAstVisitor, node: CXCursor) =
  ## Visit a function declaration.
  let access = getCXXAccessSpecifier(node)
  if access == CX_CXXPrivate:
    return

  let name = toNimStr(getCursorSpelling(node))
  if name.startsWith("operator"):
    return

  let fullyQual = getFullyQualifiedName(node)
  let returnType = toNimStr(getTypeSpelling(getCursorResultType(node)))
  let params = getParamsFromNode(node, v.ctx[].fileCache)

  # Get file origin
  let loc = getCursorLocation(node)
  var file: CXFile
  var line, column, offset: cuint
  getExpansionLocation(loc, addr file, addr line, addr column, addr offset)
  let fileOrigin = if file != nil: toNimStr(getFileName(file)) else: ""

  v.methods.add(initMethodDecl(
    name = name,
    fullyQualified = fullyQual,
    className = "",
    returnType = returnType,
    params = params,
    isConst = false,
    isPlainFunction = true,
    fileOrigin = fileOrigin,
    comment = none(string),
    resultDeps = getTemplateDependencies(returnType)
  ))

proc visitTypedefDecl(v: var CppAstVisitor, node: CXCursor) =
  ## Visit a typedef declaration.
  let access = getCXXAccessSpecifier(node)
  if access == CX_CXXPrivate or access == CX_CXXProtected:
    return

  let spelling = toNimStr(getCursorSpelling(node))
  let underlyingType = getTypedefDeclUnderlyingType(node)
  var underlying = toNimStr(getTypeSpelling(underlyingType))
  let underlyingDeps = getTemplateDependencies(underlying)
  let params = getParamsFromNode(node, v.ctx[].fileCache)

  var typedefKind = none(string)
  var resultType = some(toNimStr(getTypeSpelling(getCursorResultType(node))))
  var structData = none(StructDecl)
  var enumData = none(EnumDecl)

  let kind = underlyingType.kind

  if kind == CXType_Pointer:
    let pointee = getPointeeType(underlyingType)
    if pointee.kind == CXType_FunctionProto:
      resultType = some(toNimStr(getTypeSpelling(getResultType(pointee))))
      typedefKind = some("function")
    else:
      # Check if pointing to a forward-declared-only struct (opaque handle pattern)
      let pointeeDecl = getTypeDeclaration(pointee)
      if pointeeDecl.kind in {CXCursor_StructDecl, CXCursor_UnionDecl}:
        if isCursorDefinition(pointeeDecl) == 0:
          # This is a typedef to a pointer to a forward-declared struct
          # Mark as opaque handle so generator can emit = pointer
          underlying = "void *"
  elif kind == CXType_FunctionProto:
    resultType = some(toNimStr(getTypeSpelling(getResultType(underlyingType))))
    typedefKind = some("function")
  else:
    let inner = getTypeDeclaration(underlyingType)
    case inner.kind
    of CXCursor_StructDecl:
      let innerHash = hashCursor(inner)
      if innerHash in v.ctx[].visitedStructs:
        # Struct already visited - this is just a typedef alias (e.g., typedef struct Foo_ Foo;)
        typedefKind = some("alias")
      else:
        v.ctx[].visitedStructs.incl(innerHash)
        structData = some(v.parseStructInner(inner))
        typedefKind = some("struct")
    of CXCursor_UnionDecl:
      let innerHash = hashCursor(inner)
      if innerHash in v.ctx[].visitedStructs:
        # Union already visited - this is just a typedef alias
        typedefKind = some("alias")
      else:
        v.ctx[].visitedStructs.incl(innerHash)
        var sd = v.parseStructInner(inner)
        sd.isUnion = true
        structData = some(sd)
        typedefKind = some("struct")
    of CXCursor_EnumDecl:
      if spelling in v.config.enumToConst:
        return
      let innerHash = hashCursor(inner)
      if innerHash in v.ctx[].visitedEnums:
        # Enum already visited - this is just a typedef alias
        typedefKind = some("alias")
      else:
        v.ctx[].visitedEnums.incl(innerHash)

      var items: seq[EnumItem]
      proc enumChildVisitor2(cursor, parent: CXCursor, clientData: CXClientData): CXChildVisitResult {.cdecl.} =
        if cursor.kind == CXCursor_EnumConstantDecl:
          let itemsPtr = cast[ptr seq[EnumItem]](clientData)
          let name = toNimStr(getCursorSpelling(cursor))
          let value = int(getEnumConstantDeclValue(cursor))
          itemsPtr[].add(initEnumItem(name, value, none(string)))
        return CXChildVisit_Continue

      discard visitChildren(inner, enumChildVisitor2, addr items)

      let innerName = toNimStr(getCursorSpelling(inner))
      # Use typedef name for anonymous enums (common C pattern: typedef type name; enum { ... };)
      let enumName = if innerName == "" or innerName.startsWith("(unnamed") or innerName.startsWith("(anonymous"):
          spelling
        else:
          innerName
      let enumFQ = if enumName == spelling:
          getFullyQualifiedName(node)
        else:
          getFullyQualifiedName(inner)
      enumData = some(initEnumDecl(
        name = enumName,
        fullyQualified = enumFQ,
        underlyingType = toNimStr(getTypeSpelling(getEnumDeclIntegerType(inner))),
        items = items,
        comment = none(string)
      ))
      typedefKind = some("enum")
    else:
      discard

  v.typedefs.add(initTypedefDecl(
    name = spelling,
    fullyQualified = getFullyQualifiedName(node),
    underlying = underlying,
    typedefKind = typedefKind,
    params = params,
    resultType = resultType,
    underlyingDeps = underlyingDeps,
    structData = structData,
    enumData = enumData
  ))

proc visitAll(v: var CppAstVisitor, cursor: CXCursor) =
  ## Visit all nodes in the AST.
  type
    NodeLists = object
      typedefs: seq[CXCursor]
      enums: seq[CXCursor]
      classes: seq[CXCursor]
      structs: seq[CXCursor]
      unions: seq[CXCursor]
      constructors: seq[CXCursor]
      methods: seq[CXCursor]
      functions: seq[CXCursor]

  var nodes: NodeLists

  proc collectNodesVisitor(cursor, parent: CXCursor, clientData: CXClientData): CXChildVisitResult {.cdecl.} =
    let data = cast[ptr NodeLists](clientData)
    case cursor.kind
    of CXCursor_TypedefDecl, CXCursor_TypeAliasDecl:
      # TypedefDecl = C typedef, TypeAliasDecl = C++11 "using X = Y"
      data.typedefs.add(cursor)
    of CXCursor_EnumDecl:
      data.enums.add(cursor)
    of CXCursor_ClassDecl:
      data.classes.add(cursor)
      # Recurse to find methods/constructors inside class
      return CXChildVisit_Recurse
    of CXCursor_ClassTemplate:
      # Template can be struct or class - check what it instantiates to
      let templateKind = getTemplateCursorKind(cursor)
      if templateKind == CXCursor_StructDecl:
        data.structs.add(cursor)
      else:
        data.classes.add(cursor)
      return CXChildVisit_Recurse
    of CXCursor_StructDecl:
      data.structs.add(cursor)
      # Recurse to find methods/constructors inside struct
      return CXChildVisit_Recurse
    of CXCursor_UnionDecl:
      data.unions.add(cursor)
    of CXCursor_Constructor:
      data.constructors.add(cursor)
    of CXCursor_CXXMethod:
      data.methods.add(cursor)
    of CXCursor_FunctionDecl:
      data.functions.add(cursor)
    of CXCursor_Namespace:
      # Recurse into namespaces
      return CXChildVisit_Recurse
    else:
      discard
    return CXChildVisit_Continue

  discard visitChildren(cursor, collectNodesVisitor, addr nodes)

  # Visit typedefs first (they may define structs/enums)
  for node in nodes.typedefs:
    if v.canVisit(node):
      v.visitTypedefDecl(node)

  for node in nodes.enums:
    if v.canVisit(node):
      v.visitEnumDecl(node)

  for node in nodes.classes:
    if v.canVisit(node):
      v.visitClassDecl(node)

  for node in nodes.structs:
    if v.canVisit(node):
      v.visitStructDecl(node)

  for node in nodes.unions:
    if v.canVisit(node):
      # Parse union like struct but mark as union
      let nodeHash = hashCursor(node)
      if nodeHash notin v.ctx[].visitedStructs:
        let spelling = toNimStr(getCursorSpelling(node))
        if not spelling.startsWith("(unnamed"):
          var unionData = v.parseStructInner(node)
          unionData.isUnion = true
          v.structs.add(unionData)
          v.ctx[].visitedStructs.incl(nodeHash)

  for node in nodes.constructors:
    if v.canVisit(node):
      v.visitConstructorDecl(node)

  for node in nodes.methods:
    if v.canVisit(node):
      v.visitCxxMethod(node)

  for node in nodes.functions:
    if v.canVisit(node):
      v.visitFunctionDecl(node)

proc findDependsOn(header: ParsedHeader): HashSet[string] =
  ## Find all dependencies in the parsed header.
  for meth in header.methods:
    for param in meth.params:
      let deps = getTemplateDependencies(param.typeName)
      if deps.len > 0:
        for d in deps:
          result.incl(d)
      else:
        result.incl(cleanTypeName(param.typeName))

      if param.defaultValue.isSome:
        result.incl(param.defaultValue.get)

    if meth.resultDeps.len > 0:
      for d in meth.resultDeps:
        result.incl(d)
    elif meth.returnType.len > 0:
      result.incl(cleanTypeName(meth.returnType))

  for ctor in header.constructors:
    for param in ctor.params:
      let deps = getTemplateDependencies(param.typeName)
      if deps.len > 0:
        for d in deps:
          result.incl(d)
      else:
        result.incl(cleanTypeName(param.typeName))

  for typedef in header.typedefs:
    if typedef.underlyingDeps.len > 0:
      for d in typedef.underlyingDeps:
        result.incl(d)
    else:
      result.incl(cleanTypeName(typedef.underlying))

  for struct in header.structs:
    for field in struct.fields:
      result.incl(field.typeName)

proc findProvided(header: ParsedHeader, dependencies: HashSet[string]): HashSet[string] =
  ## Find all types that the header provides.
  for constEnum in header.constants:
    for item in constEnum.items:
      if item.name in dependencies:
        result.incl(item.name)

  for e in header.enums:
    for item in e.items:
      result.incl(item.name)
    result.incl(e.fullyQualified)

  for struct in header.structs:
    result.incl(struct.fullyQualified)

  for cls in header.classes:
    result.incl(cls.fullyQualified)

  for typedef in header.typedefs:
    result.incl(typedef.fullyQualified)

proc findMissing(dependencies, provides: HashSet[string]): HashSet[string] =
  ## Find dependencies that are not provided locally.
  for dep in dependencies:
    if dep in NormalTypes:
      continue
    if dep in provides:
      continue
    result.incl(dep)

proc detectSysroot(): string =
  ## Auto-detect system SDK/sysroot path for the current platform.
  when defined(macosx):
    const sdkPaths = [
      "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk",
      "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
    ]
    for path in sdkPaths:
      if dirExists(path):
        return path
  elif defined(windows):
    # Windows SDK paths - check common Visual Studio locations
    const winSdkPaths = [
      r"C:\Program Files (x86)\Windows Kits\10\Include",
      r"C:\Program Files\Windows Kits\10\Include",
    ]
    for path in winSdkPaths:
      if dirExists(path):
        return path
  elif defined(linux):
    # Linux typically doesn't need explicit sysroot, but check for cross-compile setups
    const linuxSysroots = [
      "/usr/include",
      "/usr/local/include",
    ]
    for path in linuxSysroots:
      if dirExists(path):
        return ""  # Linux usually works without explicit sysroot
  return ""

proc parseSingleFile(filename: string, config: Config): ParsedHeader =
  var ctx = initParserContext()

  let index = createIndex(0, 0)
  defer: disposeIndex(index)

  var clangArgs: seq[cstring]
  var argStrings: seq[string]

  if config.cMode:
    argStrings.add("-x")
    argStrings.add("c")
  else:
    argStrings.add("-x")
    argStrings.add("c++")
    argStrings.add("-std=c++17")

  # Auto-add macOS sysroot if not already specified
  var hasSysroot = false
  for arg in config.extraArgs:
    if arg == "-isysroot" or arg.startsWith("-isysroot"):
      hasSysroot = true
      break
  if not hasSysroot:
    let sysroot = detectSysroot()
    if sysroot.len > 0:
      argStrings.add("-isysroot")
      argStrings.add(sysroot)

  for arg in config.extraArgs:
    argStrings.add(arg)

  for define in config.defines:
    argStrings.add("-D" & define)

  for path in config.searchPaths:
    argStrings.add("-I" & path)

  # Force-include headers (for C libs with typedef dependencies across headers)
  # Skip pre-including the target file itself to avoid duplicate declaration issues
  let targetBasename = extractFilename(filename)
  for header in config.preIncludeHeaders:
    let headerBasename = extractFilename(header)
    if headerBasename == targetBasename:
      continue  # Don't pre-include the file we're about to parse
    argStrings.add("-include")
    argStrings.add(header)

  for s in argStrings:
    clangArgs.add(s.cstring)

  let opts = (CXTranslationUnit_SkipFunctionBodies.cuint or
              CXTranslationUnit_DetailedPreprocessingRecord.cuint)

  var tu: CXTranslationUnit
  let argsArray = if clangArgs.len > 0: allocCStringArray(argStrings) else: nil
  defer:
    if argsArray != nil:
      deallocCStringArray(argsArray)

  let err = parseTranslationUnit2(
    index,
    filename.cstring,
    argsArray,
    clangArgs.len.cint,
    nil, 0,
    opts,
    addr tu
  )

  if err != CXError_Success or tu == nil:
    error "Failed to parse: " & filename
    return initParsedHeader(filename)

  defer: disposeTranslationUnit(tu)

  # Visit AST
  let rootCursor = getTranslationUnitCursor(tu)
  var visitor = initCppAstVisitor(filename, config, addr ctx)
  visitor.visitAll(rootCursor)

  # Create ParsedHeader
  result = initParsedHeader(filename)
  result.enums = visitor.enums
  result.structs = visitor.structs
  result.classes = visitor.classes
  result.methods = visitor.methods
  result.constructors = visitor.constructors
  result.typedefs = visitor.typedefs
  result.constants = visitor.constants
  result.enumDups = visitor.enumDups

  # Compute dependencies
  result.dependencies = findDependsOn(result)
  result.provides = findProvided(result, result.dependencies)
  result.missing = findMissing(result.dependencies, result.provides)

proc parseFile*(p: CppHeaderParser, filename: string): ParsedHeader =
  parseSingleFile(filename, p.config)

proc parseFiles*(p: CppHeaderParser, patterns: seq[string],
                 progressCallback: proc(current, total: int, filename: string) = nil): ParseResult =
  var files: seq[string]
  for pattern in patterns:
    if "*" in pattern or "?" in pattern:
      for path in walkDir(pattern.parentDir):
        if path.kind == pcFile:
          files.add(path.path)
    elif fileExists(pattern):
      files.add(pattern)

  files = files.filterIt(it notin p.config.ignoreFiles)

  if files.len == 0:
    return initParseResult()

  result = initParseResult()

  for i, filename in files:
    info "Parsing (" & $(i+1) & "/" & $files.len & "): " & filename
    let header = parseSingleFile(filename, p.config)
    result.headers[filename] = header
    result.allDependencies[filename] = header.dependencies
    result.allProvides[filename] = header.provides
    result.allMissing[filename] = header.missing

    if progressCallback != nil:
      progressCallback(i + 1, files.len, filename)
