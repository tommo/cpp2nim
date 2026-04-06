---
name: cpp2nim
description: This skill should be used when the user asks to "generate nim bindings", "wrap C/C++ library", "use cpp2nim", "create bindings for", "parse C headers", "bind mujoco/raylib/sdl to nim", "cpp2nim config", or "troubleshoot bindings". Provides cpp2nim configuration, patterns, and troubleshooting for generating Nim bindings from C/C++ headers.
---

# cpp2nim Binding Generator

Generates Nim bindings from C/C++ headers using libclang. Source at `~/prj/dev/nimlibdev/cpp2nim`.

## Quick Start

```bash
cpp2nim all -c config.json          # full pipeline
cpp2nim all -o bindings/ mylib.h    # single header
```

## Workflow

1. Create `cpp2nim.json` — start with `c_mode`, `headers`, `output_dir`
2. Run `cpp2nim all -c cpp2nim.json`
3. Try compiling: `nim c -c output/mylib.nim`
4. Fix compile errors iteratively:
   - Undefined types → add to `ignore_types` or `type_renames`
   - Platform types → add to `ignore_types` (pointers auto-become `pointer`)
   - Wrong names → add to `type_renames`
   - Types needed across files → add to `force_shared_types`
   - Remaining issues → add `post_fixes` or `patch_files`
5. Re-run cpp2nim after each config change (uses caching, only re-parses if headers changed)
6. Write a small test program importing the bindings to verify linkage

## Config Template

```json
{
  "headers": ["include/*.h"],
  "output_dir": "output",
  "search_paths": ["include"],
  "c_mode": false,
  "camel_case": true,
  "root_namespace": "MyLib",
  "extra_args": ["-std=c++17"],
  "defines": ["MYLIB_STATIC"],
  "type_renames": { "MyLib::OldName": "NewName" },
  "ignore_types": ["std::vector", "std::string", "std::function"],
  "inheritable_types": ["BaseClass"],
  "force_shared_types": ["CommonType"],
  "pre_include_headers": [],
  "patch_files": {},
  "post_fixes": {}
}
```

## Config Options

| Option | Type | Description |
|--------|------|-------------|
| `headers` | `string[]` | Header files/globs to process |
| `output_dir` | `string` | Output directory for .nim files |
| `search_paths` | `string[]` | Include directories (-I paths) |
| `c_mode` | `bool` | Parse as C instead of C++ |
| `camel_case` | `bool` | Convert to camelCase (default: true). Set `false` for C libs with UPPERCASE prefixes |
| `root_namespace` | `string` | Namespace to strip from names |
| `extra_args` | `string[]` | Additional clang arguments |
| `defines` | `string[]` | Preprocessor defines |
| `type_renames` | `object` | Map C++ types to Nim names |
| `ignore_types` | `string[]` | Types to skip. Pointer refs (`ptr IgnoredType`) auto-convert to `pointer` |
| `ignore_fields` | `string[]` | Fields to exclude |
| `inheritable_types` | `string[]` | Types to mark `inheritable` |
| `force_shared_types` | `string[]` | Types for shared_types.nim |
| `pre_include_headers` | `string[]` | Force-include before parsing |
| `patch_files` | `object` | Prepend file content: `{"output.nim": "patch_file.nim"}` |
| `post_fixes` | `object` | Post-generation text replacements |

## Automatic Handling

These cases are handled automatically (no post_fixes needed):

- **`typedef void Foo`** generates opaque `{.incompleteStruct.} = object`
- **Union types** get correct `importc: "union X"` in C mode
- **`camel_case: false`** preserves original identifier casing (first char matters in Nim)
- **Anonymous enums inside typedefs** inherit the typedef name
- **Anonymous enums** skip invalid `importc` pragmas
- **Ignored struct fields** generate `array[N, byte]` padding to maintain ABI
- **Multi-file output** always generates `shared_types.nim` (no duplicate helper types)
- **Typedef'd structs/enums** in C mode use `importc: "Foo"` (no `struct`/`enum` prefix)
- **Opaque handle typedefs** (`typedef struct _Foo_t* Foo`) generate `= pointer`
- **`ptr IgnoredType`** in params/fields auto-converts to `pointer`
- **`unsigned char`** maps to `uint8` (not deprecated `cuchar`)

## Post-fixes

For remaining edge cases:

```json
{
  "post_fixes": {
    "output.nim": [
      {"pattern": "old text", "replacement": "new text", "mode": "plain"},
      {"pattern": "re_pattern", "replacement": "$1_replaced", "mode": "regex"}
    ]
  }
}
```

Modes: `plain`, `plain_one`, `regex`, `regex_one`

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Types resolve to `cint` instead of typedef | `"pre_include_headers": ["types.h"]` |
| Template types cause errors | Add to `ignore_types`, define manually in `patch_files` |
| Header not found | Add parent dir to `search_paths` |
| macOS sysroot issues | `"extra_args": ["-isysroot", "/path/to/SDK"]` |
| Duplicate enum values (aliases) | Still needs post_fixes to comment out alias |

## Known Limitations

- Template struct fields may be lost (use `patch_files`)
- Template instantiation aliases (`using Foo = Bar<int>`) not extracted
- Macro-generated types invisible to libclang (use `patch_files`)
- Duplicate enum values (same int for two names) need manual fixup
