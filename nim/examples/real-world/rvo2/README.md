# RVO2 Example

cpp2nim bindings for [RVO2](https://github.com/snape/RVO2) - Optimal Reciprocal Collision Avoidance.

## Generate bindings

```bash
cpp2nim all --config=config.json \
    ~/prj/dev/lib/RVO2/src/Vector2.h \
    ~/prj/dev/lib/RVO2/src/Line.h \
    ~/prj/dev/lib/RVO2/src/RVOSimulator.h
```

## Features demonstrated

- Namespace handling (`RVO::`)
- Type renames (`RVO::Vector2` -> `Vec2`)
- `std::size_t` type resolution
- Operator overloading
- Method bindings with proper self parameter types
