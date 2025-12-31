# Auto-generated Nim bindings for headers/SceneBase.h
# Generated: 2025-12-31T16:44:49+08:00

import shared_types, Types, Log

type
  ePrimType* {.size:sizeof(cint), header: "SceneBase.h", importcpp: "Ray::ePrimType", pure.} = enum
    TriangleList = 0

  eShadingNode* {.size:sizeof(uint32), header: "SceneBase.h", importcpp: "Ray::eShadingNode", pure.} = enum
    Diffuse = 0,
    Glossy = 1,
    Refractive = 2,
    Emissive = 3,
    Mix = 4,
    Transparent = 5,
    Principled = 6

  eTextureFormat* {.size:sizeof(cint), header: "SceneBase.h", importcpp: "Ray::eTextureFormat", pure.} = enum
    Undefined = 0,
    RGBA8888 = 1,
    RGB888 = 2,
    RG88 = 3,
    R8 = 4,
    BC1 = 5,
    BC3 = 6,
    BC4 = 7,
    BC5 = 8

  eTextureConvention* {.size:sizeof(cint), header: "SceneBase.h", importcpp: "Ray::eTextureConvention", pure.} = enum
    OGL = 0,
    DX = 1

  CameraHandle_T* {.header: "SceneBase.h", importcpp: "Ray::CameraHandle_T".} = object
  LightHandle_T* {.header: "SceneBase.h", importcpp: "Ray::LightHandle_T".} = object
  MaterialHandle_T* {.header: "SceneBase.h", importcpp: "Ray::MaterialHandle_T".} = object
  MeshHandle_T* {.header: "SceneBase.h", importcpp: "Ray::MeshHandle_T".} = object
  MeshInstanceHandle_T* {.header: "SceneBase.h", importcpp: "Ray::MeshInstanceHandle_T".} = object
  TextureHandle_T* {.header: "SceneBase.h", importcpp: "Ray::TextureHandle_T".} = object
  shading_node_desc_t* {.header: "SceneBase.h", importcpp: "Ray::shading_node_desc_t".} = object
    `type`*: eShadingNode
    base_color*: array[3,cfloat]
    base_texture*: TextureHandle
    normal_map*: TextureHandle
    normal_map_intensity*: cfloat
    mix_materials*: array[2,MaterialHandle]
    roughness*: cfloat
    roughness_texture*: TextureHandle
    anisotropic*: cfloat
    anisotropic_rotation*: cfloat
    sheen*: cfloat
    specular*: cfloat
    strength*: cfloat
    fresnel*: cfloat
    ior*: cfloat
    tint*: cfloat
    metallic_texture*: TextureHandle
    importance_sample*: bool
    mix_add*: bool
  principled_mat_desc_t* {.header: "SceneBase.h", importcpp: "Ray::principled_mat_desc_t".} = object
    base_color*: array[3,cfloat]
    base_texture*: TextureHandle
    metallic*: cfloat
    metallic_texture*: TextureHandle
    specular*: cfloat
    specular_texture*: TextureHandle
    specular_tint*: cfloat
    roughness*: cfloat
    roughness_texture*: TextureHandle
    anisotropic*: cfloat
    anisotropic_rotation*: cfloat
    sheen*: cfloat
    sheen_tint*: cfloat
    clearcoat*: cfloat
    clearcoat_roughness*: cfloat
    ior*: cfloat
    transmission*: cfloat
    transmission_roughness*: cfloat
    emission_color*: array[3,cfloat]
    emission_texture*: TextureHandle
    emission_strength*: cfloat
    alpha*: cfloat
    alpha_texture*: TextureHandle
    normal_map*: TextureHandle
    normal_map_intensity*: cfloat
    importance_sample*: bool
  mat_group_desc_t* {.header: "SceneBase.h", importcpp: "Ray::mat_group_desc_t".} = object
    front_mat*: MaterialHandle
    back_mat*: MaterialHandle
    vtx_start*: csize_t
    vtx_count*: csize_t
  vtx_attribute_t* {.header: "SceneBase.h", importcpp: "Ray::vtx_attribute_t".} = object
    data*: pointer
    offset*: cint
    stride*: cint
  mesh_desc_t* {.header: "SceneBase.h", importcpp: "Ray::mesh_desc_t".} = object
    name*: cstring
    prim_type*: ePrimType
    vtx_positions*: vtx_attribute_t
    vtx_normals*: vtx_attribute_t
    vtx_binormals*: vtx_attribute_t
    vtx_uvs*: vtx_attribute_t
    vtx_indices*: pointer
    base_vertex*: cint
    groups*: pointer
    allow_spatial_splits*: bool
    use_fast_bvh_build*: bool
  mesh_instance_desc_t* {.header: "SceneBase.h", importcpp: "Ray::mesh_instance_desc_t".} = object
    xform*: ptr cfloat
    mesh*: MeshHandle
    camera_visibility*: bool
    diffuse_visibility*: bool
    specular_visibility*: bool
    refraction_visibility*: bool
    shadow_visibility*: bool
  tex_desc_t* {.header: "SceneBase.h", importcpp: "Ray::tex_desc_t".} = object
    format*: eTextureFormat
    convention*: eTextureConvention
    name*: cstring
    data*: pointer
    w*: cint
    h*: cint
    mips_count*: cint
    is_srgb*: bool
    is_normalmap*: bool
    is_YCoCg*: bool
    force_no_compression*: bool
    generate_mipmaps*: bool
    reconstruct_z*: bool
  directional_light_desc_t* {.header: "SceneBase.h", importcpp: "Ray::directional_light_desc_t".} = object
    color*: array[3,cfloat]
    direction*: array[3,cfloat]
    angle*: cfloat
    multiple_importance*: bool
    cast_shadow*: bool
    diffuse_visibility*: bool
    specular_visibility*: bool
    refraction_visibility*: bool
  sphere_light_desc_t* {.header: "SceneBase.h", importcpp: "Ray::sphere_light_desc_t".} = object
    color*: array[3,cfloat]
    position*: array[3,cfloat]
    radius*: cfloat
    multiple_importance*: bool
    cast_shadow*: bool
    diffuse_visibility*: bool
    specular_visibility*: bool
    refraction_visibility*: bool
  spot_light_desc_t* {.header: "SceneBase.h", importcpp: "Ray::spot_light_desc_t".} = object
    color*: array[3,cfloat]
    position*: array[3,cfloat]
    direction*: array[3,cfloat]
    spot_size*: cfloat
    spot_blend*: cfloat
    radius*: cfloat
    multiple_importance*: bool
    cast_shadow*: bool
    diffuse_visibility*: bool
    specular_visibility*: bool
    refraction_visibility*: bool
  rect_light_desc_t* {.header: "SceneBase.h", importcpp: "Ray::rect_light_desc_t".} = object
    color*: array[3,cfloat]
    width*: cfloat
    height*: cfloat
    spread_angle*: cfloat
    doublesided*: bool
    sky_portal*: bool
    multiple_importance*: bool
    cast_shadow*: bool
    diffuse_visibility*: bool
    specular_visibility*: bool
    refraction_visibility*: bool
  disk_light_desc_t* {.header: "SceneBase.h", importcpp: "Ray::disk_light_desc_t".} = object
    color*: array[3,cfloat]
    size_x*: cfloat
    size_y*: cfloat
    spread_angle*: cfloat
    doublesided*: bool
    sky_portal*: bool
    multiple_importance*: bool
    cast_shadow*: bool
    diffuse_visibility*: bool
    specular_visibility*: bool
    refraction_visibility*: bool
  line_light_desc_t* {.header: "SceneBase.h", importcpp: "Ray::line_light_desc_t".} = object
    color*: array[3,cfloat]
    radius*: cfloat
    height*: cfloat
    sky_portal*: bool
    multiple_importance*: bool
    cast_shadow*: bool
    diffuse_visibility*: bool
    specular_visibility*: bool
    refraction_visibility*: bool
  camera_desc_t* {.header: "SceneBase.h", importcpp: "Ray::camera_desc_t".} = object
    `type`*: eCamType
    filter*: ePixelFilter
    view_transform*: eViewTransform
    ltype*: eLensUnits
    filter_width*: cfloat
    origin*: array[3,cfloat]
    fwd*: array[3,cfloat]
    up*: array[3,cfloat]
    shift*: array[2,cfloat]
    exposure*: cfloat
    fov*: cfloat
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
    mi_index*: uint32
    uv_index*: uint32
    lighting_only*: bool
    skip_direct_lighting*: bool
    skip_indirect_lighting*: bool
    no_background*: bool
    output_sh*: bool
    max_diff_depth*: uint8
    max_spec_depth*: uint8
    max_refr_depth*: uint8
    max_transp_depth*: uint8
    max_total_depth*: uint8
    min_total_depth*: uint8
    min_transp_depth*: uint8
    clamp_direct*: cfloat
    clamp_indirect*: cfloat
    min_samples*: cint
    variance_threshold*: cfloat
    regularize_alpha*: cfloat
  atmosphere_params_t* {.header: "SceneBase.h", importcpp: "Ray::atmosphere_params_t".} = object
    planet_radius*: cfloat
    viewpoint_height*: cfloat
    atmosphere_height*: cfloat
    rayleigh_height*: cfloat
    mie_height*: cfloat
    clouds_height_beg*: cfloat
    clouds_height_end*: cfloat
    clouds_variety*: cfloat
    clouds_density*: cfloat
    clouds_offset_x*: cfloat
    clouds_offset_z*: cfloat
    clouds_flutter_x*: cfloat
    clouds_flutter_z*: cfloat
    cirrus_clouds_amount*: cfloat
    cirrus_clouds_height*: cfloat
    ozone_height_center*: cfloat
    ozone_half_width*: cfloat
    atmosphere_density*: cfloat
    stars_brightness*: cfloat
    moon_radius*: cfloat
    moon_distance*: cfloat
    moon_dir*: array[4,cfloat]
    rayleigh_scattering*: array[4,cfloat]
    mie_scattering*: array[4,cfloat]
    mie_extinction*: array[4,cfloat]
    mie_absorption*: array[4,cfloat]
    ozone_absorption*: array[4,cfloat]
    ground_albedo*: array[4,cfloat]
  environment_desc_t* {.header: "SceneBase.h", importcpp: "Ray::environment_desc_t".} = object
    env_col*: array[3,cfloat]
    env_map*: TextureHandle
    back_col*: array[3,cfloat]
    back_map*: TextureHandle
    env_map_rotation*: cfloat
    back_map_rotation*: cfloat
    envmap_resolution*: cint
    importance_sample*: bool
    atmosphere*: atmosphere_params_t

