## Data models for cpp2nim.
##
## Type-safe objects representing C++ declarations extracted from headers.
## These replace the untyped dictionaries used in the original implementation.

import std/[json, options, tables, sets, sequtils]

type
  Parameter* = object
    ## A function/method parameter.
    ##
    ## Fields:
    ##   name: Parameter name (may be empty for unnamed params).
    ##   typeName: The C++ type as a string.
    ##   defaultValue: Default value expression, or none if no default.
    name*: string
    typeName*: string
    defaultValue*: Option[string]

  EnumItem* = object
    ## A single enumerator within an enum.
    ##
    ## Fields:
    ##   name: Enumerator name.
    ##   value: Integer value.
    ##   comment: Documentation comment, if any.
    name*: string
    value*: int
    comment*: Option[string]

  EnumDecl* = object
    ## An enum declaration.
    ##
    ## Fields:
    ##   name: Enum name (may be empty for anonymous enums).
    ##   fullyQualified: Fully qualified C++ name (e.g., "ns::MyEnum").
    ##   underlyingType: The underlying integer type.
    ##   items: List of enumerators.
    ##   comment: Documentation comment.
    name*: string
    fullyQualified*: string
    underlyingType*: string
    items*: seq[EnumItem]
    comment*: Option[string]

  FieldDecl* = object
    ## A struct/class field declaration.
    ##
    ## Fields:
    ##   name: Field name.
    ##   typeName: The C++ type.
    ##   isAnonymous: Whether this field's type is an anonymous struct/union.
    ##   nestedFields: For anonymous struct fields, the fields of the nested struct.
    name*: string
    typeName*: string
    isAnonymous*: bool
    nestedFields*: seq[FieldDecl]

  TemplateParam* = object
    ## A template parameter - either just a name or a (name, type) pair.
    name*: string
    typeName*: Option[string]

  StructDecl* = object
    ## A struct declaration.
    ##
    ## Fields:
    ##   name: Struct name.
    ##   fullyQualified: Fully qualified C++ name.
    ##   fields: List of field declarations.
    ##   baseTypes: Base class/struct types for inheritance.
    ##   templateParams: Template parameters.
    ##   isIncomplete: Whether the struct has opaque/incomplete size.
    ##   isUnion: Whether this is actually a union.
    ##   comment: Documentation comment.
    ##   underlyingDeps: Type dependencies extracted from fields.
    name*: string
    fullyQualified*: string
    fields*: seq[FieldDecl]
    baseTypes*: seq[string]
    templateParams*: seq[TemplateParam]
    isIncomplete*: bool
    isUnion*: bool
    comment*: Option[string]
    underlyingDeps*: seq[string]

  ClassDecl* = object
    ## A C++ class declaration.
    ##
    ## Fields:
    ##   name: Class name.
    ##   fullyQualified: Fully qualified C++ name.
    ##   fields: Public fields.
    ##   baseTypes: Base class types.
    ##   templateParams: Template parameters.
    ##   comment: Documentation comment.
    name*: string
    fullyQualified*: string
    fields*: seq[FieldDecl]
    baseTypes*: seq[string]
    templateParams*: seq[TemplateParam]
    comment*: Option[string]

  MethodDecl* = object
    ## A method or function declaration.
    ##
    ## Fields:
    ##   name: Method/function name.
    ##   fullyQualified: Fully qualified name.
    ##   className: Owning class name (empty for free functions).
    ##   returnType: Return type.
    ##   params: Parameter list.
    ##   isConst: Whether this is a const method.
    ##   isStatic: Whether this is a static method.
    ##   isPlainFunction: Whether this is a free function vs method.
    ##   fileOrigin: Source file path.
    ##   comment: Documentation comment.
    ##   resultDeps: Dependencies from return type.
    name*: string
    fullyQualified*: string
    className*: string
    returnType*: string
    params*: seq[Parameter]
    isConst*: bool
    isStatic*: bool
    isPlainFunction*: bool
    fileOrigin*: string
    comment*: Option[string]
    resultDeps*: seq[string]

  ConstructorDecl* = object
    ## A constructor declaration.
    ##
    ## Fields:
    ##   name: Constructor name (class name).
    ##   fullyQualified: Fully qualified class name.
    ##   className: Class name.
    ##   params: Constructor parameters.
    ##   comment: Documentation comment.
    name*: string
    fullyQualified*: string
    className*: string
    params*: seq[Parameter]
    comment*: Option[string]

  TypedefDecl* = object
    ## A typedef declaration.
    ##
    ## Fields:
    ##   name: Typedef name.
    ##   fullyQualified: Fully qualified name.
    ##   underlying: Underlying type.
    ##   typedefKind: Kind of typedef ("function", "struct", "enum", or none).
    ##   params: Parameters if this is a function typedef.
    ##   resultType: Return type if this is a function typedef.
    ##   underlyingDeps: Type dependencies.
    ##   structData: Embedded struct data if typedefKind is "struct".
    ##   enumData: Embedded enum data if typedefKind is "enum".
    name*: string
    fullyQualified*: string
    underlying*: string
    typedefKind*: Option[string]
    params*: seq[Parameter]
    resultType*: Option[string]
    underlyingDeps*: seq[string]
    structData*: Option[StructDecl]
    enumData*: Option[EnumDecl]

  EnumDup* = object
    ## Duplicate enum value mapping.
    original*: string
    duplicate*: string

  ParsedHeader* = object
    ## Result of parsing a single header file.
    ##
    ## Fields:
    ##   filename: Path to the source header file.
    ##   enums: Enum declarations found.
    ##   structs: Struct declarations found.
    ##   classes: Class declarations found.
    ##   methods: Method and function declarations found.
    ##   constructors: Constructor declarations found.
    ##   typedefs: Typedef declarations found.
    ##   constants: Anonymous enums treated as constants.
    ##   enumDups: Duplicate enum value mappings.
    ##   dependencies: Types this header depends on.
    ##   provides: Types this header provides.
    ##   missing: Dependencies not found locally.
    filename*: string
    enums*: seq[EnumDecl]
    structs*: seq[StructDecl]
    classes*: seq[ClassDecl]
    methods*: seq[MethodDecl]
    constructors*: seq[ConstructorDecl]
    typedefs*: seq[TypedefDecl]
    constants*: seq[EnumDecl]
    enumDups*: seq[EnumDup]
    dependencies*: HashSet[string]
    provides*: HashSet[string]
    missing*: HashSet[string]

  ParseResult* = object
    ## Result of parsing multiple headers.
    ##
    ## Fields:
    ##   headers: Map from filename to ParsedHeader.
    ##   allDependencies: Dependencies per file.
    ##   allProvides: Provided types per file.
    ##   allMissing: Missing dependencies per file.
    headers*: Table[string, ParsedHeader]
    allDependencies*: Table[string, HashSet[string]]
    allProvides*: Table[string, HashSet[string]]
    allMissing*: Table[string, HashSet[string]]


