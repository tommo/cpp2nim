# C++ Complex Header Test

Tests cpp2nim on a complex C++ header with advanced features.

## Features Tested

- Namespaces (math::)
- Enum classes (Axis)
- Regular enums with flags (TransformFlags)
- Structs with methods and operators (Color)
- Template classes (Vector3<T>)
- Type aliases (Vec3f, Vec3d, Vec3i)
- Inheritance (AnimatedTransform : Transform)
- Virtual functions (toMatrix, apply)
- Static methods (Color::red, Matrix4::identity)
- Operator overloading (+, *, ==, [], ())
- Function pointers / callbacks (UpdateCallback)
- Struct with function pointers (EventHandler)
- Free functions (normalize, dot, cross)
- Constructors with default args

## Results

### What Works
- Enum classes extracted correctly
- Regular enums with values
- Struct fields
- Methods on classes
- Operators (+, *, ==)
- Constructors
- Function pointer typedefs
- Struct with function pointer fields
- Free functions
- Inheritance detected

### Issues Found

1. **Template classes not generated**
   - `Vector3<T>` template class body not output
   - Only typedef aliases reference it
   - Need to add template class support

2. **Inheritance needs RootObj**
   - Base classes with `byref` need `of RootObj` for derived classes
   - `AnimatedTransform of Transform` fails because Transform not inheritable

3. **Type alias with templates confused**
   - `Vec3f[cfloat]` is wrong - typedef shouldn't add params
   - Should be just `Vec3f` referencing `Vector3[float]`

4. **Static methods treated as instance methods**
   - `Color::red()` becomes `red*(self: ptr Color)`
   - Should be standalone or marked static

## Status

**Partially Working** - needs fixes for:
- Template class generation
- Inheritance pragma handling
- Type alias with template instantiation
- Static method detection
