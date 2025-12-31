# Advanced Example

Complex cpp2nim usage with inheritance, templates, multiple files, and dependency resolution.

## Input Files

### `vehicle.h`
Base classes and templates:
- `Vehicle` - abstract base class with virtual methods
- `Car` - derived class
- `Container<T>` - template class
- `VehicleList` - typedef for Container<Vehicle*>

### `engine.h`
Depends on vehicle.h:
- `EngineType` enum
- `EngineSpecs` struct
- `Motorcycle` - another derived class
- `createVehicle<T>` - factory template with specializations
- `Fleet` - manager using Container template

## Configuration Features

`config.json` demonstrates:
- `inheritable_types`: Mark Vehicle as inheritable (generates RootObj)
- `force_shared_types`: Put common types in shared module
- `ignore_types`: Skip std:: types (use Nim equivalents)
- `ignore_fields`: Exclude internal fields
- `search_paths`: Include directories for resolving headers
- `parallel`/`num_workers`: Enable parallel parsing

## Running

```bash
# From the examples/advanced directory:
cd examples/advanced

# Run cpp2nim on all headers
../../cpp2nim_cli all --config=config.json vehicle.h engine.h
```

> Note: The CLI currently uses JSON config files. See `config.json`.

## Expected Output

### `output/shared_types.nim`
```nim
# Shared types used across multiple bindings

type
  EngineType* {.importcpp: "Transport::EngineType".} = enum
    gasoline = 0
    diesel = 1
    electric = 2
    hybrid = 3

type
  EngineSpecs* {.importcpp: "Transport::EngineSpecs", header: "engine.h".} = object
    `type`*: EngineType
    horsepower*: cdouble
    fuelEfficiency*: cdouble
```

### `output/vehicle.nim`
```nim
# Auto-generated Nim bindings for vehicle.h

import shared_types

type
  VehicleBase* {.importcpp: "Transport::Vehicle", header: "vehicle.h", inheritable.} = object of RootObj
    model* {.importcpp: "model".}: cstring
    year* {.importcpp: "year".}: cint

proc maxSpeed*(self: VehicleBase): cdouble
  {.importcpp: "#.maxSpeed()", header: "vehicle.h".}

proc getType*(self: VehicleBase): cstring
  {.importcpp: "#.getType()", header: "vehicle.h".}

type
  Car* {.importcpp: "Transport::Car", header: "vehicle.h".} = object of VehicleBase
    numDoors*: cint

proc init*(self: var Car; model: cstring; year, doors: cint)
  {.importcpp: "Transport::Car(@)", header: "vehicle.h".}

proc getDoors*(self: Car): cint
  {.importcpp: "#.getDoors()", header: "vehicle.h".}

type
  GenericContainer*[T] {.importcpp: "Transport::Container<'0>", header: "vehicle.h".} = object

proc add*[T](self: var GenericContainer[T]; item: T)
  {.importcpp: "#.add(@)", header: "vehicle.h".}

proc size*[T](self: GenericContainer[T]): csize_t
  {.importcpp: "#.size()", header: "vehicle.h".}

proc get*[T](self: GenericContainer[T]; index: csize_t): T
  {.importcpp: "#.get(@)", header: "vehicle.h".}

type VehicleList* = GenericContainer[ptr VehicleBase]
```

### `output/engine.nim`
```nim
# Auto-generated Nim bindings for engine.h

import shared_types, vehicle

type
  Motorcycle* {.importcpp: "Transport::Motorcycle", header: "engine.h".} = object of VehicleBase
    engine*: EngineSpecs
    hasSidecar*: bool

proc init*(self: var Motorcycle; model: cstring; year: cint; specs: EngineSpecs)
  {.importcpp: "Transport::Motorcycle(@)", header: "engine.h".}

proc getSidecar*(self: Motorcycle): bool
  {.importcpp: "#.getSidecar()", header: "engine.h".}

proc setSidecar*(self: var Motorcycle; value: bool)
  {.importcpp: "#.setSidecar(@)", header: "engine.h".}

proc createVehicle*[T](model: cstring; year: cint): ptr T
  {.importcpp: "Transport::createVehicle<'*0>(@)", header: "engine.h".}

type
  Fleet* {.importcpp: "Transport::Fleet", header: "engine.h".} = object

proc init*(self: var Fleet; name: cstring)
  {.importcpp: "Transport::Fleet(@)", header: "engine.h".}

proc addVehicle*(self: var Fleet; v: ptr VehicleBase)
  {.importcpp: "#.addVehicle(@)", header: "engine.h".}

proc count*(self: Fleet): csize_t
  {.importcpp: "#.count()", header: "engine.h".}

proc totalMaxSpeed*(self: Fleet): cdouble
  {.importcpp: "#.totalMaxSpeed()", header: "engine.h".}
```

## Dependency Resolution

cpp2nim automatically:
1. Detects that `engine.h` includes `vehicle.h`
2. Generates import statements between modules
3. Places shared types (EngineType, EngineSpecs) in a common module
4. Maintains correct type references across files