# Constructors

proc initParameter*(name, typeName: string, defaultValue = none(string)): Parameter =
  Parameter(name: name, typeName: typeName, defaultValue: defaultValue)

proc initEnumItem*(name: string, value: int, comment = none(string)): EnumItem =
  EnumItem(name: name, value: value, comment: comment)

proc initEnumDecl*(name, fullyQualified, underlyingType: string,
                   items: seq[EnumItem] = @[], comment = none(string)): EnumDecl =
  EnumDecl(name: name, fullyQualified: fullyQualified,
           underlyingType: underlyingType, items: items, comment: comment)

proc initFieldDecl*(name, typeName: string, isAnonymous = false, nestedFields: seq[FieldDecl] = @[]): FieldDecl =
  FieldDecl(name: name, typeName: typeName, isAnonymous: isAnonymous, nestedFields: nestedFields)

proc initTemplateParam*(name: string, typeName = none(string)): TemplateParam =
  TemplateParam(name: name, typeName: typeName)

proc initStructDecl*(name, fullyQualified: string,
                     fields: seq[FieldDecl] = @[],
                     baseTypes: seq[string] = @[],
                     templateParams: seq[TemplateParam] = @[],
                     isIncomplete = false, isUnion = false,
                     comment = none(string),
                     underlyingDeps: seq[string] = @[]): StructDecl =
  StructDecl(name: name, fullyQualified: fullyQualified,
             fields: fields, baseTypes: baseTypes,
             templateParams: templateParams,
             isIncomplete: isIncomplete, isUnion: isUnion,
             comment: comment, underlyingDeps: underlyingDeps)

