# Auto-generated Nim bindings for headers/Types.h
# Generated: 2025-12-31T16:44:49+08:00

import shared_types

type
  ePassFlags* {.size:sizeof(uint8), header: "Types.h", importcpp: "Ray::ePassFlags", pure.} = enum
    SkipDirectLight = 0,
    SkipIndirectLight = 1,
    LightingOnly = 2,
    NoBackground = 3,
    OutputSH = 4

  color_t*[T; N: static cint] {.header: "Types.h", importcpp: "Ray::color_t".} = object
    v*: array[N, T]
  color_data_t*[T; N: static cint] {.header: "Types.h", importcpp: "Ray::color_data_t".} = object
    `ptr`*: ptr color_t[T, N]
    pitch*: cint
  # Type aliases
  color_rgba_t* = color_t[cfloat, 4]
  color_rgb_t* = color_t[cfloat, 3]
  color_rg_t* = color_t[cfloat, 2]
  color_r_t* = color_t[cfloat, 1]
  color_rgba8_t* = color_t[uint8, 4]
  color_rgb8_t* = color_t[uint8, 3]
  color_rg8_t* = color_t[uint8, 2]
  color_r8_t* = color_t[uint8, 1]
  color_data_rgba_t* = color_data_t[cfloat, 4]
  color_data_rgb_t* = color_data_t[cfloat, 3]
  color_data_rg_t* = color_data_t[cfloat, 2]
  color_data_r_t* = color_data_t[cfloat, 1]
  color_data_rgba8_t* = color_data_t[uint8, 4]
  color_data_rgb8_t* = color_data_t[uint8, 3]
  color_data_rg8_t* = color_data_t[uint8, 2]
  color_data_r8_t* = color_data_t[uint8, 1]
  pass_settings_t* {.header: "Types.h", importcpp: "Ray::pass_settings_t".} = object
    max_diff_depth*: uint8
    max_spec_depth*: uint8
    max_refr_depth*: uint8
    max_transp_depth*: uint8
    max_total_depth*: uint8
    min_total_depth*: uint8
    min_transp_depth*: uint8
    flags*: cint
    clamp_direct*: cfloat
    clamp_indirect*: cfloat
    min_samples*: cint
    variance_threshold*: cfloat
    regularize_alpha*: cfloat
  camera_t* {.header: "Types.h", importcpp: "Ray::camera_t".} = object
    `type`*: eCamType
    filter*: ePixelFilter
    view_transform*: eViewTransform
    ltype*: eLensUnits
    filter_width*: cfloat
    fov*: cfloat
    exposure*: cfloat
    gamma*: cfloat
    sensor_height*: cfloat
    focus_distance*: cfloat
    focal_length*: cfloat
    fstop*: cfloat
    lens_rotation*: cfloat
    lens_ratio*: cfloat
    lens_blades*: cint
    clip_start*: cfloat
    clip_end*: cfloat
    origin*: array[3,cfloat]
    fwd*: array[3,cfloat]
    side*: array[3,cfloat]
    up*: array[3,cfloat]
    shift*: array[2,cfloat]
    mi_index*: uint32
    uv_index*: uint32
    pass_settings*: pass_settings_t
  gpu_device_t* {.header: "Types.h", importcpp: "Ray::gpu_device_t".} = object
    name*: array[256,cchar]

