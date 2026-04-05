## Tests for models module.

import std/[unittest, json, options, tables, sets]
import ../src/cpp2nim/models

suite "Parameter":
  test "init with default":
    let p = initParameter("arg", "int")
    check p.name == "arg"
    check p.typeName == "int"
    check p.defaultValue.isNone

  test "init with default value":
    let p = initParameter("arg", "int", some("0"))
    check p.defaultValue.isSome
    check p.defaultValue.get == "0"

  test "JSON round-trip":
    let p = initParameter("arg", "int", some("0"))
    let j = %p
    let restored = toParameter(j)
    check restored.name == p.name
    check restored.typeName == p.typeName
    check restored.defaultValue == p.defaultValue

suite "EnumItem":
  test "init":
    let item = initEnumItem("VALUE", 42, some("A value"))
    check item.name == "VALUE"
    check item.value == 42
    check item.comment.get == "A value"

  test "JSON round-trip":
    let item = initEnumItem("VALUE", 42, some("doc"))
    let j = %item
    let restored = toEnumItem(j)
    check restored.name == item.name
    check restored.value == item.value
    check restored.comment == item.comment

suite "EnumDecl":
  test "init":
    let items = @[
      initEnumItem("A", 0),
      initEnumItem("B", 1),
      initEnumItem("C", 2)
    ]
    let e = initEnumDecl("MyEnum", "ns::MyEnum", "int", items, some("An enum"))

    check e.name == "MyEnum"
    check e.fullyQualified == "ns::MyEnum"
    check e.underlyingType == "int"
    check e.items.len == 3
    check e.comment.get == "An enum"

  test "JSON round-trip":
    let items = @[initEnumItem("X", 10)]
    let e = initEnumDecl("E", "E", "uint", items)
    let j = %e
    let restored = toEnumDecl(j)
    check restored.name == e.name
    check restored.items.len == 1
    check restored.items[0].value == 10

suite "FieldDecl":
  test "init":
    let f = initFieldDecl("x", "int", false)
    check f.name == "x"
    check f.typeName == "int"
    check f.isAnonymous == false

  test "anonymous field":
    let f = initFieldDecl("data", "union{}", true)
    check f.isAnonymous == true

  test "field with sizeBytes":
    let f = initFieldDecl("data", "MyType", sizeBytes = 16)
    check f.sizeBytes == 16

  test "default sizeBytes is 0":
    let f = initFieldDecl("x", "int")
    check f.sizeBytes == 0

  test "JSON round-trip":
    let f = initFieldDecl("ptr", "void*")
    let j = %f
    let restored = toFieldDecl(j)
    check restored.name == f.name
    check restored.typeName == f.typeName

  test "JSON round-trip with sizeBytes":
    let f = initFieldDecl("data", "MyType", sizeBytes = 24)
    let j = %f
    check j.hasKey("size_bytes")
    check j["size_bytes"].getInt == 24
    let restored = toFieldDecl(j)
    check restored.sizeBytes == 24

suite "TemplateParam":
  test "simple param":
    let t = initTemplateParam("T")
    check t.name == "T"
    check t.typeName.isNone

  test "typed param":
    let t = initTemplateParam("N", some("int"))
    check t.name == "N"
    check t.typeName.get == "int"

  test "JSON round-trip":
    let t = initTemplateParam("T", some("class"))
    let j = %t
    let restored = toTemplateParam(j)
    check restored.name == t.name
    check restored.typeName == t.typeName

suite "StructDecl":
  test "init":
    let fields = @[
      initFieldDecl("x", "int"),
      initFieldDecl("y", "int")
    ]
    let s = initStructDecl("Point", "ns::Point", fields)

    check s.name == "Point"
    check s.fullyQualified == "ns::Point"
    check s.fields.len == 2
    check s.isUnion == false
    check s.isIncomplete == false

  test "union":
    let s = initStructDecl("Data", "Data", @[], isUnion = true)
    check s.isUnion == true

  test "with template params":
    let tparams = @[initTemplateParam("T")]
    let s = initStructDecl("Container", "Container", @[], templateParams = tparams)
    check s.templateParams.len == 1
    check s.templateParams[0].name == "T"

  test "JSON round-trip":
    let fields = @[initFieldDecl("val", "float")]
    let s = initStructDecl("S", "ns::S", fields, baseTypes = @["Base"],
                           isIncomplete = true, comment = some("A struct"))
    let j = %s
    let restored = toStructDecl(j)
    check restored.name == s.name
    check restored.fields.len == 1
    check restored.baseTypes == s.baseTypes
    check restored.isIncomplete == true

suite "ClassDecl":
  test "init":
    let c = initClassDecl("Widget", "ui::Widget",
                          baseTypes = @["Object"],
                          comment = some("A widget"))
    check c.name == "Widget"
    check c.fullyQualified == "ui::Widget"
    check c.baseTypes == @["Object"]

  test "JSON round-trip":
    let c = initClassDecl("C", "C", comment = some("Class"))
    let j = %c
    let restored = toClassDecl(j)
    check restored.name == c.name
    check restored.comment == c.comment

