# cpp2nim Bug Reports & Feature Requests

Found while wrapping [RGFW](https://github.com/ColleagueRiley/RGFW) and [minigamepad](https://github.com/ColleagueRiley/RGFW/blob/main/examples/gamepad/minigamepad.h).

---

## Bugs

### 1. `typedef void Foo` generates `= void`, causing `ptr void` error

**Repro**: `typedef void RGFW_mouse;` in C header.

**Generated**:
```nim
RGFW_mouse* {.importc: "RGFW_mouse".} = void
```

**Problem**: Any usage as `ptr RGFW_mouse` fails with `type 'ptr void' is not allowed`.

**Expected**: Should generate an opaque object type:
```nim
RGFW_mouse* {.incompleteStruct, importc: "RGFW_mouse".} = object
```

**Workaround**: post_fixes to replace the line.

---

### 2. Union types get `importc: "struct X"` instead of `"union X"`

**Repro**: `typedef union RGFW_event { ... } RGFW_event;`

**Generated**:
```nim
RGFW_event* {.union, importc: "struct RGFW_event".} = object
```

**Problem**: C compiler error: `use of 'RGFW_event' with tag type that does not match previous declaration`. The `{.union.}` pragma is correctly added but the importc string says `struct`.

**Expected**:
```nim
RGFW_event* {.union, importc: "RGFW_event".} = object
```
or `importc: "union RGFW_event"`.

**Workaround**: post_fixes `plain_one` replacement.

---

### 3. camelCase conversion lowercases first character, breaking Nim identifiers

**Repro**: C function `RGFW_setClassName` with `camel_case: true` or `false`.

**Generated**: `proc rGFW_setClassName*`

**Problem**: Nim is style-insensitive *except* for the first character. `rGFW_setClassName` ≠ `RGFW_setClassName`. Users must use the lowercase form or it's "undeclared identifier".

**Expected**: The first character of the original C identifier should be preserved. `RGFW_setClassName` should stay `RGFW_setClassName` (or at minimum, the importc-derived Nim name should match the original casing for the first char).

**Workaround**: post_fixes `{"pattern": "proc rGFW_", "replacement": "proc RGFW_", "mode": "plain"}`.

---

### 4. Anonymous enums from macro patterns get unusable names

**Repro**: Common C pattern:
```c
#define RGFW_ENUM(type, name) type name; enum
typedef RGFW_ENUM(u8, RGFW_key) { RGFW_keyA = 'a', ... };
```
After preprocessing this becomes `typedef u8 RGFW_key; enum { ... };` — an anonymous enum.

**Generated**:
```nim
enum (unnamed at RGFW.h:512:9)* {.importc: "enum enum (unnamed at RGFW.h:512:9)".} = enum
```

**Problem**: Not a valid Nim identifier. The `importc` string is also nonsensical.

**Note**: The typedef (`RGFW_key = uint8`) IS correctly generated. The issue is only with the enum type name and its importc.

**Workaround**: post_fixes regex to rename each enum individually.

---

### 5. Ignored struct fields cause sizeof mismatch (no padding)

**Repro**: `mg_gamepad` has a platform-specific `mg_gamepad_src src` field at the end. Adding `mg_gamepad_src` to `ignore_types` causes the field to be silently dropped.

**Problem**: The generated Nim struct is smaller than the C struct. Stack-allocated instances will corrupt memory.

**Expected**: When a field's type is ignored, either:
- (a) Generate a padding `array[N, byte]` placeholder using the known sizeof, or
- (b) Emit a warning that the struct has missing fields and is unsafe to allocate

**Workaround**: Manual patch file or post_fixes to add padding.

---

### 6. Duplicate helper types across multi-module output

**Repro**: Generate bindings for both `RGFW.h` and `minigamepad.h` into the same output dir.

**Problem**: Both `RGFW.nim` and `minigamepad.nim` define:
```nim
type
  ccstring* = cstring
  ConstPointer* = pointer
  ConstPtr*[T] = ptr T
```
Also both define `u8`, `i8`, `u32`, `i32` etc. Importing both modules causes redefinition conflicts.

**Expected**: Either:
- (a) Emit shared types into a `shared_types.nim`, or
- (b) Provide a config option to suppress helper type generation for secondary modules

---

## Fixed

Bugs 1–6 and Features A–D have been fixed in commit 26580b7.

---

## Remaining Bugs

### 7. `ptr IgnoredType` in params/fields becomes dangling reference

**Repro**: RGFW config has `ignore_types: ["wl_display", "wl_surface"]`. Functions with `wl_display *` parameters generate `ptr wl_display` — but the type doesn't exist in the output.

**Expected**: When a type is in `ignore_types` and appears as a pointer in function params or struct fields, automatically replace `ptr IgnoredType` with `pointer` (opaque pointer).

**Workaround**: post_fixes `{"pattern": "ptr wl_display", "replacement": "pointer", "mode": "plain"}`.

---

### 8. Negative or duplicate enum values break Nim enum

**Repro**: ONNX `OrtMemType` has `OrtMemTypeCPU = -1` and `OrtMemTypeCPUOutput = -1` (alias).

**Problem**: Nim enums require strictly ascending values and no duplicates. Negative values are allowed but aliases (two names with the same value) cause a compile error.

**Expected**: Either:
- (a) Emit duplicate enum values as `const` aliases outside the enum, or
- (b) Auto-comment them with a note

**Workaround**: post_fixes to comment out the alias line.

---

### 9. Template struct fields are lost

**Repro**: ray_renderer `color_t<T, N>` has field `T v[N]`, but the generated binding has no fields.

**Problem**: Template struct fields that use template parameters are not emitted (the struct is treated as incomplete/opaque). The field types can't be resolved to concrete types, but for Nim generics they should be emitted as-is.

**Expected**: `color_t*[T; N: static cint] = object` should include `v*: array[N, T]`.

**Workaround**: post_fixes regex to replace the entire type block with hand-written fields.

---

### 10. Template instantiation typedefs/aliases not extracted

**Repro**: ray_renderer has `using color_rgba_t = color_t<float, 4>;` (or C++ `typedef`).

**Problem**: These type aliases for template instantiations are not extracted by the parser, so users must manually define them.

**Expected**: Generate `type color_rgba_t* = color_t[cfloat, 4]`.

**Workaround**: post_fixes to inject the aliases manually.

---

### 11. Macro-generated types invisible to libclang

**Repro**: ray_renderer uses `DEFINE_HANDLE(CameraHandle)` macro that expands to a struct definition. After preprocessing, the struct exists but libclang sometimes doesn't expose it as a named type.

**Problem**: Types created by macros like `DEFINE_HANDLE`, `DECLARE_OPAQUE`, etc. are not captured by the parser.

**Expected**: Either:
- (a) Add an `extra_types` config option for users to manually declare types that are invisible to clang, or
- (b) Improve parsing to pick up macro-expanded struct definitions

**Workaround**: post_fixes regex to inject the type definitions.

---

### 12. C mode importc adds unnecessary `struct`/`enum` prefix for typedef'd types

**Repro**: SimpleBLE (`simpleble_adapter_t`), CameraCapture (`ccap_*`), Steam Audio (`IPL*`). In C, `typedef struct { ... } Foo;` makes `Foo` a standalone type name — no `struct` prefix needed.

**Generated**:
```nim
Foo* {.importc: "struct Foo".} = object
Bar* {.importc: "enum Bar".} = enum
```

**Problem**: Many C compilers accept this, but it's technically wrong for typedef'd types, and it causes issues with some toolchains.

**Expected**: For typedef'd structs/enums, use `importc: "Foo"` without the `struct`/`enum` prefix.

**Workaround**: post_fixes `{"pattern": "importc: \"struct ", "replacement": "importc: \"", "mode": "plain"}` — seen in BLE, ccap, and Steam Audio configs.

**Affected configs**: bluetooth/ble, camera/ccap, steam_audio (3 projects, 5 post_fix rules total).

---

### 13. Opaque handle typedefs generate `= ptr _Foo_t` instead of `= pointer`

**Repro**: Steam Audio has `typedef struct _IPLContext_t* IPLContext;` — an opaque handle typedef pointing to a forward-declared struct.

**Generated**:
```nim
IPLContext* = ptr _IPLContext_t
```

**Problem**: `_IPLContext_t` is never defined (forward-declared only), so the generated code references a nonexistent type. This is a very common C API pattern for opaque handles.

**Expected**: When the underlying struct is forward-declared only (no definition), generate `= pointer` instead.

**Workaround**: 30 individual post_fixes in Steam Audio config, each replacing `= ptr _IPLFoo_t` with `= pointer`.

---

### 14. Functions missing dynlib/cdecl pragmas for runtime-loaded libraries

**Repro**: OpenXR functions are loaded at runtime via `xrGetInstanceProcAddr`. The generated `importc` only does link-time binding.

**Generated**:
```nim
proc xrCreateInstance*(...) {.importc: "xrCreateInstance".}
```

**Expected**: Support a config option like `"dynlib"` or `"calling_convention"` to add pragmas:
```nim
proc xrCreateInstance*(...) {.cdecl, dynlib: loaderlib, importc: "xrCreateInstance".}
```

**Workaround**: post_fixes regex `{.importc: "(xr...)".}` → `{.cdecl, dynlib: loaderlib, importc: "$1".}`.

---

### 15. `cuchar` deprecation warning — should use `uint8`

**Repro**: Steam Audio fields typed as `unsigned char` generate `cuchar`.

**Problem**: Nim has deprecated `cuchar` in favor of `char`/`uint8`. The generated code produces warnings.

**Expected**: Map `unsigned char` to `uint8` instead of `cuchar`.

**Workaround**: post_fixes `{"pattern": "= cuchar", "replacement": "= uint8"}`.

---

## Feature Requests (New)

### E. Config option `extra_types` for manually declaring opaque types

For macro-generated types (Bug 11), allow users to declare types directly in the config:
```json
"extra_types": {
  "CameraHandle": { "fields": [{"name": "index", "type": "uint32"}, {"name": "blk", "type": "uint32"}] },
  "LightHandle": "opaque"
}
```

### F. Auto-replace `ptr IgnoredType` with `pointer`

When a type is in `ignore_types`, all references to `ptr IgnoredType` in params and fields should automatically become `pointer`. This eliminates the most common post_fixes workaround (Bug 7).

### G. Config option for dynlib/calling convention pragmas

Add `"dynlib"` and `"calling_convention"` config options to inject pragmas on all generated procs:
```json
"dynlib": "loaderlib",
"calling_convention": "cdecl"
```
Would eliminate the most common OpenXR-style workaround (Bug 14).

### H. Strip `struct`/`enum` prefix from importc for typedef'd C types

In C mode, typedef'd types (`typedef struct { ... } Foo;`) should use `importc: "Foo"` without the tag prefix. This is the single most common workaround across all configs — appearing in BLE, ccap, Steam Audio, and RGFW (Bug 12).

### I. Auto-detect opaque handle typedefs

When a typedef points to `ptr _Foo_t` and `_Foo_t` is only forward-declared (no definition), automatically generate `= pointer` instead of referencing the undefined type (Bug 13).

---

## Archived Feature Requests (Fixed)

### A. Enum name inference from adjacent typedef

For the `RGFW_ENUM(type, name)` / `MG_ENUM(type, name)` pattern, the typedef and anonymous enum always appear together:
```c
typedef u8 RGFW_key; enum { RGFW_keyA = 'a', ... };
```

cpp2nim could detect that an anonymous enum immediately follows a typedef, and name the enum `{typedef_name}_enum` automatically (e.g. `RGFW_key_enum`). This is a very common C idiom.

### B. Config option to preserve original identifier casing

Add a config option like `"preserve_case": true` to skip the first-character lowercasing entirely. For C libraries that use `UPPERCASE_prefix` naming (RGFW, SDL, GLFW, etc.), the camelCase conversion actively breaks things.

### C. Config option to skip importc for anonymous/synthetic enums

Anonymous enums have no C tag name, so their `importc` is always wrong. Could auto-detect and omit `importc` for enums that were unnamed in the source.

### D. Struct sizeof validation / padding generation

When `ignore_types` causes struct fields to be dropped, generate `_padding: array[sizeof_from_clang - sizeof_computed, byte]` to maintain ABI compatibility. The size info is already available from libclang.
