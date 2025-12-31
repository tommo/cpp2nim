# stb_image bindings test

Tests cpp2nim on the real-world stb_image.h single-header library.

## Results

### What Works
- Typedef extraction (stbi_uc, stbi_us -> uint8, cushort)
- Function declarations with correct parameter types
- Constants extraction (STBI_default, STBI_grey, etc.)
- Pointer type conversion (int* -> ptr cint)
- Const char* -> ccstring mapping
- Anonymous typedef structs (stbi_io_callbacks)
- Function pointer fields in structs
- Parse command works

### Remaining Issues

1. **Some functions missing**
   - File-based functions (stbi_load, stbi_info with filename param) not extracted
   - Due to `#ifndef STBI_NO_STDIO` preprocessor guards
   - Fix: Add `-DSTBI_NO_STDIO=0` to config extra_args if needed

### Compilation

No manual fixes required:
```
nim check output/stb_image.nim  # Success
```

## Usage

```bash
cd examples/real-world/stb
cpp2nim all --config=config.json stb_image.h
nim check output/stb_image.nim
```