suite "MethodDecl":
  test "init":
    let params = @[initParameter("x", "int")]
    let m = initMethodDecl("foo", "Class::foo", "Class", "void",
                           params, isConst = true)

    check m.name == "foo"
    check m.className == "Class"
    check m.returnType == "void"
    check m.isConst == true
    check m.params.len == 1

  test "plain function":
    let m = initMethodDecl("func", "func", "", "int", isPlainFunction = true)
    check m.isPlainFunction == true
    check m.className == ""

  test "JSON round-trip":
    let m = initMethodDecl("m", "C::m", "C", "bool",
                           fileOrigin = "header.h",
                           resultDeps = @["bool"])
    let j = %m
    let restored = toMethodDecl(j)
    check restored.name == m.name
    check restored.fileOrigin == m.fileOrigin
    check restored.resultDeps == m.resultDeps

suite "ConstructorDecl":
  test "init":
    let params = @[initParameter("val", "int")]
    let c = initConstructorDecl("Widget", "ui::Widget", "Widget", params)

    check c.name == "Widget"
    check c.className == "Widget"
    check c.params.len == 1

  test "JSON round-trip":
    let c = initConstructorDecl("C", "C", "C", comment = some("Ctor"))
    let j = %c
    let restored = toConstructorDecl(j)
    check restored.comment == c.comment

suite "TypedefDecl":
  test "simple typedef":
    let t = initTypedefDecl("MyInt", "MyInt", "int")
    check t.name == "MyInt"
    check t.underlying == "int"
    check t.typedefKind.isNone

  test "function typedef":
    let params = @[initParameter("", "int")]
    let t = initTypedefDecl("Callback", "Callback", "int(*)(int)",
                            typedefKind = some("function"),
                            params = params,
                            resultType = some("int"))

    check t.typedefKind.get == "function"
    check t.params.len == 1
    check t.resultType.get == "int"

  test "JSON round-trip":
    let t = initTypedefDecl("T", "T", "underlying",
                            underlyingDeps = @["dep1", "dep2"])
    let j = %t
    let restored = toTypedefDecl(j)
    check restored.name == t.name
    check restored.underlying == t.underlying
    check restored.underlyingDeps == t.underlyingDeps

suite "ParsedHeader":
  test "init":
    let h = initParsedHeader("test.h")
    check h.filename == "test.h"
    check h.enums.len == 0
    check h.structs.len == 0
    check h.methods.len == 0

  test "JSON round-trip":
    var h = initParsedHeader("header.h")
    h.enums.add(initEnumDecl("E", "E", "int"))
    h.structs.add(initStructDecl("S", "S", @[]))
    h.dependencies.incl("Dep")
    h.provides.incl("S")

    let j = %h
    let restored = toParsedHeader(j)
    check restored.filename == h.filename
    check restored.enums.len == 1
    check restored.structs.len == 1
    check "Dep" in restored.dependencies
    check "S" in restored.provides

suite "ParseResult":
  test "init":
    let r = initParseResult()
    check r.headers.len == 0

  test "JSON round-trip":
    var r = initParseResult()
    r.headers["a.h"] = initParsedHeader("a.h")
    r.allDependencies["a.h"] = ["Foo"].toHashSet
    r.allProvides["a.h"] = ["Bar"].toHashSet

    let j = %r
    let restored = toParseResult(j)
    check "a.h" in restored.headers
    check "Foo" in restored.allDependencies["a.h"]
    check "Bar" in restored.allProvides["a.h"]

suite "Legacy dict format":
  test "EnumDecl toLegacyDict":
    let items = @[initEnumItem("A", 0), initEnumItem("B", 1)]
    let e = initEnumDecl("E", "E", "int", items, some("doc"))
    let legacy = toLegacyDict(e)

    check legacy["name"].getStr == "E"
    check legacy["type"].getStr == "int"
    check legacy["items"].len == 2

  test "fromLegacyEnumDict":
    # Note: items must have explicit null for comment field due to jsonToOpt
    let legacy = %*{
      "name": "E",
      "type": "uint",
      "comment": "An enum",
      "items": [{"name": "X", "value": 10, "comment": newJNull()}]
    }
    let e = fromLegacyEnumDict("E", legacy)

    check e.name == "E"
    check e.underlyingType == "uint"
    check e.items.len == 1
    check e.items[0].value == 10

  test "FieldDecl toLegacyDict":
    let f = initFieldDecl("x", "int", true)
    let legacy = toLegacyDict(f)

    check legacy["name"].getStr == "x"
    check legacy["type"].getStr == "int"
    check legacy["is_anonymous"].getBool == true

  test "StructDecl toLegacyDict":
    let fields = @[initFieldDecl("x", "int")]
    let s = initStructDecl("S", "ns::S", fields,
                           baseTypes = @["Base"],
                           isIncomplete = true)
    let legacy = toLegacyDict(s)

    check legacy["name"].getStr == "S"
    check legacy["fully_qualified"].getStr == "ns::S"
    check legacy["base"].len == 1
    check legacy["incomplete"].getBool == true


when isMainModule:
  echo "Running models tests..."
