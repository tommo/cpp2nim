# Auto-generated Nim bindings for stb_image.h
# Generated: 2025-12-31T13:14:17+08:00

type
  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*

type
  stbi_uc* {.header: "stb_image.h", importcpp: "stbi_uc".} = uint8
  stbi_us* {.header: "stb_image.h", importcpp: "stbi_us".} = cushort
  stbi_io_callbacks* {.header: "stb_image.h", importcpp: "stbi_io_callbacks".} = object of RootObj
    read*: proc(arg_0:pointer,arg_1:cstring,arg_2:cint):cint{.cdecl}
    skip*: proc(arg_0:pointer,arg_1:cint){.cdecl}
    eof*: proc(arg_0:pointer):cint{.cdecl}

proc stbi_load_from_memory*(buffer: ptr stbi_uc, len: cint, x: ptr cint, y: ptr cint, channels_in_file: ptr cint, desired_channels: cint): ptr stbi_uc {.importc: "stbi_load_from_memory".}
proc stbi_load_from_callbacks*(clbk: ptr stbi_io_callbacks, user: pointer, x: ptr cint, y: ptr cint, channels_in_file: ptr cint, desired_channels: cint): ptr stbi_uc {.importc: "stbi_load_from_callbacks".}
proc stbi_load_gif_from_memory*(buffer: ptr stbi_uc, len: cint, delays: ptr ptr cint, x: ptr cint, y: ptr cint, z: ptr cint, comp: ptr cint, req_comp: cint): ptr stbi_uc {.importc: "stbi_load_gif_from_memory".}
proc stbi_load_16_from_memory*(buffer: ptr stbi_uc, len: cint, x: ptr cint, y: ptr cint, channels_in_file: ptr cint, desired_channels: cint): ptr stbi_us {.importc: "stbi_load_16_from_memory".}
proc stbi_load_16_from_callbacks*(clbk: ptr stbi_io_callbacks, user: pointer, x: ptr cint, y: ptr cint, channels_in_file: ptr cint, desired_channels: cint): ptr stbi_us {.importc: "stbi_load_16_from_callbacks".}
proc stbi_loadf_from_memory*(buffer: ptr stbi_uc, len: cint, x: ptr cint, y: ptr cint, channels_in_file: ptr cint, desired_channels: cint): ptr cfloat {.importc: "stbi_loadf_from_memory".}
proc stbi_loadf_from_callbacks*(clbk: ptr stbi_io_callbacks, user: pointer, x: ptr cint, y: ptr cint, channels_in_file: ptr cint, desired_channels: cint): ptr cfloat {.importc: "stbi_loadf_from_callbacks".}
proc stbi_hdr_to_ldr_gamma*(gamma: cfloat) {.importc: "stbi_hdr_to_ldr_gamma".}
proc stbi_hdr_to_ldr_scale*(scale: cfloat) {.importc: "stbi_hdr_to_ldr_scale".}
proc stbi_ldr_to_hdr_gamma*(gamma: cfloat) {.importc: "stbi_ldr_to_hdr_gamma".}
proc stbi_ldr_to_hdr_scale*(scale: cfloat) {.importc: "stbi_ldr_to_hdr_scale".}
proc stbi_is_hdr_from_callbacks*(clbk: ptr stbi_io_callbacks, user: pointer): cint {.importc: "stbi_is_hdr_from_callbacks".}
proc stbi_is_hdr_from_memory*(buffer: ptr stbi_uc, len: cint): cint {.importc: "stbi_is_hdr_from_memory".}
proc stbi_failure_reason*(): ccstring {.importc: "stbi_failure_reason".}
proc stbi_image_free*(retval_from_stbi_load: pointer) {.importc: "stbi_image_free".}
proc stbi_info_from_memory*(buffer: ptr stbi_uc, len: cint, x: ptr cint, y: ptr cint, comp: ptr cint): cint {.importc: "stbi_info_from_memory".}
proc stbi_info_from_callbacks*(clbk: ptr stbi_io_callbacks, user: pointer, x: ptr cint, y: ptr cint, comp: ptr cint): cint {.importc: "stbi_info_from_callbacks".}
proc stbi_is_16_bit_from_memory*(buffer: ptr stbi_uc, len: cint): cint {.importc: "stbi_is_16_bit_from_memory".}
proc stbi_is_16_bit_from_callbacks*(clbk: ptr stbi_io_callbacks, user: pointer): cint {.importc: "stbi_is_16_bit_from_callbacks".}
proc stbi_set_unpremultiply_on_load*(flag_true_if_should_unpremultiply: cint) {.importc: "stbi_set_unpremultiply_on_load".}
proc stbi_convert_iphone_png_to_rgb*(flag_true_if_should_convert: cint) {.importc: "stbi_convert_iphone_png_to_rgb".}
proc stbi_set_flip_vertically_on_load*(flag_true_if_should_flip: cint) {.importc: "stbi_set_flip_vertically_on_load".}
proc stbi_set_unpremultiply_on_load_thread*(flag_true_if_should_unpremultiply: cint) {.importc: "stbi_set_unpremultiply_on_load_thread".}
proc stbi_convert_iphone_png_to_rgb_thread*(flag_true_if_should_convert: cint) {.importc: "stbi_convert_iphone_png_to_rgb_thread".}
proc stbi_set_flip_vertically_on_load_thread*(flag_true_if_should_flip: cint) {.importc: "stbi_set_flip_vertically_on_load_thread".}
proc stbi_zlib_decode_malloc_guesssize*(buffer: ccstring, len: cint, initial_size: cint, outlen: ptr cint): cstring {.importc: "stbi_zlib_decode_malloc_guesssize".}
proc stbi_zlib_decode_malloc_guesssize_headerflag*(buffer: ccstring, len: cint, initial_size: cint, outlen: ptr cint, parse_header: cint): cstring {.importc: "stbi_zlib_decode_malloc_guesssize_headerflag".}
proc stbi_zlib_decode_malloc*(buffer: ccstring, len: cint, outlen: ptr cint): cstring {.importc: "stbi_zlib_decode_malloc".}
proc stbi_zlib_decode_buffer*(obuffer: cstring, olen: cint, ibuffer: ccstring, ilen: cint): cint {.importc: "stbi_zlib_decode_buffer".}
proc stbi_zlib_decode_noheader_malloc*(buffer: ccstring, len: cint, outlen: ptr cint): cstring {.importc: "stbi_zlib_decode_noheader_malloc".}
proc stbi_zlib_decode_noheader_buffer*(obuffer: cstring, olen: cint, ibuffer: ccstring, ilen: cint): cint {.importc: "stbi_zlib_decode_noheader_buffer".}
const
  STBI_default* = 0
  STBI_grey* = 1
  STBI_grey_alpha* = 2
  STBI_rgb* = 3
  STBI_rgb_alpha* = 4
