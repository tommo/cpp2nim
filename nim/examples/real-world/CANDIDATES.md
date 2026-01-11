# cpp2nim Example Candidates

Libraries to test binding generation. Focus: game/media development.

## Legend
- **Status**: `pending` | `in-progress` | `done` | `skipped`
- **Complexity**: `low` | `medium` | `high` | `massive`

---

# Big Projects (Engines & Frameworks)

## Game Engines

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [raylib](https://github.com/raysan5/raylib) | medium | pending | Simple C game library, 2D/3D, no deps, great docs |
| [Godot godot-cpp](https://github.com/godotengine/godot-cpp) | high | pending | GDExtension C++ bindings, modern C++ |
| [Urho3D](https://github.com/urho3d/urho3d) | massive | pending | Full 2D/3D engine, AngelScript/Lua, networking |
| [LumixEngine](https://github.com/nem0/LumixEngine) | massive | pending | Data-oriented 3D engine, editor included |
| [toy](https://github.com/hugoam/toy) | high | pending | Thin modular C++ engine, ECS, browser editor |
| [Hazel](https://github.com/TheCherno/Hazel) | high | pending | Game engine series by TheCherno, educational |
| [Acid](https://github.com/EQMG/Acid) | high | pending | Vulkan game engine, C++17, modular |
| [Crown](https://github.com/crownengine/crown) | high | pending | General purpose data-driven game engine |
| [Cocos2d-x](https://github.com/cocos2d/cocos2d-x) | massive | pending | Popular 2D game framework, mobile-focused |

## Rendering Engines / Graphics

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [bgfx](https://github.com/bkaradzic/bgfx) | high | pending | Cross-platform, API-agnostic renderer, BYOE |
| [Diligent Engine](https://github.com/DiligentGraphics/DiligentEngine) | massive | pending | Modern cross-platform graphics, D3D12/Vulkan/Metal |
| [The-Forge](https://github.com/ConfettiFX/The-Forge) | massive | pending | AAA cross-platform renderer, console support |
| [Wicked Engine](https://github.com/turanszkij/WickedEngine) | massive | pending | Full engine, DX11/12/Vulkan, open source |
| [OGRE](https://github.com/OGRECave/ogre) | massive | pending | Classic 3D engine since 2001, C++/Python/C# |
| [Magnum](https://github.com/mosra/magnum) | high | pending | Modular C++11 graphics middleware |
| [Filament](https://github.com/google/filament) | massive | pending | Google's PBR renderer, mobile-first |
| [LLGL](https://github.com/LukasBanana/LLGL) | high | pending | Low Level Graphics Library, multi-API |
| [Falcor](https://github.com/NVIDIAGameWorks/Falcor) | massive | pending | NVIDIA real-time rendering framework |

## Physics Engines

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [Jolt Physics](https://github.com/jrouwe/JoltPhysics) | high | pending | Modern physics, Horizon/Death Stranding, C++17 |
| [Bullet3](https://github.com/bulletphysics/bullet3) | massive | pending | Industry standard, VR/games/robotics |
| [ReactPhysics3D](https://github.com/DanielChappuis/reactphysics3d) | medium | pending | Clean 3D physics, C++, well documented |
| [PhysX](https://github.com/NVIDIA-Omniverse/PhysX) | massive | pending | NVIDIA physics, used in UE/Unity |
| [Box2D](https://github.com/erincatto/box2d) | medium | pending | 2D physics, classic, widely used |
| [LiquidFun](https://github.com/google/liquidfun) | medium | pending | Box2D fork with particle fluids |
| [qu3e](https://github.com/RandyGaul/qu3e) | low | pending | Lightweight 3D physics, single-file friendly |
| [Chipmunk2D](https://github.com/slembcke/Chipmunk2D) | medium | pending | Fast 2D physics, C, game-focused |

## Audio Engines

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [SoLoud](https://github.com/jarikomppa/soloud) | medium | pending | Easy C/C++ audio, fire-and-forget, free |
| [OpenAL Soft](https://github.com/kcat/openal-soft) | high | pending | 3D audio API implementation, LGPL |
| [LabSound](https://github.com/LabSound/LabSound) | high | pending | Graph-based audio, WebAudio-like |
| [Resonance Audio](https://github.com/resonance-audio/resonance-audio) | high | pending | Google spatial audio SDK |
| [Steam Audio](https://github.com/ValveSoftware/steam-audio) | high | pending | Valve's 3D audio, HRTF, ray-traced |
| [FAudio](https://github.com/FNA-XNA/FAudio) | medium | pending | XAudio reimplementation, C |
| [libnyquist](https://github.com/ddiakopoulos/libnyquist) | medium | pending | Audio decoding library, C++11 |

## Scripting / Embedding

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [sol2](https://github.com/ThePhD/sol2) | high | pending | C++ Lua bindings, header-only |
| [LuaBridge3](https://github.com/kunitoki/LuaBridge3) | medium | pending | Lightweight C++ to Lua binding |
| [AngelScript](https://github.com/codecat/angelscript-mirror) | high | pending | Game scripting language, C++ integration |
| [ChaiScript](https://github.com/ChaiScript/ChaiScript) | medium | pending | Embedded scripting for C++, header-only |
| [Squirrel](https://github.com/albertodemichelis/squirrel) | medium | pending | Lightweight scripting, game-focused |
| [mruby](https://github.com/mruby/mruby) | high | pending | Lightweight Ruby, embeddable |
| [QuickJS](https://github.com/nickinditocker/nickinditocker) | medium | pending | Small JavaScript engine, ES2020 |
| [Duktape](https://github.com/nickinditocker/nickinditocker) | medium | pending | Embeddable JS, C, small footprint |

## Scene / World Management

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [Open3D](https://github.com/isl-org/Open3D) | massive | pending | 3D data processing, point clouds, ML |
| [OpenSceneGraph](https://github.com/openscenegraph/OpenSceneGraph) | massive | pending | High-performance 3D graphics toolkit |
| [VTK](https://github.com/Kitware/VTK) | massive | pending | Visualization toolkit, scientific |
| [PCL](https://github.com/PointCloudLibrary/pcl) | massive | pending | Point Cloud Library, robotics/vision |

---

## Procedural Generation

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [FastNoiseLite](https://github.com/Auburn/FastNoiseLite) | low | pending | Single-header C, noise generation |
| [FastNoise2](https://github.com/Auburn/FastNoise2) | high | pending | C++17 templates, SIMD, node graphs |
| [libnoise](https://libnoise.sourceforge.net/) | medium | pending | Classic coherent noise library |

## Animation

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [ozz-animation](https://github.com/guillaumeblanc/ozz-animation) | high | pending | Skeletal animation, C++17, SIMD, SoA |
| [spine-runtimes](https://github.com/EsotericSoftware/spine-runtimes) | medium | pending | 2D skeletal animation runtime |
| [ACL](https://github.com/nfrechette/acl) | high | pending | Animation Compression Library |

## AI / Pathfinding

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [Recast/Detour](https://github.com/recastnavigation/recastnavigation) | high | pending | Industry-standard navmesh (Unity/Unreal) |
| [MicroPather](https://github.com/leethomason/MicroPather) | low | done | Tiny A* solver, virtual interface |

## Level Design / Tilemaps

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [LDtkLoader](https://github.com/Madour/LDtkLoader) | medium | in-progress | LDtk level loader, needs template alias fix |
| [Tilengine](https://www.tilengine.org/) | medium | pending | Retro 2D engine, C99, scanline effects |
| [tmx-parser](https://github.com/sainteos/tmxparser) | low | pending | Tiled TMX format loader |

## Asset Loading

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [cgltf](https://github.com/jsmber/cgltf) | low | pending | Single-file glTF 2.0 loader, C99 |
| [tinyobjloader](https://github.com/tinyobjloader/tinyobjloader) | low | pending | Single-header OBJ loader |
| [tinygltf](https://github.com/syoyo/tinygltf) | medium | pending | Header-only glTF 2.0 loader, C++11 |
| [Assimp](https://github.com/assimp/assimp) | high | pending | Multi-format importer, large API |

## Networking

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [librg](https://github.com/zpl-c/librg) | low | pending | Gamedev sync/replication, header-only C |
| [yojimbo](https://github.com/networkprotocol/yojimbo) | high | pending | Game networking, reliable UDP |
| [GameNetworkingSockets](https://github.com/ValveSoftware/GameNetworkingSockets) | high | pending | Valve's networking library |

## Math

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [HandmadeMath](https://github.com/HandmadeMath/HandmadeMath) | low | pending | Single-header C, game math |
| [cglm](https://github.com/recp/cglm) | medium | pending | C99, SIMD, OpenGL math |
| [linalg.h](https://github.com/sgorsten/linalg) | low | pending | Single-header C++11, linear algebra |

## Graphics / Rendering

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [sokol](https://github.com/floooh/sokol) | medium | pending | Multi-module C, cross-platform gfx/app/audio |
| [par_shapes](https://github.com/prideout/par) | low | pending | Procedural mesh generation, C99 |
| [meshoptimizer](https://github.com/zeux/meshoptimizer) | medium | pending | Mesh optimization, C++ |
| [volk](https://github.com/zeux/volk) | low | pending | Vulkan meta-loader, C |

## Text / Fonts

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [stb_truetype](https://github.com/nothings/stb) | low | pending | Single-header font rasterizer |
| [fontstash](https://github.com/memononen/fontstash) | low | pending | Font rendering with stb_truetype |
| [msdf-atlas-gen](https://github.com/Chlumsky/msdf-atlas-gen) | high | pending | Multi-channel SDF font atlases |

## UI

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [Nuklear](https://github.com/Immediate-Mode-UI/Nuklear) | medium | pending | Single-header C, immediate mode UI |
| [microui](https://github.com/rxi/microui) | low | pending | Tiny immediate mode UI, C |
| [raygui](https://github.com/raysan5/raygui) | low | pending | raylib-style immediate mode GUI |

## Utilities

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [cr.h](https://github.com/fungos/cr) | low | pending | C/C++ hot reload |
| [log.c](https://github.com/rxi/log.c) | low | pending | Simple C logging |
| [ini.h](https://github.com/mattiasgustavsson/libs) | low | pending | INI file parser |
| [cute_headers](https://github.com/RandyGaul/cute_headers) | varies | pending | Collection: sound, tiled, spritebatch, etc. |

## Compression / Serialization

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [lz4](https://github.com/lz4/lz4) | low | pending | Fast compression, C |
| [zstd](https://github.com/facebook/zstd) | medium | pending | Facebook compression, C |
| [miniz](https://github.com/richgel999/miniz) | low | pending | Single-file zlib replacement |

## Spatial / Collision

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [nanoflann](https://github.com/jlblancoc/nanoflann) | medium | pending | Header-only KD-trees, C++ templates |
| [rectpack2D](https://github.com/TeamHypersomnia/rectpack2D) | low | pending | Rectangle packing, C++ |

---

# Generic / Systems Libraries

## Threading / Job Systems

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [enkiTS](https://github.com/dougbinks/enkiTS) | medium | pending | Task scheduler, C/C++, fiber-free, game-focused |
| [BS::thread_pool](https://github.com/bshoshany/thread-pool) | low | pending | Single-header C++17/20/23 thread pool |
| [marl](https://github.com/google/marl) | high | pending | Google's hybrid thread/fiber scheduler, C++11 |
| [taskflow](https://github.com/taskflow/taskflow) | high | pending | Parallel task programming, DAG-based, C++17 |
| [libjobs](https://github.com/TLeonardUK/libjobs) | medium | pending | Fiber-based job system, coroutine-style |

## State Machines / Behavior

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [BehaviorTree.CPP](https://github.com/BehaviorTree/BehaviorTree.CPP) | high | pending | Industry BT library, XML trees, async actions |
| [tinyfsm](https://github.com/digint/tinyfsm) | low | pending | Header-only FSM, C++11, no RTTI |
| [hfsm2](https://github.com/andrew-gresyk/HFSM2) | medium | pending | Hierarchical FSM, header-only, C++11 |
| [sml](https://github.com/boost-ext/sml) | medium | pending | State Machine Language, C++14, Boost.MSM alternative |

## Expression Parsing / Scripting

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [exprtk](https://github.com/ArashPartow/exprtk) | high | pending | Math expression parser, feature-rich, single-header |
| [muparser](https://github.com/beltoforion/muparser) | medium | pending | Fast math parser, bytecode compilation |
| [cparse](https://github.com/cparse/cparse) | medium | pending | Configurable expression parser, calculator |
| [Lua](https://github.com/lua/lua) | medium | pending | Classic embeddable scripting, C |
| [wren](https://github.com/wren-lang/wren) | medium | pending | Small, fast scripting language, C |
| [chibi-scheme](https://github.com/ashinn/chibi-scheme) | medium | pending | Minimal Scheme for embedding, C |

## Memory Allocators

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [mimalloc](https://github.com/microsoft/mimalloc) | medium | pending | Microsoft's fast allocator, drop-in replacement |
| [tlsf](https://github.com/mattconte/tlsf) | low | pending | Two-Level Segregated Fit, O(1) alloc, embedded |
| [rpmalloc](https://github.com/mjansson/rpmalloc) | low | pending | Cross-platform lock-free allocator |
| [memtailor](https://github.com/broune/memtailor) | low | pending | Arena + pool allocators, C++ |

## Signals / Events

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [sigslot](https://github.com/palacaze/sigslot) | low | pending | Header-only signals/slots, C++14, thread-safe |
| [rocket](https://github.com/tripleslash/rocket) | low | pending | Fast single-header signal/slots |
| [eventpp](https://github.com/wqking/eventpp) | medium | pending | Event dispatcher, callback list, C++11 |
| [nano-signal-slot](https://github.com/NoAvailableAlias/nano-signal-slot) | low | pending | Minimal signal/slot, header-only |

## Serialization / Reflection

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [reflect-cpp](https://github.com/getml/reflect-cpp) | high | pending | C++20 reflection, JSON/msgpack/CBOR/XML |
| [cereal](https://github.com/USCiLab/cereal) | medium | pending | Header-only serialization, C++11 |
| [msgpack-c](https://github.com/msgpack/msgpack-c) | medium | pending | MessagePack for C/C++ |
| [bitsery](https://github.com/fraillt/bitsery) | medium | pending | Header-only binary serialization, fast |
| [cista](https://github.com/felixguendling/cista) | medium | pending | Zero-copy serialization, reflection, C++17 |

## Profiling / Debugging

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [tracy](https://github.com/wolfpld/tracy) | high | pending | Frame profiler, nanosecond resolution, GPU support |
| [optick](https://github.com/bombomby/optick) | high | pending | Game profiler, Unreal/Unity support |
| [microprofile](https://github.com/jonasmr/microprofile) | medium | pending | Embeddable profiler, web viewer |
| [Remotery](https://github.com/Celtoys/Remotery) | medium | pending | Realtime CPU/GPU profiler, single C file |

## Data Structures

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [robin-hood-hashing](https://github.com/martinus/robin-hood-hashing) | low | pending | Fast hashmap, single-header |
| [parallel-hashmap](https://github.com/greg7mdp/parallel-hashmap) | medium | pending | Thread-safe hashmaps, Abseil-based |
| [plf::colony](https://github.com/mattreecebentley/plf_colony) | low | pending | Unordered container, pointer stability |
| [slot_map](https://github.com/SergeyMakeev/slot_map) | low | pending | Slot map container, O(1) operations |
| [ETL](https://github.com/ETLCPP/etl) | high | pending | Embedded Template Library, no heap |

## String / Text Processing

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [fmt](https://github.com/fmtlib/fmt) | medium | pending | Modern formatting library, C++11/14/17/20 |
| [utf8proc](https://github.com/JuliaStrings/utf8proc) | low | pending | UTF-8 processing, C |
| [re2](https://github.com/google/re2) | high | pending | Google's regex library, linear time |
| [ctre](https://github.com/hanickadot/compile-time-regular-expressions) | medium | pending | Compile-time regex, C++17 |

## CLI / Terminal

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [CLI11](https://github.com/CLIUtils/CLI11) | low | pending | Command line parser, header-only, C++11 |
| [argparse](https://github.com/p-ranav/argparse) | low | pending | Argument parser, header-only, C++17 |
| [indicators](https://github.com/p-ranav/indicators) | low | pending | Progress bars, spinners, C++11 |
| [tabulate](https://github.com/p-ranav/tabulate) | low | pending | Table formatting, header-only |
| [rang](https://github.com/agauniyal/rang) | low | pending | Terminal colors, header-only |

## HTTP / Web

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [cpp-httplib](https://github.com/yhirose/cpp-httplib) | medium | pending | Single-header HTTP/HTTPS client/server |
| [cpr](https://github.com/libcpr/cpr) | medium | pending | Curl wrapper, modern C++ API |
| [drogon](https://github.com/drogonframework/drogon) | high | pending | High-performance web framework |
| [uWebSockets](https://github.com/uNetworking/uWebSockets) | high | pending | Fast WebSocket/HTTP, C++17 |

## Cryptography

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [libsodium](https://github.com/jedisct1/libsodium) | medium | pending | Modern crypto library, C |
| [tiny-AES-c](https://github.com/kokke/tiny-AES-c) | low | pending | Small AES implementation, C |
| [xxHash](https://github.com/Cyan4973/xxHash) | low | pending | Extremely fast hash, C |
| [wyhash](https://github.com/wangyi-fudan/wyhash) | low | pending | Fastest hash function, portable |

## Testing / Mocking

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [doctest](https://github.com/doctest/doctest) | low | pending | Fastest C++ testing framework, single-header |
| [Catch2](https://github.com/catchorg/Catch2) | medium | pending | Popular testing framework, header-only |
| [fff](https://github.com/meekrosoft/fff) | low | pending | Fake Function Framework, C mocking |

## ECS (Entity Component System)

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [flecs](https://github.com/SanderMertens/flecs) | high | pending | Fast ECS, C/C++, queries, relationships |
| [entt](https://github.com/skypjack/entt) | high | pending | Gaming ECS, header-only, C++17 |

## Misc Interesting

| Library | Complexity | Status | Notes |
|---------|------------|--------|-------|
| [stc](https://github.com/stclib/STC) | medium | pending | Modern C container library, templates via macros |
| [sc](https://github.com/tezc/sc) | low | pending | Portable C libs: hashmap, queue, buffer, timer |
| [incbin](https://github.com/graphitemaster/incbin) | low | pending | Include binary files in C/C++ |
| [whereami](https://github.com/gpakosz/whereami) | low | pending | Get executable path, C/C++ |
| [hedley](https://github.com/nemequ/hedley) | low | pending | Portability macros, compiler detection |
| [dr_libs](https://github.com/mackron/dr_libs) | low | pending | Audio decoders: wav, mp3, flac |
| [pocketpy](https://github.com/pocketpy/pocketpy) | medium | pending | Python interpreter in 1 file, C++17 |

---

## Already Done

| Library | Category | Notes |
|---------|----------|-------|
| stb_image | Image loading | C mode |
| glfw | Windowing | C |
| RVO2 | Collision avoidance | C++ |
| ray_renderer | Vulkan graphics | Complex multi-file |
| LinaVG | Vector graphics | C++ templates |
| polypartition | Polygon triangulation | C++ |
| im3d | 3D gizmos | C++ |
| miniaudio | Audio | (if done elsewhere) |
| box2d | Physics | (if done elsewhere) |
| dear imgui | UI | (if done elsewhere) |
| enet | Networking | (if done elsewhere) |

---

## Selection Criteria

When choosing next targets, consider:

1. **Feature coverage** - Does it test new C++ features not yet covered?
   - Templates (FastNoise2, nanoflann)
   - Virtual interfaces (MicroPather)
   - Callbacks (Recast, librg)
   - SIMD intrinsics (ozz, cglm)
   - C99 mode (cgltf, sokol, Tilengine)

2. **Practical value** - Is it commonly used in game dev?

3. **Complexity gradient** - Mix of easy wins and challenging cases

4. **Header structure** - Single-header vs multi-file projects
