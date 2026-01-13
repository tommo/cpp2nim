# cpp2nim

C++ to Nim binding generator using libclang.

## Installation

```bash
nimble install
```

Requires libclang (LLVM) installed on your system.

## Usage

### CLI Commands

```bash
# Full pipeline: parse + generate
cpp2nim all --config=config.json header1.h header2.h

# Parse only (outputs parsed.json)
cpp2nim parse --config=config.json header.h

# Generate from parsed JSON
cpp2nim generate --config=config.json parsed.json
```

### Configuration

Create a `config.json`:

```json
{
  "headers": ["include/*.h"],
  "output_dir": "generated",
  "search_paths": ["include"],
  "defines": ["MYLIB_EXPORT="],
  "c_mode": false,
  "type_renames": {
    "MyNamespace::MyType": "MyNimType"
  },
  "ignore_types": ["std::vector", "std::string"],
  "root_namespace": "MyLib"
}
```

Config keys support both `snake_case` and `camelCase` (e.g., `output_dir` or `outputDir`).
Unknown keys trigger a warning to help catch typos.

### Config Options

| Option | Description |
|--------|-------------|
| `headers` | Header files/globs to process (e.g., `["src/*.h"]`) |
| `output_dir` | Output directory for generated .nim files |
| `search_paths` | Additional include directories (-I paths) |
| `extra_args` | Additional clang compiler arguments |
| `defines` | Preprocessor defines |
| `c_mode` | Parse as C instead of C++ |
| `type_renames` | Map C++ types to Nim names |
| `ignore_types` | Types to skip during generation |
| `ignore_files` | File patterns to ignore |
| `pre_include_headers` | Headers to force-include before parsing (for C libs with typedef deps) |
| `root_namespace` | Namespace to strip from type names |
| `camel_case` | Convert names to camelCase (default: true) |
| `force_shared_types` | Types to always put in shared_types.nim |
| `post_fixes` | Post-generation regex/plain text replacements |
| `patch_files` | Prepend content from patch files to generated files |
| `inheritable_types` | Types to mark with `inheritable` pragma |
| `parallel` | Enable parallel parsing (default: true) |
| `num_workers` | Number of parallel workers |

### Pre-include Headers (C libraries)

Many C libraries expect headers to be included in a specific order. For example, MuJoCo defines typedefs in `mjtnum.h` that other headers use:

```c
// mjtnum.h
typedef double mjtNum;

// mjdata.h (uses mjtNum but doesn't include mjtnum.h)
struct mjData_ {
    mjtNum time;  // Would fail without mjtnum.h
};
```

Use `pre_include_headers` to force-include type definition headers:

```json
{
  "headers": ["mjtnum.h", "mjdata.h"],
  "c_mode": true,
  "pre_include_headers": ["mjtnum.h"]
}
```

This ensures `mjtNum` is defined when parsing `mjdata.h`.

### Patch Files

Prepend content from patch files to generated files. Useful for adding manual type definitions that can't be auto-generated (like C++ templates with non-type parameters):

```json
{
  "patch_files": {
    "shared_types.nim": "patches/shared_types_patch.nim"
  }
}
```

### Post-fixes

Post-fixes are text replacements applied after code generation. They're the primary tool for fixing edge cases the generator doesn't handle automatically.

```json
{
  "post_fixes": {
    "MyClass.nim": [
      {"pattern": "old text", "replacement": "new text", "mode": "plain"}
    ],
    "*.nim": [
      {"pattern": "regex (\\w+)", "replacement": "replaced $1", "mode": "regex"}
    ]
  }
}
```

**Replacement modes:**
- `plain` - Exact string match, replaces all occurrences (fast, use when possible)
- `plain_one` - Exact string match, replaces first occurrence only
- `regex` - Regular expression with capture groups (`$1`, `$2`, etc.), replaces all
- `regex_one` - Regex, replaces first match only

**Common use cases:**

| Problem | Solution |
|---------|----------|
| Wrong type mapping | `{"pattern": "ptr cint", "replacement": "ptr File", "mode": "plain"}` |
| Missing import | `{"pattern": "# Auto-generated", "replacement": "import foo\\n\\n# Auto-generated", "mode": "plain"}` |
| Fix generic syntax | `{"pattern": "array\\[(\\w+), (\\d+)\\]", "replacement": "array[$2, $1]", "mode": "regex"}` |
| Remove duplicate type | `{"pattern": "  MyType\\* \\{[^}]+\\} = object\\n[^\\n]*\\n", "replacement": "", "mode": "regex"}` |
| Add pragma | `{"pattern": "(proc foo\\*[^\\n]*)", "replacement": "$1 {.used.}", "mode": "regex"}` |

**Guidelines:**

1. **Minimize post-fixes** - Each one is technical debt. If you need many, consider improving the generator.

2. **Use `plain` over `regex`** - Plain replacements are faster and less error-prone.

3. **Be specific with patterns** - Include surrounding context to avoid unintended replacements.

4. **Order matters** - Replacements apply in sequence. Put specific patterns before broad ones.

5. **Use `*.nim` sparingly** - File-specific patterns are safer than wildcards.

6. **Test after changes** - Run `nim check` on generated files to verify post-fixes work.

7. **Use `_one` modes for precision** - When you only want to replace the first match.

**Debugging tips:**
- Run with `-v` to see files processed
- Temporarily remove post-fixes to see raw output
- Use regex101.com to test patterns (PCRE flavor)
- Check `\n` in JSON needs escaping as `\\n`

## Examples

See `examples/` for real-world usage:

- `examples/real-world/kissat/` - Kissat SAT solver (pure C)
- `examples/real-world/picosat/` - PicoSAT solver (pure C)
- `examples/real-world/micropather/` - MicroPather A* pathfinding (C++)
- `examples/real-world/ldtkloader/` - LDtk level loader (C++ with templates)
- `examples/real-world/ray_renderer/` - Ray physically-based renderer
- `examples/real-world/rvo2/` - RVO2 collision avoidance library

## Features

- Namespace handling with type renames
- Template type resolution
- `std::size_t`, `std::vector`, etc. support
- Operator overloading
- Constructor/destructor bindings
- Enum and struct field extraction
- Typedef expansion and alias generation (`typedef struct Foo_ Foo;` → `Foo* = Foo_`)
- NTTP (non-type template parameters) support (`T: static int`)
- Dependency ordering between headers
