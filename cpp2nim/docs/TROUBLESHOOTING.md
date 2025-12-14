# cpp2nim Troubleshooting Guide

Common issues and solutions when generating Nim bindings from C++ headers.

## Parsing Issues

### libclang not found

**Error:**
```
ImportError: libclang.so: cannot open shared object file
```

**Solution:**
Install libclang and set the library path:

```bash
# macOS
brew install llvm
export DYLD_LIBRARY_PATH=/usr/local/opt/llvm/lib

# Linux
apt install libclang-dev
export LD_LIBRARY_PATH=/usr/lib/llvm-14/lib
```

Or set it in Python:
```python
import clang.cindex
clang.cindex.Config.set_library_path('/path/to/libclang')
```

---

### Missing system headers

**Error:**
```
fatal error: 'stddef.h' file not found
```

**Solution:**
Add the system SDK path to extra_args:

```python
extra_args = [
    # macOS
    '-isysroot', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk',
    
    # Or use xcrun to find it
    # '-isysroot', subprocess.check_output(['xcrun', '--show-sdk-path']).decode().strip(),
]
```

---

### Parsing takes too long

**Problem:** Large header sets take several minutes to parse.

**Solution:**
1. Enable multiprocessing (default in new API):
   ```python
   config = Config(parallel=True, num_workers=4)
   ```

2. Parse only needed headers:
   ```python
   folders = [
       root + "/main_api.h",  # Just the public API
       # Not internal headers
   ]
   ```

3. Use precompiled preamble (already enabled):
   ```python
   opts = clang.cindex.TranslationUnit.PARSE_PRECOMPILED_PREAMBLE
   ```

---

## Generation Issues

### Type conversion errors

**Problem:** `???` placeholder values in generated code.

**Solution:**
Check for complex default values that couldn't be parsed:

```python
# Post-processing to fix unknown defaults
replacements = [
    ('= ???', '= 0', 'plain'),
    ('cfloat = ???', 'cfloat = 0.0f', 'plain'),
    ('scale_min: cfloat = ???', 'scale_min: cfloat = FLT_MIN', 'plain'),
]
sub_in_file(output_file, replacements, 'plain')
```

---

### Nim keyword conflicts

**Problem:** Generated code uses Nim reserved words.

**Solution:**
The generator automatically escapes keywords with backticks. If you see issues:

```python
replacements = [
    ('type:', '`type`:', 'plain'),
    ('proc:', '`proc`:', 'plain'),
    ('iterator:', '`iterator`:', 'plain'),
]
```

---

### Missing type definitions

**Problem:** Types referenced but not defined.

**Solution:**
1. Check if the type is in another header:
   ```python
   folders = [
       root + "/types.h",  # Add type definitions first
       root + "/api.h",
   ]
   ```

2. Add to `builtin_types.nim`:
   ```nim
   type
     MissingType* = object
   ```

3. Use type renames:
   ```python
   rename = {
       "missing::Type": "ExistingType"
   }
   ```

---

### Pointer type issues

**Problem:** Wrong pointer types in generated code.

**Solution:**
Post-process to fix:

```python
replacements = [
    # Fix C++ to Nim pointer types
    ('ptr int', 'ptr cint', 'plain'),
    ('ptr unsigned int', 'ptr cuint', 'plain'),
    ('ptr float', 'ptr cfloat', 'plain'),
    ('ptr unsigned char', 'ptr uint8', 'plain'),
    
    # Fix const pointers
    ('ptr Memory', 'ConstPtr[Memory]', 'plain'),
]
```

---

### Template type issues

**Problem:** Template types not converting correctly.

**Solution:**
```python
replacements = [
    # Fix vector types
    (r'vector\[(\w+) \*\]', r'vector[ptr \1]', 'regex'),
    
    # Fix map types
    (r'map\[(\w+), (\w+)\]', r'Table[\1, \2]', 'regex'),
]
```

---

## Compilation Issues

### Import pragma wrong

**Problem:** `importc` used for C++ code.

**Solution:**
```python
replacements = [
    ('{.importc:', '{.importcpp:', 'plain'),
    ('{.importc: "NS::func".}', '{.importcpp: "NS::func".}', 'plain'),
]
```

---

### Constructor issues

**Problem:** Constructor doesn't work correctly.

**Solution:**
Ensure the constructor pragma is correct:

```nim
# Correct
proc newMyClass*(): MyClass {.constructor, importcpp: "MyClass()".}

# With parameters
proc newMyClass*(x: cint): MyClass {.constructor, importcpp: "MyClass(@)".}
```

---

### Method binding issues

**Problem:** Methods not calling correctly.

**Solution:**
Check the importcpp pattern:

```nim
# Instance method
proc myMethod*(self: ptr MyClass): cint {.importcpp: "#.myMethod()".}

# With parameters
proc myMethod*(self: ptr MyClass, x: cint) {.importcpp: "#.myMethod(@)".}

# Static method
proc staticMethod*(): cint {.importcpp: "MyClass::staticMethod()".}
```

---

### Operator overloading

**Problem:** Operators not working.

**Solution:**
Use the correct operator syntax:

```nim
proc `[]`*(self: ptr MyVector, idx: cint): cint {.importcpp: "#[#]".}
proc `+=`*(self: ptr MyVec, other: MyVec) {.importcpp: "# += #".}
proc `==`*(a, b: MyType): bool {.importcpp: "# == #".}
```

---

## Common Post-Processing Fixes

### Fix float literals

```python
replacements = [
    ('0.f', '0.0f', 'plain'),
    ('1.f', '1.0f', 'plain'),
]
```

### Fix nil defaults

```python
replacements = [
    ('ccstring = nil', 'ccstring = ccstring(nil)', 'plain'),
    ('= NULL', '= nil', 'plain'),
]
```

### Comment out problematic lines

```python
replacements = [
    ('proc problematicProc*', '# proc problematicProc*', 'plain'),
    ('type InternalType*', '# type InternalType*', 'plain'),
]
```

### Fix array parameters

```python
replacements = [
    (': array[', ': var array[', 'plain'),  # Arrays should be var
]
```

### Fix size_t issues

```python
replacements = [
    ('sizeof(float)', 'sizeof(cfloat).cint', 'plain'),
    ('sizeof(int)', 'sizeof(cint).cint', 'plain'),
]
```

---

## Verification Steps

### 1. Check syntax

```bash
nim check output/mylib.nim
```

### 2. Run compilation

```bash
nim cpp -c output/mylib.nim
```

### 3. Run test file

```bash
nim cpp -r output/test.nim
```

### 4. Compare with baseline

```bash
diff -r previous_output/ current_output/
```

---

## Getting Help

1. **Check clang output:** Run clang directly to see parsing errors:
   ```bash
   clang++ -fsyntax-only -I/path/to/include header.h
   ```

2. **Enable debug logging:**
   ```python
   import logging
   logging.basicConfig(level=logging.DEBUG)
   ```

3. **Examine parsed data:**
   ```python
   import pickle
   with open("output_gen/data.pkl", "rb") as f:
       data, depends_on, provides, missing = pickle.load(f)
   print(f"Parsed {len(data)} items")
   ```

4. **Inspect specific items:**
   ```python
   for item in data:
       if item[1] == "class":
           print(f"Class: {item[2]}")
   ```
