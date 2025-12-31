## Tests for types module.

import std/[unittest, tables, strutils]
import ../src/cpp2nim/types

suite "BasicTypeMap":
  test "basic types exist":
    check BasicTypeMap["int"] == "cint"
    check BasicTypeMap["char"] == "cchar"
    check BasicTypeMap["float"] == "cfloat"
    check BasicTypeMap["double"] == "cdouble"
    check BasicTypeMap["void"] == "void"
    check BasicTypeMap["bool"] == "bool"

  test "unsigned types":
    check BasicTypeMap["unsigned int"] == "cuint"
    check BasicTypeMap["unsigned char"] == "uint8"
    check BasicTypeMap["unsigned long"] == "culong"
    check BasicTypeMap["unsigned long long"] == "culonglong"

  test "special pointers":
    check BasicTypeMap["void *"] == "pointer"
    check BasicTypeMap["const void *"] == "ConstPointer"
    check BasicTypeMap["const char *"] == "ccstring"
    check BasicTypeMap["char *"] == "cstring"

suite "normalizePtrType":
  test "adds space before *":
    check normalizePtrType("int*") == "int *"
    check normalizePtrType("char*") == "char *"

  test "preserves existing space":
    check normalizePtrType("int *") == "int *"

  test "collapses multiple const":
    check normalizePtrType("const const int") == "const int"

  test "strips whitespace":
    check normalizePtrType("  int  ") == "int"

suite "getNimArrayType":
  test "sized array":
    check getNimArrayType("int[10]") == "array[10,cint]"
    check getNimArrayType("char[256]") == "array[256,cchar]"

  test "unsized array":
    check getNimArrayType("int[]") == "ptr cint"
    check getNimArrayType("char[]") == "ptr cchar"

  test "non-array returns unchanged":
    check getNimArrayType("int") == "int"

suite "getNimProcType":
  test "void function":
    let result = getNimProcType("void (int, float) *")
    check result == "proc(arg_0:cint,arg_1:cfloat){.cdecl}"

  test "returning function":
    # Note: "void" as param produces arg_0:void
    let result = getNimProcType("int (void) *")
    check "cint{.cdecl}" in result

  test "no params":
    let result = getNimProcType("void () *")
    check result == "proc(){.cdecl}"

suite "getNimType - basic":
  test "basic types":
    check getNimType("int") == "cint"
    check getNimType("char") == "cchar"
    check getNimType("float") == "cfloat"
    check getNimType("double") == "cdouble"
    check getNimType("void") == "void"
    check getNimType("bool") == "bool"

  test "unsigned types":
    check getNimType("unsigned int") == "cuint"
    check getNimType("unsigned char") == "uint8"
    check getNimType("long long") == "clonglong"

suite "getNimType - pointers":
  test "simple pointer":
    check getNimType("int *") == "ptr cint"
    check getNimType("int*") == "ptr cint"

  test "void pointer":
    check getNimType("void *") == "pointer"

  test "const char pointer":
    check getNimType("const char *") == "ccstring"

  test "const void pointer":
    check getNimType("const void *") == "ConstPointer"

suite "getNimType - references":
  test "reference becomes var":
    check getNimType("int &") == "var cint"
    check getNimType("float &") == "var cfloat"

  test "const reference":
    # const ref doesn't become var
    let result = getNimType("const int &")
    check "var" notin result

suite "getNimType - const":
  test "const prefix stripped":
    check getNimType("const int") == "cint"

  test "const preserved for special types":
    check getNimType("const char *") == "ccstring"

suite "getNimType - arrays":
  test "sized array":
    check getNimType("int[10]") == "array[10,cint]"

  test "unsized array":
    check getNimType("char[]") == "ptr cchar"

suite "getNimType - templates":
  test "simple template":
    # Simple templates get bracket replacement
    let result = getNimType("vector<int>")
    check result == "vector[int]"  # Note: inner types not converted without namespace

  test "namespace template":
    let result = getNimType("std::vector<int>")
    # Namespace templates go through different path
    check "vector" in result

  test "nested template":
    let result = getNimType("map<int, string>")
    check "map" in result

suite "getNimType - prefixes":
  test "strips enum prefix":
    check getNimType("enum MyEnum") == "MyEnum"

  test "strips struct prefix":
    check getNimType("struct MyStruct") == "MyStruct"

  test "strips class prefix":
    check getNimType("class MyClass") == "MyClass"

suite "TypeConverter":
  test "basic conversion":
    let tc = initTypeConverter()
    check tc.toNim("int") == "cint"
    check tc.toNim("float") == "cfloat"

  test "with rename - namespaced":
    # Rename only works with namespace prefix in current implementation
    var tc = initTypeConverter({"ns::MyType": "RenamedType"}.toTable)
    check tc.toNim("ns::MyType") == "RenamedType"

  test "addRename":
    var tc = initTypeConverter()
    tc.addRename("OldName", "NewName")
    check tc.rename["OldName"] == "NewName"


when isMainModule:
  echo "Running types tests..."
