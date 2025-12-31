# LinaVG Example

cpp2nim bindings for [LinaVG](https://github.com/inanevin/LinaVG) - Vector Graphics Library.

## Generate

```bash
cpp2nim all --config=config.json \
    ~/prj/dev/lib/LinaVG/include/LinaVG/Core/Vectors.hpp \
    ~/prj/dev/lib/LinaVG/include/LinaVG/Core/Common.hpp
```

## Notes

This library uses template containers (Array<T>) that require further work for proper Nim generic handling.
