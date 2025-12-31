# Known Issues & Improvement Areas

Collected from real-world testing of cpp2nim on various C++ libraries.

## Fixed Issues

### 1. std::size_t and std library types (Fixed)
- **Problem**: `std::size_t` params showed as empty types
- **Root cause**: `CXType_Elaborated` returned empty when declaration name was empty
- **Fix**: Added fallback to `getTypeSpelling()` in parser.nim
- **File**: `src/cpp2nim/parser.nim`

### 2. Type renames not applied to self parameters (Fixed)
- **Problem**: Methods showed `self: ptr Vector2` instead of `self: ptr Vec2`
- **Root cause**: Rename lookup didn't check fully qualified class names
- **Fix**: Added fallback loop checking rename entries ending with `::className`
- **File**: `src/cpp2nim/generator.nim`

### 3. Template Container Type Order (Fixed)
- **Problem**: `Array<CharacterInfo>` generated as `array[CharacterInfo, Array]` instead of `Array[CharacterInfo]`
- **Root cause**: After processing namespaced templates, a recursive `getNimType()` call was made on the already-processed result (e.g., `Array[Foo]`). The entry guard checked for `]` without `<`, which incorrectly matched the converted template and routed it through C-array handling.
- **Fix**:
  1. Added guard `"<" notin cType` to skip C-array handling for template types
  2. Removed unnecessary recursive `getNimType()` call after template processing (line 181)
- **File**: `src/cpp2nim/generator.nim`, `src/cpp2nim/types.nim`

## Known Limitations

### 2. Forward Declared Types
- **Problem**: Forward declared types like `class Font;` are used but not defined
- **Seen in**: LinaVG (`ptr Font` referenced but Font not generated)
- **Status**: TODO - generate opaque type stubs for forward declarations

### 3. Nested Template Typedefs
- **Problem**: Template member typedefs like `typedef T value_type` generate incorrectly
- **Example**: `value_type* = T` where T is not in scope
- **Seen in**: LinaVG Array<T> class
- **Status**: TODO - skip or properly handle template member typedefs

### 4. C Libraries vs C++ Libraries
Many libraries in the wild are pure C APIs with `extern "C"`:
- flecs (ECS)
- enet (networking)
- Chipmunk2D (physics)
- box2d v3 (physics)
- ufbx (FBX loader)
- cute_framework

These work but don't benefit from C++ class/method binding features.

## Successfully Tested Libraries

| Library | Status | Notes |
|---------|--------|-------|
| RVO2 | ✅ Works | Collision avoidance, namespace handling |
| im3d | ✅ Works | 3D gizmos, namespace + enums |
| polypartition | ✅ Works | Polygon triangulation |
| LinaVG | ⚠️ Partial | Template containers need work |

## Testing Checklist for New Libraries

1. Check if C or C++ (look for classes, namespaces)
2. Check for template containers
3. Check for forward declarations
4. Check for nested typedefs
5. Run `nim check` on generated bindings
6. Test actual compilation with C++ backend
