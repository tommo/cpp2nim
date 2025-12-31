# Auto-generated shared types for cpp2nim
# Generated: 2025-12-31T16:44:49+08:00

type
  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*

type
  eAUXBuffer* {.size:sizeof(uint32), header: "Types.h", importcpp: "Ray::eAUXBuffer", pure.} = enum
    SHL1 = 0,
    BaseColor = 1,
    DepthNormals = 2

  eCamType* {.size:sizeof(uint8), header: "Types.h", importcpp: "Ray::eCamType", pure.} = enum
    Persp = 0,
    Ortho = 1,
    Geo = 2

  ePixelFilter* {.size:sizeof(uint8), header: "Types.h", importcpp: "Ray::ePixelFilter", pure.} = enum
    Box = 0,
    Gaussian = 1,
    BlackmanHarris = 2,
    x_Count = 3

  eLensUnits* {.size:sizeof(uint8), header: "Types.h", importcpp: "Ray::eLensUnits", pure.} = enum
    FOV = 0,
    FLength = 1

  eViewTransform* {.size:sizeof(uint8), header: "Types.h", importcpp: "Ray::eViewTransform", pure.} = enum
    Standard = 0,
    AgX = 1,
    AgX_Punchy = 2,
    Filmic_VeryLowContrast = 3,
    Filmic_LowContrast = 4,
    Filmic_MediumLowContrast = 5,
    Filmic_MediumContrast = 6,
    Filmic_MediumHighContrast = 7,
    Filmic_HighContrast = 8,
    Filmic_VeryHighContrast = 9,
    x_Count = 10

  shl1_data_t* {.header: "Types.h", importcpp: "Ray::shl1_data_t".} = object
    coeff_r*: array[4,cfloat]
    coeff_g*: array[4,cfloat]
    coeff_b*: array[4,cfloat]
  rect_t* {.header: "Types.h", importcpp: "Ray::rect_t".} = object
    x*: cint
    y*: cint
    w*: cint
    h*: cint
  unet_filter_properties_t* {.header: "Types.h", importcpp: "Ray::unet_filter_properties_t".} = object
    pass_count*: cint
    alias_dependencies*: array[16,array[4,cint]]

  # Handle types (from DEFINE_HANDLE macro - invisible to libclang)
  CameraHandle* {.header: "SceneBase.h", importcpp: "Ray::CameraHandle".} = object
    index: uint32
    blk: uint32
  LightHandle* {.header: "SceneBase.h", importcpp: "Ray::LightHandle".} = object
    index: uint32
    blk: uint32
  MaterialHandle* {.header: "SceneBase.h", importcpp: "Ray::MaterialHandle".} = object
    index: uint32
    blk: uint32
  MeshHandle* {.header: "SceneBase.h", importcpp: "Ray::MeshHandle".} = object
    index: uint32
    blk: uint32
  MeshInstanceHandle* {.header: "SceneBase.h", importcpp: "Ray::MeshInstanceHandle".} = object
    index: uint32
    blk: uint32
  TextureHandle* {.header: "SceneBase.h", importcpp: "Ray::TextureHandle".} = object
    index: uint32
    blk: uint32
  ParallelForFunction* = proc(begin_idx, end_idx: cint) {.cdecl.}
  ConstPtr*[T] = ptr T
  SceneBase* {.header: "SceneBase.h", importcpp: "Ray::SceneBase", byref.} = object of RootObj
    log* {.importcpp:"log_".}: ptr ILog
  ILog* {.header: "Log.h", importcpp: "Ray::ILog", byref.} = object of RootObj