proc initClassDecl*(name, fullyQualified: string,
                    fields: seq[FieldDecl] = @[],
                    baseTypes: seq[string] = @[],
                    templateParams: seq[TemplateParam] = @[],
                    comment = none(string)): ClassDecl =
  ClassDecl(name: name, fullyQualified: fullyQualified,
            fields: fields, baseTypes: baseTypes,
            templateParams: templateParams, comment: comment)

proc initMethodDecl*(name, fullyQualified, className, returnType: string,
                     params: seq[Parameter] = @[],
                     isConst = false, isStatic = false, isPlainFunction = false,
                     fileOrigin = "", comment = none(string),
                     resultDeps: seq[string] = @[]): MethodDecl =
  MethodDecl(name: name, fullyQualified: fullyQualified,
             className: className, returnType: returnType,
             params: params, isConst: isConst, isStatic: isStatic,
             isPlainFunction: isPlainFunction,
             fileOrigin: fileOrigin, comment: comment,
             resultDeps: resultDeps)

proc initConstructorDecl*(name, fullyQualified, className: string,
                          params: seq[Parameter] = @[],
                          comment = none(string)): ConstructorDecl =
  ConstructorDecl(name: name, fullyQualified: fullyQualified,
                  className: className, params: params, comment: comment)

proc initTypedefDecl*(name, fullyQualified, underlying: string,
                      typedefKind = none(string),
                      params: seq[Parameter] = @[],
                      resultType = none(string),
                      underlyingDeps: seq[string] = @[],
                      structData = none(StructDecl),
                      enumData = none(EnumDecl)): TypedefDecl =
  TypedefDecl(name: name, fullyQualified: fullyQualified,
              underlying: underlying, typedefKind: typedefKind,
              params: params, resultType: resultType,
              underlyingDeps: underlyingDeps,
              structData: structData, enumData: enumData)

proc initEnumDup*(original, duplicate: string): EnumDup =
  EnumDup(original: original, duplicate: duplicate)

proc initParsedHeader*(filename: string): ParsedHeader =
  ParsedHeader(filename: filename)

proc initParseResult*(): ParseResult =
  ParseResult()


# JSON serialization helpers

proc optToJson(opt: Option[string]): JsonNode =
  if opt.isSome: %opt.get else: newJNull()

proc jsonToOpt(node: JsonNode): Option[string] =
  if node.kind == JNull: none(string)
  else: some(node.getStr)

proc `%`*(p: Parameter): JsonNode =
  %*{"name": p.name, "type_name": p.typeName, "default_value": optToJson(p.defaultValue)}

proc `%`*(e: EnumItem): JsonNode =
  %*{"name": e.name, "value": e.value, "comment": optToJson(e.comment)}

proc `%`*(e: EnumDecl): JsonNode =
  %*{
    "name": e.name,
    "fully_qualified": e.fullyQualified,
    "underlying_type": e.underlyingType,
    "items": %e.items,
    "comment": optToJson(e.comment)
  }

proc `%`*(f: FieldDecl): JsonNode =
  result = %*{"name": f.name, "type_name": f.typeName, "is_anonymous": f.isAnonymous}
  if f.nestedFields.len > 0:
    result["nested_fields"] = %f.nestedFields

proc `%`*(t: TemplateParam): JsonNode =
  if t.typeName.isSome:
    %*{"name": t.name, "type_name": t.typeName.get}
  else:
    %*{"name": t.name}

proc `%`*(s: StructDecl): JsonNode =
  %*{
    "name": s.name,
    "fully_qualified": s.fullyQualified,
    "fields": %s.fields,
    "base_types": %s.baseTypes,
    "template_params": %s.templateParams,
    "is_incomplete": s.isIncomplete,
    "is_union": s.isUnion,
    "comment": optToJson(s.comment),
    "underlying_deps": %s.underlyingDeps
  }

