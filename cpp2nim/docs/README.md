# cpp2nim - C++ to Nim Binding Generator

Generate Nim bindings from C++ headers using libclang.

## Quick Start

Generate Nim bindings from C++ headers in 3 steps:

1. **Parse** - Extract declarations from C++ headers using libclang
2. **Export** - Generate Nim binding code with proper imports
3. **Post-process** - Apply text fixups for edge cases

## Minimal Example

```python
from cpp2nim.parse_headers import do_parse
from cpp2nim.analize import export_nim, export_nim_option

# Step 1: Parse headers
do_parse(
    root="/path/to/library/include",
    folders=["/path/to/library/include/*.h"],
    dest="output_gen",
    search_paths=["/path/to/library/include"],
    extra_args=["-I/some/other/include"]
)

# Step 2: Generate Nim bindings
export_nim(
    dest="mylib",           # Library name prefix
    parsed="output_gen",    # Directory from do_parse
    output="output_gen/mylib",  # Output directory
    root="/path/to/library/include"
)
```

## Complete Example (BGFX-style)

```python
import subprocess
import shutil
from cpp2nim.parse_headers import do_parse
from cpp2nim.analize import export_nim, export_nim_option
from cpp2nim.tool import sub_in_file

# Configuration
output = "bgfx_gen"
target = "nimbgfx"
root = "/path/to/bgfx/include"

# List header files to parse
folders = [
    root + "/bgfx/bgfx.h",
    root + "/bgfx/defines.h",
    root + "/bgfx/platform.h",
]

search_paths = [root]

# Additional clang compiler arguments
extra_args = [
    '-isysroot', '/path/to/SDK',
    '-I.',
    '-DSOME_DEFINE=0'
]

# Step 1: Parse headers
do_parse(root, folders, output, search_paths=search_paths, extra_args=extra_args)

# Step 2: Configure export options
ignore = []  # Types to skip
inheritable = ["AllocatorI"]  # Types to mark as inheritable
varargs = ["bgfx::dbgTextPrintf"]  # Varargs functions

nim_output = f'{output}/{target}'
export_nim_option({'root_namespace': 'bgfx'})
export_nim(target, output, nim_output, root, ignore=ignore, 
           inheritable=inheritable, varargs=varargs)

# Step 3: Copy support files
shutil.copy("wrapping_tools.nim", f"{nim_output}/wrapping_tools.nim")
shutil.copy("builtin_types.nim", f"{nim_output}/builtin_types.nim")

# Step 4: Post-process fixes
outputReplaces = [
    ('ptr Memory', 'ConstPtr[Memory]', 'plain'),
    ('ptr Enum.NULL', 'nil', 'plain'),
]
sub_in_file(f"{nim_output}/bgfx.nim", outputReplaces, 'plain')

# Step 5: Verify (optional)
subprocess.call(["nim", "cpp", "-r", f'{nim_output}/test.nim'])
```

## Common Options

### do_parse() Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `root` | `str` | Root directory for headers | `"/usr/include/mylib"` |
| `folders` | `list[str]` | Header files or glob patterns | `["/usr/include/*.h"]` |
| `dest` | `str` | Output directory for parsed data | `"output_gen"` |
| `search_paths` | `list[str]` | Include directories for clang | `["/usr/include"]` |
| `extra_args` | `list[str]` | Additional clang arguments | `["-std=c++17"]` |
| `enum_to_const` | `list[str]` | Enum prefixes to treat as constants | `["MyFlags_"]` |
| `c_mode` | `bool` | Parse as C instead of C++ | `False` |

### export_nim() Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `dest` | `str` | Library name prefix | `"mylib"` |
| `parsed` | `str` | Directory from do_parse | `"output_gen"` |
| `output` | `str` | Output directory for Nim files | `"output_gen/mylib"` |
| `root` | `str` | Root path for header references | `"/usr/include/mylib"` |
| `ignore` | `dict\|list` | Types to skip during export | `["InternalStruct"]` |
| `inheritable` | `dict\|list` | Types to mark as inheritable | `["BaseClass"]` |
| `varargs` | `list` | Functions to mark as varargs | `["printf"]` |
| `rename` | `dict` | Manual type renames | `{"OldName": "NewName"}` |

### export_nim_option() Parameters

Set global options before calling export_nim:

```python
export_nim_option({
    'root_namespace': 'bgfx'  # Namespace to strip from type names
})
```

## Post-Processing (sub_in_file)

The `sub_in_file` function applies text replacements to generated files:

```python
from cpp2nim.tool import sub_in_file

# Tuple format: (pattern, replacement, mode)
# mode = "plain" (literal) or "regex" (regex pattern)
replacements = [
    # Literal replacement
    ('ptr int', 'ptr cint', 'plain'),
    
    # Regex replacement
    (r'(\w+)_Enum', r'\1Bit* = enum', 'regex'),
    
    # Default mode is "regex" if not specified
    ('oldText', 'newText'),
]

sub_in_file("output.nim", replacements)
```

## New Modular API

The refactored package provides a cleaner API for programmatic use:

```python
from cpp2nim import Config, CppHeaderParser

# Create configuration
config = Config(
    search_paths=["/usr/include"],
    extra_args=["-std=c++17"],
    parallel=True,  # Enable multiprocessing
    num_workers=4   # Number of parallel workers
)

# Parse headers
parser = CppHeaderParser(config)
result = parser.parse_files(["/path/to/*.h"])

# Access parsed data
for filename, header in result.headers.items():
    print(f"Parsed {filename}:")
    print(f"  - {len(header.enums)} enums")
    print(f"  - {len(header.structs)} structs")
    print(f"  - {len(header.classes)} classes")
    print(f"  - {len(header.methods)} methods")
```

## Required Files

Your binding project needs these support files:

1. **wrapping_tools.nim** - Utility macros and types for bindings
2. **builtin_types.nim** - Type definitions for common C++ types

Copy these to your output directory after generating bindings.

## Tips for LLM Agents

1. **Always check generated output** - Run `nim check` on generated files
2. **Use post-processing** - Many edge cases need regex fixups
3. **Test compilation** - Run `nim cpp -r test.nim` to verify
4. **Handle missing types** - Check for `???` placeholder values
5. **Fix const/ptr issues** - Common issues with pointer types
