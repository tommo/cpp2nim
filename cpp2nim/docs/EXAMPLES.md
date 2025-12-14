# cpp2nim Examples

Real-world examples demonstrating cpp2nim usage patterns.

## BGFX Graphics Library

Binding generation for the BGFX cross-platform graphics library.

```python
import subprocess
import shutil
from cpp2nim.parse_headers import do_parse
from cpp2nim.analize import export_nim, export_nim_option
from cpp2nim.tool import sub_in_file

# Configuration
output = "bgfx_gen"
target = "nimbgfx"
root = "/path/to/bgfx.cmake/bgfx/include"
bxroot = "/path/to/bgfx.cmake/bx/include"

# Headers to parse
foldersCPP = [
    root + "/bgfx/bgfx.h",
    root + "/bgfx/defines.h",
    root + "/bgfx/platform.h",
    bxroot + "/bx/allocator.h",
]

folders = foldersCPP

search_paths = [
    root,
    bxroot
]

extra_args = [
    '-isysroot', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk',
    '-I.',
    '-DBX_CONFIG_DEBUG=0'
]

# Step 1: Parse headers
do_parse(root, folders, output, search_paths=search_paths, extra_args=extra_args)

# Step 2: Export Nim bindings
ignore = []
inheritable = ["AllocatorI"]
varargs = ["bgfx::dbgTextPrintf"]

nim_output = f'{output}/{target}'
export_nim_option({'root_namespace': 'bgfx'})
export_nim(target, output, nim_output, root, ignore=ignore, 
           inheritable=inheritable, varargs=varargs)

# Step 3: Copy support files
shutil.copy("wrapping_tools.nim", f"{nim_output}/wrapping_tools.nim")
shutil.copy("bgfx_builtin_types.nim", f"{nim_output}/builtin_types.nim")
shutil.copy("bgfx_test.nim", f"{nim_output}/test.nim")

# Step 4: Post-processing fixes
outputReplaces = {
    ('ptr Memory', 'ConstPtr[Memory]', 'plain'),
    ('ptr Enum.NULL', 'nil', 'plain'),
    (
        'proc init*(v_init: Init = {})',
        'proc init*(v_init: Init)',
        'plain'
    ),
    (
        'proc getSupportedRenderers*(v_max: uint8_t = 0, v_enum: ptr Enum = nil)',
        'proc getSupportedRenderers*(v_max: uint8_t = 0, v_enum: ptr RendererType_Enum)',
        'plain'
    ),
}
sub_in_file(f"{nim_output}/bgfx.nim", outputReplaces, 'plain')

# Fix cross-file includes
outputReplaces = {
    ('../../bx/include/', '', 'plain')
}
sub_in_file(f"{nim_output}/nimbgfx_types.nim", outputReplaces, 'plain')

# Fix nil string defaults
outputReplaces = {
    ('ccstring = nil', 'ccstring = nilCCString', 'plain')
}
sub_in_file(f"{nim_output}/allocator.nim", outputReplaces, 'plain')
```

---

## Dear ImGui

Binding generation for the Dear ImGui immediate mode GUI library.

