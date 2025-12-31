# cpp2nim Test Suite

## Running Tests

```bash
# Using nimble
nimble test

# Or directly with nim
nim c -r tests/test_all.nim

# Verbose mode
nimble testv
```

## Test Modules

| File | Module | Tests |
|------|--------|-------|
| `test_utils.nim` | utils.nim | Keyword escaping, identifier cleaning, template parsing |
| `test_types.nim` | types.nim | Type conversion (C++ → Nim), arrays, pointers, templates |
| `test_config.nim` | config.nim | Config creation, JSON serialization, validation |
| `test_models.nim` | models.nim | Data structures, JSON round-trips, legacy format |

## Test Fixtures

Sample C++ headers in `fixtures/`:

- `sample_enums.h` - Enum declarations (simple, class, anonymous)
- `sample_structs.h` - Structs, classes, unions, templates
- `sample_functions.h` - Functions, methods, callbacks
- `sample_templates.h` - Template classes and specializations

## Coverage

### utils.nim
- `escapeNimKeyword` - Keyword detection and backtick escaping
- `cleanIdentifier` - Underscore prefix handling
- `cleanTypeName` - Const/pointer/reference removal
- `getTemplateDependencies` - Template parameter extraction
- `flattenNamespace` - Namespace to underscore conversion
- `getTemplateParameters` - Method template parsing
- `formatComment` - Doc comment formatting
- `getRootFromGlob` - Glob pattern parsing

### types.nim
- `normalizePtrType` - Pointer spacing normalization
- `getNimArrayType` - Array type conversion
- `getNimProcType` - Function pointer conversion
- `getNimType` - Full type conversion with all features
- `TypeConverter` - Stateful converter with rename support

### config.nim
- `initConfig` / `defaultConfig` - Configuration creation
- `effectiveWorkers` - CPU count resolution
- JSON serialization/deserialization round-trips
- `mergeWith` - Configuration merging
- `validateOrWarn` - Configuration validation

### models.nim
- All model types: Parameter, EnumItem, EnumDecl, FieldDecl, etc.
- JSON serialization for all types
- Legacy dict format conversion for Python interop