proc `%`*(c: ClassDecl): JsonNode =
  %*{
    "name": c.name,
    "fully_qualified": c.fullyQualified,
    "fields": %c.fields,
    "base_types": %c.baseTypes,
    "template_params": %c.templateParams,
    "comment": optToJson(c.comment)
  }

proc `%`*(m: MethodDecl): JsonNode =
  %*{
    "name": m.name,
    "fully_qualified": m.fullyQualified,
    "class_name": m.className,
    "return_type": m.returnType,
    "params": %m.params,
    "is_const": m.isConst,
    "is_static": m.isStatic,
    "is_plain_function": m.isPlainFunction,
    "file_origin": m.fileOrigin,
    "comment": optToJson(m.comment),
    "result_deps": %m.resultDeps
  }

proc `%`*(c: ConstructorDecl): JsonNode =
  %*{
    "name": c.name,
    "fully_qualified": c.fullyQualified,
    "class_name": c.className,
    "params": %c.params,
    "comment": optToJson(c.comment)
  }

proc `%`*(t: TypedefDecl): JsonNode =
  result = %*{
    "name": t.name,
    "fully_qualified": t.fullyQualified,
    "underlying": t.underlying,
    "typedef_kind": optToJson(t.typedefKind),
    "params": %t.params,
    "result_type": optToJson(t.resultType),
    "underlying_deps": %t.underlyingDeps
  }
  if t.structData.isSome:
    result["struct_data"] = %t.structData.get
  if t.enumData.isSome:
    result["enum_data"] = %t.enumData.get

proc `%`*(e: EnumDup): JsonNode =
  %*{"original": e.original, "duplicate": e.duplicate}

proc `%`*(h: ParsedHeader): JsonNode =
  %*{
    "filename": h.filename,
    "enums": %h.enums,
    "structs": %h.structs,
    "classes": %h.classes,
    "methods": %h.methods,
    "constructors": %h.constructors,
    "typedefs": %h.typedefs,
    "constants": %h.constants,
    "enum_dups": %h.enumDups,
    "dependencies": %toSeq(h.dependencies),
    "provides": %toSeq(h.provides),
    "missing": %toSeq(h.missing)
  }

proc `%`*(r: ParseResult): JsonNode =
  var headersJson = newJObject()
  for k, v in r.headers:
    headersJson[k] = %v

  var depsJson = newJObject()
  for k, v in r.allDependencies:
    depsJson[k] = %toSeq(v)

  var providesJson = newJObject()
  for k, v in r.allProvides:
    providesJson[k] = %toSeq(v)

  var missingJson = newJObject()
  for k, v in r.allMissing:
    missingJson[k] = %toSeq(v)

  %*{
    "headers": headersJson,
    "all_dependencies": depsJson,
    "all_provides": providesJson,
    "all_missing": missingJson
  }


# JSON deserialization

proc toParameter*(node: JsonNode): Parameter =
  Parameter(
    name: node["name"].getStr,
    typeName: node["type_name"].getStr,
    defaultValue: jsonToOpt(node["default_value"])
  )

proc toEnumItem*(node: JsonNode): EnumItem =
  EnumItem(
    name: node["name"].getStr,
    value: node["value"].getInt,
    comment: jsonToOpt(node["comment"])
  )

proc toEnumDecl*(node: JsonNode): EnumDecl =
  var items: seq[EnumItem]
  for item in node["items"]:
    items.add(toEnumItem(item))
  EnumDecl(
    name: node["name"].getStr,
    fullyQualified: node["fully_qualified"].getStr,
    underlyingType: node["underlying_type"].getStr,
    items: items,
    comment: jsonToOpt(node["comment"])
  )

proc toFieldDecl*(node: JsonNode): FieldDecl =
  var nestedFields: seq[FieldDecl]
  if node.hasKey("nested_fields"):
    for nf in node["nested_fields"]:
      nestedFields.add(toFieldDecl(nf))
  FieldDecl(
    name: node["name"].getStr,
    typeName: node["type_name"].getStr,
    isAnonymous: node{"is_anonymous"}.getBool(false),
    nestedFields: nestedFields
  )

