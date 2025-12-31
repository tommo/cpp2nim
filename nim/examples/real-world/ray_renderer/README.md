# Ray Renderer Example

This example demonstrates cpp2nim bindings for the [Ray](https://github.com/sergcpp/Ray) physically-based renderer.

## Setup

The `headers/` folder should contain the Ray library headers and built library. This is not included in the repository.

To set up:
1. Clone Ray: `git clone https://github.com/sergcpp/Ray`
2. Build the library following Ray's instructions
3. Copy or symlink the headers and built library to `headers/`

Required structure:
```
headers/
├── Types.h
├── Log.h
├── SceneBase.h
├── RendererBase.h
├── internal/        # Ray internal headers
├── third-party/     # Ray third-party dependencies
└── build/
    └── libRay.a     # Built library
```

## Running

```bash
# Generate bindings
../../../bin/cpp2nim_cli all --config=config.json headers/Types.h headers/Log.h headers/SceneBase.h headers/RendererBase.h

# Build and run example
nim cpp -d:release --passC:"-I./headers -I./headers/build" --passL:"./headers/build/libRay.a" -o:example_bin example.nim
./example_bin
```

This renders a Cornell box scene and saves to `render_output.tga`.