```python
import subprocess
import shutil
from cpp2nim.parse_headers import do_parse
from cpp2nim.analize import export_nim, export_nim_option
from cpp2nim.tool import sub_in_file

# Configuration  
output = "imgui_gen"
target = "nimimgui"
srcRoot = "/path/to/imgui/binding/vendor/deps"
root = srcRoot + "/imgui"

# Headers
foldersCPP = [
    root + "/imgui.h",
    # root + "/imgui_internal.h",  # Optional
]

folders = foldersCPP
search_paths = [root]

extra_args = [
    '-isysroot', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk',
    '-I', root + "/build",
    '-I', root + "/misc",
    '-I.',
    '-DUSE_IMGUI_API',
    '-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS',
    '-DIMGUI_DISABLE_OBSOLETE_KEYIO',
]

# Enums to treat as constants
enum_to_const = [
    # 'ImGuiWindowFlags_',  # Uncomment to convert flags to consts
]

# Step 1: Parse
do_parse(root, folders, output, search_paths=search_paths, 
         extra_args=extra_args, enum_to_const=enum_to_const)

# Step 2: Export
ignore = []
inheritable = []
varargs = []

nim_output = f'{output}/{target}'
export_nim_option({})  # No special options
export_nim(target, output, nim_output, root, ignore=ignore, 
           inheritable=inheritable, varargs=varargs)

# Step 3: Copy support files
shutil.copy("wrapping_tools.nim", f"{nim_output}/wrapping_tools.nim")
shutil.copy("imgui_builtin_types.nim", f"{nim_output}/builtin_types.nim")
shutil.copy("imgui_test.nim", f"{nim_output}/test.nim")

# Step 4: Post-process types file
outputReplaces = {
    # Fix enum naming
    (r'(Im\w*)_.*enum', r'\1Bit* = enum'),
    
    # Fix ImVector pointer types
    (r'ImVector\[(\w+) \*\]', r'ImVector[ptr \1]'),
    
    # Fix underscore variable names
    ('_ =', '_v =', 'plain'),
    
    # Comment out problematic declarations
    ('v_NextFrameFontSizeBase', '#v_NextFrameFontSizeBase', 'plain'),
    ('v_MainScale', '#v_MainScale', 'plain'),
    ('value_type*', '#value_type*', 'plain'),
    ('`iterator`', '#`iterator`', 'plain'),
    
    # Fix pointer types
    ('ptr unsigned int', 'ptr cuint', 'plain'),
    ('ImVector[ImGuiViewport *]', 'ImVector[ptr ImGuiViewport]', 'plain'),
    
    # Comment out problematic types
    ('Stb*', '#Stb*', 'plain'),
    ('mMinimap*', '#mMinimap*', 'plain'),
}
sub_in_file(f"{nim_output}/nimimgui_types.nim", outputReplaces)

# Step 4: Post-process main file
outputReplaces = [
    # Fix default values
    ('scale_min: cfloat = ???', 'scale_min: cfloat = FLT_MIN', 'plain'),
    ('scale_max: cfloat = ???', 'scale_max: cfloat = FLT_MAX', 'plain'),
    
    # Fix ImVec constructors
    ('ImVec2(, ', 'ImVec2(', 'plain'),
    (r'ImVec2\(([-.\\w]+f?), *([-.\\w]+f?)\)', r'ImVec2(x: \\1, y: \\2)'),
    (r'ImVec4\((\\w+), *(\\w+), *(\\w+), *(\\w+)\)', 
     r'ImVec4(x: \\1, y: \\2, z: \\3, w: \\4)'),
    
    # Fix varargs
    (r', *?\\w+: *va_list *\\)(.*){\\.', r')\\1{.varargs, '),
    
    # Fix pointer types
    ('ptr int', 'ptr cint', 'plain'),
    ('0.f', '0.0f', 'plain'),
    
    # Fix import pragmas
    ('{.importc: "ImGui::GetIO".}', '{.importcpp: "ImGui::GetIO".}', 'plain'),
    ('{.importc: "ImGui::GetStyle".}', '{.importcpp: "ImGui::GetStyle".}', 'plain'),
]
sub_in_file(f"{nim_output}/imgui.nim", outputReplaces)

# Step 5: Verify
subprocess.call(["nim", "cpp", "-r", f'{nim_output}/test.nim'])
```

---

## C Library (Plain C)

For C libraries, use `c_mode=True`:

```python
from cpp2nim.parse_headers import do_parse
from cpp2nim.analize import export_nim

# Configuration
output = "mylib_gen"
target = "mylib"
root = "/path/to/mylib/include"

folders = [
    root + "/mylib.h",
    root + "/mylib_types.h",
]

search_paths = [root]

extra_args = [
    '-I.',
]

# Use c_mode for C headers
do_parse(root, folders, output, search_paths=search_paths, 
         extra_args=extra_args, c_mode=True)

export_nim(target, output, f'{output}/{target}', root)
```

---

## Custom Type Renames

When types from different namespaces conflict:

```python
from cpp2nim.parse_headers import do_parse
from cpp2nim.analize import export_nim

# Parse headers
do_parse(root, folders, output, search_paths=search_paths)

# Provide explicit type renames
rename = {
    "namespace1::Color": "Color1",
    "namespace2::Color": "Color2",
    "MyType<int>": "MyIntType",
}

export_nim(target, output, nim_output, root, rename=rename)
```

---

## Progress Callback (New API)

Track parsing progress for large header sets:

```python
from cpp2nim import Config, CppHeaderParser

def on_progress(current: int, total: int, filename: str):
    percent = (current / total) * 100
    print(f"[{percent:.1f}%] Parsed: {filename}")

config = Config(
    search_paths=["/usr/include"],
    parallel=True,
    num_workers=4
)

parser = CppHeaderParser(config)
result = parser.parse_files(
    ["/path/to/headers/*.h"],
    progress_callback=on_progress
)

print(f"Parsed {len(result.headers)} files")
```

---

## Post-Processing Patterns

### Comment Out Problematic Declarations

```python
replacements = [
    ('problematic_type*', '#problematic_type*', 'plain'),
    ('proc badFunc*', '# proc badFunc*', 'plain'),
]
```

### Fix Default Values

```python
replacements = [
    ('= ???', '= 0', 'plain'),  # Unknown default -> 0
    ('ccstring = nil', 'ccstring = ccstring(nil)', 'plain'),
]
```

### Fix Type Names

```python
replacements = [
    ('ptr int', 'ptr cint', 'plain'),
    ('ptr unsigned int', 'ptr cuint', 'plain'),
    ('ptr float', 'ptr cfloat', 'plain'),
]
```

### Convert Enum Patterns

```python
replacements = [
    (r'(\w+)_Enum\*', r'\1*'),  # Remove _Enum suffix
    (r'(\w+)Flags_\*', r'\1Bit*'),  # Flags -> Bit
]
```

### Fix Template Types

```python  
replacements = [
    (r'vector\[(\w+) \*\]', r'vector[ptr \1]'),
    (r'(\w+)\<(\w+)\>', r'\1[\2]'),  # C++ to Nim template syntax
]
```