proc toTemplateParam*(node: JsonNode): TemplateParam =
  TemplateParam(
    name: node["name"].getStr,
    typeName: if node.hasKey("type_name"): some(node["type_name"].getStr) else: none(string)
  )

proc toStructDecl*(node: JsonNode): StructDecl =
  var fields: seq[FieldDecl]
  for f in node["fields"]:
    fields.add(toFieldDecl(f))

  var templateParams: seq[TemplateParam]
  for t in node{"template_params"}:
    templateParams.add(toTemplateParam(t))

  var baseTypes: seq[string]
  for b in node{"base_types"}:
    baseTypes.add(b.getStr)

  var underlyingDeps: seq[string]
  for d in node{"underlying_deps"}:
    underlyingDeps.add(d.getStr)

  StructDecl(
    name: node["name"].getStr,
    fullyQualified: node["fully_qualified"].getStr,
    fields: fields,
    baseTypes: baseTypes,
    templateParams: templateParams,
    isIncomplete: node{"is_incomplete"}.getBool(false),
    isUnion: node{"is_union"}.getBool(false),
    comment: jsonToOpt(node{"comment"}),
    underlyingDeps: underlyingDeps
  )

proc toClassDecl*(node: JsonNode): ClassDecl =
  var fields: seq[FieldDecl]
  for f in node["fields"]:
    fields.add(toFieldDecl(f))

  var templateParams: seq[TemplateParam]
  for t in node{"template_params"}:
    templateParams.add(toTemplateParam(t))

  var baseTypes: seq[string]
  for b in node{"base_types"}:
    baseTypes.add(b.getStr)

  ClassDecl(
    name: node["name"].getStr,
    fullyQualified: node["fully_qualified"].getStr,
    fields: fields,
    baseTypes: baseTypes,
    templateParams: templateParams,
    comment: jsonToOpt(node{"comment"})
  )

proc toMethodDecl*(node: JsonNode): MethodDecl =
  var params: seq[Parameter]
  for p in node["params"]:
    params.add(toParameter(p))

  var resultDeps: seq[string]
  for d in node{"result_deps"}:
    resultDeps.add(d.getStr)

  MethodDecl(
    name: node["name"].getStr,
    fullyQualified: node["fully_qualified"].getStr,
    className: node["class_name"].getStr,
    returnType: node["return_type"].getStr,
    params: params,
    isConst: node{"is_const"}.getBool(false),
    isStatic: node{"is_static"}.getBool(false),
    isPlainFunction: node{"is_plain_function"}.getBool(false),
    fileOrigin: node{"file_origin"}.getStr(""),
    comment: jsonToOpt(node{"comment"}),
    resultDeps: resultDeps
  )

proc toConstructorDecl*(node: JsonNode): ConstructorDecl =
  var params: seq[Parameter]
  for p in node["params"]:
    params.add(toParameter(p))

  ConstructorDecl(
    name: node["name"].getStr,
    fullyQualified: node["fully_qualified"].getStr,
    className: node["class_name"].getStr,
    params: params,
    comment: jsonToOpt(node{"comment"})
  )

proc toTypedefDecl*(node: JsonNode): TypedefDecl =
  var params: seq[Parameter]
  for p in node{"params"}:
    params.add(toParameter(p))

  var underlyingDeps: seq[string]
  for d in node{"underlying_deps"}:
    underlyingDeps.add(d.getStr)

  TypedefDecl(
    name: node["name"].getStr,
    fullyQualified: node["fully_qualified"].getStr,
    underlying: node["underlying"].getStr,
    typedefKind: jsonToOpt(node{"typedef_kind"}),
    params: params,
    resultType: jsonToOpt(node{"result_type"}),
    underlyingDeps: underlyingDeps,
    structData: if node.hasKey("struct_data"): some(toStructDecl(node["struct_data"])) else: none(StructDecl),
    enumData: if node.hasKey("enum_data"): some(toEnumDecl(node["enum_data"])) else: none(EnumDecl)
  )

proc toEnumDup*(node: JsonNode): EnumDup =
  EnumDup(
    original: node["original"].getStr,
    duplicate: node["duplicate"].getStr
  )

