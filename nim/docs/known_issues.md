# Known Issues & Limitations

## Known Limitations

### Template Struct Fields
Template struct fields that use template parameters may not be emitted. The struct is treated as incomplete/opaque. Use `patch_files` to manually define the template type with its fields.

### Nested Template Typedefs
Template member typedefs like `typedef T value_type` generate incorrectly (e.g., `value_type* = T` where T is not in scope). These are skipped or need manual handling.

### Template Instantiation Aliases
C++ `using` / `typedef` aliases for template instantiations (e.g., `using Vec3f = Vec3<float>`) are not extracted. Define manually in patch files.

### Macro-Generated Types
Types created by C preprocessor macros (e.g., `DEFINE_HANDLE(Foo)`) may not be visible to libclang after preprocessing. Use `patch_files` to declare them.

### Duplicate Enum Values
When two enum members have the same integer value (aliases), Nim's `enum` rejects them. These need `post_fixes` to comment out the alias.

### Operator Overloading
Limited support for C++ operator overloads. Complex operators may need manual binding.

## See Also

- `BUGS.md` — detailed bug reports with repro steps and workarounds
