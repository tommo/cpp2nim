# Auto-generated Nim bindings for headers/RendererBase.h
# Generated: 2025-12-31T16:44:49+08:00

import shared_types, Types, Log, SceneBase

type
  eRendererType* {.size:sizeof(uint32), header: "RendererBase.h", importcpp: "Ray::eRendererType", pure.} = enum
    Reference = 0,
    SIMD_SSE41 = 1,
    SIMD_AVX = 2,
    SIMD_AVX2 = 3,
    SIMD_AVX512 = 4,
    SIMD_NEON = 5,
    Vulkan = 6,
    DirectX12 = 7

  eGPUResState* {.size:sizeof(cint), header: "RendererBase.h", importcpp: "Ray::eGPUResState", pure.} = enum
    RenderTarget = 4,
    UnorderedAccess = 5,
    DepthRead = 6,
    DepthWrite = 7,
    ShaderResource = 9,
    CopyDst = 11,
    CopySrc = 12

  settings_t* {.header: "RendererBase.h", importcpp: "Ray::settings_t".} = object
    w*: cint
    h*: cint
    preferred_device*: cstring
    use_tex_compression*: bool
    use_hwrt*: bool
    use_bindless*: bool
    use_spatial_cache*: bool
    validation_level*: cint
  GpuImage* {.header: "RendererBase.h", importcpp: "Ray::GpuImage".} = object
    state*: eGPUResState
  GpuCommandBuffer* {.header: "RendererBase.h", importcpp: "Ray::GpuCommandBuffer".} = object
    index*: cint
  stats_t* {.header: "RendererBase.h", importcpp: "Ray::RendererBase::stats_t".} = object
    time_primary_ray_gen_us*: culonglong
    time_primary_trace_us*: culonglong
    time_primary_shade_us*: culonglong
    time_primary_shadow_us*: culonglong
    time_secondary_sort_us*: culonglong
    time_secondary_trace_us*: culonglong
    time_secondary_shade_us*: culonglong
    time_secondary_shadow_us*: culonglong
    time_denoise_us*: culonglong
    time_cache_update_us*: culonglong
    time_cache_resolve_us*: culonglong
  RegionContext* {.header: "RendererBase.h", importcpp: "Ray::RegionContext", byref.} = object
    iteration*: cint
    cache_iteration*: cint
  RendererBase* {.header: "RendererBase.h", importcpp: "Ray::RendererBase", byref.} = object of RootObj

proc rect*(self: ptr RegionContext): var rect_t {.importcpp: "rect".}
proc clear*(self: ptr RegionContext) {.importcpp: "Clear".}
proc `type`*(self: ptr RendererBase): eRendererType {.importcpp: "type".}
proc log*(self: ptr RendererBase): ptr ILog {.importcpp: "log".}
proc device_name*(self: ptr RendererBase): cstring {.importcpp: "device_name".}
proc is_hwrt*(self: ptr RendererBase): bool {.importcpp: "is_hwrt".}
proc is_spatial_caching_enabled*(self: ptr RendererBase): bool {.importcpp: "is_spatial_caching_enabled".}
proc size*(self: ptr RendererBase): pointer {.importcpp: "size".}
proc get_pixels_ref*(self: ptr RendererBase): color_data_rgba_t {.importcpp: "get_pixels_ref".}
proc get_raw_pixels_ref*(self: ptr RendererBase): color_data_rgba_t {.importcpp: "get_raw_pixels_ref".}
proc get_aux_pixels_ref*(self: ptr RendererBase, buf: eAUXBuffer): color_data_rgba_t {.importcpp: "get_aux_pixels_ref".}
proc get_sh_data_ref*(self: ptr RendererBase): ConstPtr[shl1_data_t] {.importcpp: "get_sh_data_ref".}
proc get_native_raw_pixels*(self: ptr RendererBase): GpuImage {.importcpp: "get_native_raw_pixels".}
proc set_native_raw_pixels_state*(self: ptr RendererBase, a00: eGPUResState) {.importcpp: "set_native_raw_pixels_state".}
proc set_command_buffer*(self: ptr RendererBase, a00: GpuCommandBuffer) {.importcpp: "set_command_buffer".}
proc resize*(self: ptr RendererBase, w: cint, h: cint) {.importcpp: "Resize".}
proc clear*(self: ptr RendererBase, c: color_rgba_t) {.importcpp: "Clear".}
proc createScene*(self: ptr RendererBase): ptr SceneBase {.importcpp: "CreateScene".}
proc renderScene*(self: ptr RendererBase, scene: SceneBase, region: var RegionContext) {.importcpp: "RenderScene".}
proc denoiseImage*(self: ptr RendererBase, region: RegionContext) {.importcpp: "DenoiseImage".}
proc denoiseImage*(self: ptr RendererBase, pass: cint, region: RegionContext) {.importcpp: "DenoiseImage".}
proc updateSpatialCache*(self: ptr RendererBase, scene: SceneBase, region: var RegionContext) {.importcpp: "UpdateSpatialCache".}
proc resolveSpatialCache*(self: ptr RendererBase, scene: SceneBase, parallel_for: pointer) {.importcpp: "ResolveSpatialCache".}
proc resetSpatialCache*(self: ptr RendererBase, scene: SceneBase, parallel_for: pointer) {.importcpp: "ResetSpatialCache".}
proc getStats*(self: ptr RendererBase, st: var stats_t) {.importcpp: "GetStats".}
proc resetStats*(self: ptr RendererBase) {.importcpp: "ResetStats".}
proc initUNetFilter*(self: ptr RendererBase, alias_memory: bool, parallel_for: pointer): unet_filter_properties_t {.importcpp: "InitUNetFilter".}
proc rendererTypeName*(rt: eRendererType): cstring {.importc: "Ray::RendererTypeName".}
proc rendererTypeFromName*(name: cstring): eRendererType {.importc: "Ray::RendererTypeFromName".}
proc rendererSupportsMultithreading*(rt: eRendererType): bool {.importc: "Ray::RendererSupportsMultithreading".}
proc rendererSupportsHWRT*(rt: eRendererType): bool {.importc: "Ray::RendererSupportsHWRT".}
proc newRegionContext*(rect: rect_t): RegionContext {.constructor,importcpp: "Ray::RegionContext(@)".}
proc newGpuImage*(): GpuImage {.constructor,importcpp: "Ray::GpuImage".}
proc newGpuCommandBuffer*(): GpuCommandBuffer {.constructor,importcpp: "Ray::GpuCommandBuffer".}