proc toParsedHeader*(node: JsonNode): ParsedHeader =
  var enums: seq[EnumDecl]
  for e in node{"enums"}:
    enums.add(toEnumDecl(e))

  var structs: seq[StructDecl]
  for s in node{"structs"}:
    structs.add(toStructDecl(s))

  var classes: seq[ClassDecl]
  for c in node{"classes"}:
    classes.add(toClassDecl(c))

  var methods: seq[MethodDecl]
  for m in node{"methods"}:
    methods.add(toMethodDecl(m))

  var constructors: seq[ConstructorDecl]
  for c in node{"constructors"}:
    constructors.add(toConstructorDecl(c))

  var typedefs: seq[TypedefDecl]
  for t in node{"typedefs"}:
    typedefs.add(toTypedefDecl(t))

  var constants: seq[EnumDecl]
  for c in node{"constants"}:
    constants.add(toEnumDecl(c))

  var enumDups: seq[EnumDup]
  for e in node{"enum_dups"}:
    enumDups.add(toEnumDup(e))

  var dependencies: HashSet[string]
  for d in node{"dependencies"}:
    dependencies.incl(d.getStr)

  var provides: HashSet[string]
  for p in node{"provides"}:
    provides.incl(p.getStr)

  var missing: HashSet[string]
  for m in node{"missing"}:
    missing.incl(m.getStr)

  ParsedHeader(
    filename: node["filename"].getStr,
    enums: enums,
    structs: structs,
    classes: classes,
    methods: methods,
    constructors: constructors,
    typedefs: typedefs,
    constants: constants,
    enumDups: enumDups,
    dependencies: dependencies,
    provides: provides,
    missing: missing
  )

proc toParseResult*(node: JsonNode): ParseResult =
  var headers: Table[string, ParsedHeader]
  for k, v in node["headers"]:
    headers[k] = toParsedHeader(v)

  var allDependencies: Table[string, HashSet[string]]
  for k, v in node{"all_dependencies"}:
    var deps: HashSet[string]
    for d in v:
      deps.incl(d.getStr)
    allDependencies[k] = deps

  var allProvides: Table[string, HashSet[string]]
  for k, v in node{"all_provides"}:
    var prov: HashSet[string]
    for p in v:
      prov.incl(p.getStr)
    allProvides[k] = prov

  var allMissing: Table[string, HashSet[string]]
  for k, v in node{"all_missing"}:
    var miss: HashSet[string]
    for m in v:
      miss.incl(m.getStr)
    allMissing[k] = miss

  ParseResult(
    headers: headers,
    allDependencies: allDependencies,
    allProvides: allProvides,
    allMissing: allMissing
  )


# Legacy dict format conversion (for Python interop)

proc toLegacyDict*(e: EnumDecl): JsonNode =
  ## Convert to legacy dict format for Python compatibility.
  var items = newJArray()
  for item in e.items:
    items.add(%*{"name": item.name, "value": item.value, "comment": optToJson(item.comment)})
  %*{
    "name": e.name,
    "type": e.underlyingType,
    "comment": optToJson(e.comment),
    "items": items
  }

proc fromLegacyEnumDict*(name: string, data: JsonNode): EnumDecl =
  ## Create from legacy dict format.
  var items: seq[EnumItem]
  for item in data{"items"}:
    items.add(EnumItem(
      name: item["name"].getStr,
      value: item["value"].getInt,
      comment: jsonToOpt(item{"comment"})
    ))
  EnumDecl(
    name: data{"name"}.getStr(name),
    fullyQualified: name,
    underlyingType: data{"type"}.getStr("int"),
    items: items,
    comment: jsonToOpt(data{"comment"})
  )

proc toLegacyDict*(f: FieldDecl): JsonNode =
  ## Convert to legacy dict format.
  result = %*{"name": f.name, "type": f.typeName}
  if f.isAnonymous:
    result["is_anonymous"] = %true
  if f.nestedFields.len > 0:
    var nested = newJArray()
    for nf in f.nestedFields:
      nested.add(toLegacyDict(nf))
    result["nested_fields"] = nested