proc log*(self: ptr SceneBase): ptr ILog {.importcpp: "log".}
proc getEnvironment*(self: ptr SceneBase, env: var environment_desc_t) {.importcpp: "GetEnvironment".}
proc setEnvironment*(self: ptr SceneBase, env: environment_desc_t) {.importcpp: "SetEnvironment".}
proc addTexture*(self: ptr SceneBase, t: tex_desc_t): TextureHandle {.importcpp: "AddTexture".}
proc removeTexture*(self: ptr SceneBase, t: TextureHandle) {.importcpp: "RemoveTexture".}
proc addMaterial*(self: ptr SceneBase, m: shading_node_desc_t): MaterialHandle {.importcpp: "AddMaterial".}
proc addMaterial*(self: ptr SceneBase, m: principled_mat_desc_t): MaterialHandle {.importcpp: "AddMaterial".}
proc removeMaterial*(self: ptr SceneBase, m: MaterialHandle) {.importcpp: "RemoveMaterial".}
proc addMesh*(self: ptr SceneBase, m: mesh_desc_t): MeshHandle {.importcpp: "AddMesh".}
proc removeMesh*(self: ptr SceneBase, m: MeshHandle) {.importcpp: "RemoveMesh".}
proc addLight*(self: ptr SceneBase, l: directional_light_desc_t): LightHandle {.importcpp: "AddLight".}
proc addLight*(self: ptr SceneBase, l: sphere_light_desc_t): LightHandle {.importcpp: "AddLight".}
proc addLight*(self: ptr SceneBase, l: spot_light_desc_t): LightHandle {.importcpp: "AddLight".}
proc addLight*(self: ptr SceneBase, l: rect_light_desc_t, xform: ptr cfloat): LightHandle {.importcpp: "AddLight".}
proc addLight*(self: ptr SceneBase, l: disk_light_desc_t, xform: ptr cfloat): LightHandle {.importcpp: "AddLight".}
proc addLight*(self: ptr SceneBase, l: line_light_desc_t, xform: ptr cfloat): LightHandle {.importcpp: "AddLight".}
proc removeLight*(self: ptr SceneBase, l: LightHandle) {.importcpp: "RemoveLight".}
proc addMeshInstance*(self: ptr SceneBase, mesh: MeshHandle, xform: ptr cfloat): MeshInstanceHandle {.importcpp: "AddMeshInstance".}
proc addMeshInstance*(self: ptr SceneBase, mi: mesh_instance_desc_t): MeshInstanceHandle {.importcpp: "AddMeshInstance".}
proc setMeshInstanceTransform*(self: ptr SceneBase, mi: MeshInstanceHandle, xform: ptr cfloat) {.importcpp: "SetMeshInstanceTransform".}
proc removeMeshInstance*(self: ptr SceneBase, mi: MeshInstanceHandle) {.importcpp: "RemoveMeshInstance".}
proc finalize*(self: ptr SceneBase, parallel_for: pointer) {.importcpp: "Finalize".}
proc addCamera*(self: ptr SceneBase, c: camera_desc_t): CameraHandle {.importcpp: "AddCamera".}
proc getCamera*(self: ptr SceneBase, i: CameraHandle, c: var camera_desc_t) {.importcpp: "GetCamera".}
proc setCamera*(self: ptr SceneBase, i: CameraHandle, c: camera_desc_t) {.importcpp: "SetCamera".}
proc removeCamera*(self: ptr SceneBase, i: CameraHandle) {.importcpp: "RemoveCamera".}
proc current_cam*(self: ptr SceneBase): CameraHandle {.importcpp: "current_cam".}
proc set_current_cam*(self: ptr SceneBase, i: CameraHandle) {.importcpp: "set_current_cam".}
proc triangle_count*(self: ptr SceneBase): uint32 {.importcpp: "triangle_count".}
proc node_count*(self: ptr SceneBase): uint32 {.importcpp: "node_count".}
proc isCompressedFormat*(format: eTextureFormat): bool {.importc: "Ray::IsCompressedFormat".}
proc parallel_for_serial*(`from`: cint, to: cint, f: ParallelForFunction) {.importc: "Ray::parallel_for_serial".}
proc newmat_group_desc_t*(v_front_material: MaterialHandle, v_back_material: MaterialHandle, v_vtx_start: csize_t, v_vtx_count: csize_t): mat_group_desc_t {.constructor,importcpp: "Ray::mat_group_desc_t(@)".}
proc newmat_group_desc_t*(v_front_material: MaterialHandle, v_vtx_start: csize_t, v_vtx_count: csize_t): mat_group_desc_t {.constructor,importcpp: "Ray::mat_group_desc_t(@)".}
