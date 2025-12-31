## Tests for utils module.

import std/[unittest, options, strutils]
import ../src/cpp2nim/utils

suite "escapeNimKeyword":
  test "escapes keywords":
    check escapeNimKeyword("type") == "`type`"
    check escapeNimKeyword("proc") == "`proc`"
    check escapeNimKeyword("var") == "`var`"
    check escapeNimKeyword("const") == "`const`"
    check escapeNimKeyword("import") == "`import`"

  test "does not escape non-keywords":
    check escapeNimKeyword("myVar") == "myVar"
    check escapeNimKeyword("foo") == "foo"
    check escapeNimKeyword("bar123") == "bar123"

suite "cleanIdentifier":
  test "handles leading underscore":
    check cleanIdentifier("_internal") == "v_internal"
    check cleanIdentifier("_foo") == "v_foo"

  test "escapes keywords after underscore removal":
    check cleanIdentifier("_type") == "v_type"  # Not a keyword after prefix

  test "handles keywords directly":
    check cleanIdentifier("type") == "`type`"
    check cleanIdentifier("proc") == "`proc`"

  test "handles empty string":
    check cleanIdentifier("") == ""

  test "handles normal identifiers":
    check cleanIdentifier("normalName") == "normalName"

suite "cleanTypeName":
  test "removes const prefix":
    check cleanTypeName("const int") == "int"
    check cleanTypeName("const char") == "char"

  test "removes reference suffix":
    check cleanTypeName("int &") == "int"
    check cleanTypeName("const int &") == "int"

  test "removes pointer suffix":
    check cleanTypeName("int *") == "int"
    check cleanTypeName("const char *") == "char"

  test "handles const pointer":
    check cleanTypeName("int const *") == "int"

suite "getTemplateDependencies":
  test "simple template":
    let deps = getTemplateDependencies("std::vector<MyClass>")
    check "std::vector" in deps
    check "MyClass" in deps

  test "multiple template params":
    let deps = getTemplateDependencies("std::map<K, V>")
    check "std::map" in deps
    check "K" in deps
    check "V" in deps

  test "nested templates":
    let deps = getTemplateDependencies("vector<map<int, string>>")
    check "vector" in deps
    check "map" in deps
    check "int" in deps
    check "string" in deps

  test "non-template type":
    let deps = getTemplateDependencies("MyClass")
    check deps == @["MyClass"]

suite "flattenNamespace":
  test "two-part namespace":
    check flattenNamespace("std::vector") == "std_vector"

  test "multi-part namespace":
    check flattenNamespace("boost::asio::ip::tcp") == "ip_tcp"

  test "single name":
    check flattenNamespace("MyClass") == "MyClass"

  test "empty string":
    check flattenNamespace("") == ""

suite "getTemplateParameters":
  test "extracts template params":
    let (name, params) = getTemplateParameters("push_back<T>")
    check name == "push_back"
    check params == "[T]"

  test "handles no template":
    let (name, params) = getTemplateParameters("foo")
    check name == "foo"
    check params == ""

  test "multiple template params":
    let (name, params) = getTemplateParameters("emplace<T, Args>")
    check name == "emplace"
    check params == "[T, Args]"

suite "formatComment":
  test "formats comment with indent":
    let result = formatComment(some("Hello world"), 4)
    check result.startsWith("    ## ")
    check "Hello world" in result

  test "handles none":
    check formatComment(none(string)) == ""

  test "handles empty string":
    check formatComment(some("")) == ""

suite "getRootFromGlob":
  test "glob pattern":
    check getRootFromGlob("/usr/include/*.h") == "/usr/include/"

  test "file path":
    check getRootFromGlob("/path/to/file.h") == "/path/to/"

  test "nested glob":
    check getRootFromGlob("/usr/local/include/**/*.h") == "/usr/local/include/"


when isMainModule:
  echo "Running utils tests..."