proc fromLegacyFieldDict*(data: JsonNode): FieldDecl =
  ## Create from legacy dict format.
  var nestedFields: seq[FieldDecl]
  if data.hasKey("nested_fields"):
    for nf in data["nested_fields"]:
      nestedFields.add(fromLegacyFieldDict(nf))
  FieldDecl(
    name: data{"name"}.getStr(""),
    typeName: data{"type"}.getStr(""),
    isAnonymous: data{"is_anonymous"}.getBool(false),
    nestedFields: nestedFields
  )

proc toLegacyDict*(s: StructDecl): JsonNode =
  ## Convert to legacy dict format.
  var fields = newJArray()
  for f in s.fields:
    fields.add(toLegacyDict(f))

  var templateParams = newJArray()
  for t in s.templateParams:
    if t.typeName.isSome:
      templateParams.add(%*[t.name, t.typeName.get])
    else:
      templateParams.add(%t.name)

  %*{
    "name": s.name,
    "fully_qualified": s.fullyQualified,
    "fields": fields,
    "base": %s.baseTypes,
    "template_params": templateParams,
    "incomplete": s.isIncomplete,
    "is_union": s.isUnion,
    "comment": optToJson(s.comment),
    "underlying_deps": %s.underlyingDeps
  }

proc fromLegacyStructDict*(name: string, data: JsonNode): StructDecl =
  ## Create from legacy dict format.
  var fields: seq[FieldDecl]
  for f in data{"fields"}:
    fields.add(fromLegacyFieldDict(f))

  var templateParams: seq[TemplateParam]
  for t in data{"template_params"}:
    if t.kind == JArray:
      templateParams.add(TemplateParam(name: t[0].getStr, typeName: some(t[1].getStr)))
    else:
      templateParams.add(TemplateParam(name: t.getStr))

  var baseTypes: seq[string]
  for b in data{"base"}:
    baseTypes.add(b.getStr)

  var underlyingDeps: seq[string]
  for d in data{"underlying_deps"}:
    underlyingDeps.add(d.getStr)

  StructDecl(
    name: data{"name"}.getStr(name),
    fullyQualified: data{"fully_qualified"}.getStr(name),
    fields: fields,
    baseTypes: baseTypes,
    templateParams: templateParams,
    isIncomplete: data{"incomplete"}.getBool(false),
    isUnion: data{"is_union"}.getBool(false),
    comment: jsonToOpt(data{"comment"}),
    underlyingDeps: underlyingDeps
  )

proc toLegacyDict*(m: MethodDecl): JsonNode =
  ## Convert to legacy dict format.
  var params = newJArray()
  for p in m.params:
    params.add(%*[p.name, p.typeName, optToJson(p.defaultValue)])

  %*{
    "name": m.name,
    "fully_qualified": m.fullyQualified,
    "class_name": m.className,
    "result": m.returnType,
    "params": params,
    "const_method": m.isConst,
    "static_method": m.isStatic,
    "plain_function": m.isPlainFunction,
    "file_origin": m.fileOrigin,
    "comment": optToJson(m.comment),
    "result_deps": %m.resultDeps
  }

proc fromLegacyMethodDict*(name: string, data: JsonNode): MethodDecl =
  ## Create from legacy dict format.
  var params: seq[Parameter]
  for p in data{"params"}:
    let defaultVal = if p.len > 2 and p[2].kind != JNull: some(p[2].getStr) else: none(string)
    params.add(Parameter(name: p[0].getStr, typeName: p[1].getStr, defaultValue: defaultVal))

  var resultDeps: seq[string]
  for d in data{"result_deps"}:
    resultDeps.add(d.getStr)

  MethodDecl(
    name: data{"name"}.getStr(name),
    fullyQualified: data{"fully_qualified"}.getStr(name),
    className: data{"class_name"}.getStr(""),
    returnType: data{"result"}.getStr("void"),
    params: params,
    isConst: data{"const_method"}.getBool(false),
    isStatic: data{"static_method"}.getBool(false),
    isPlainFunction: data{"plain_function"}.getBool(false),
    fileOrigin: data{"file_origin"}.getStr(""),
    comment: jsonToOpt(data{"comment"}),
    resultDeps: resultDeps
  )
