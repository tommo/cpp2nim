# im3d Example

cpp2nim bindings for [im3d](https://github.com/john-googlebots/im3d) - Immediate-mode 3D gizmo/primitive library.

## Generate bindings

```bash
cpp2nim all --config=config.json \
    ~/prj/dev/lib/im3d/im3d.h \
    ~/prj/dev/lib/im3d/im3d_math.h
```

## Features demonstrated

- Namespace handling (`Im3d::`)
- Struct field extraction (Vec2, Vec3, Mat4, etc.)
- Enum generation with proper sizing
- Free function bindings
- va_list/varargs handling (Text functions)
