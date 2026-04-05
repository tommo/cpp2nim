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

## Feature Requests

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
