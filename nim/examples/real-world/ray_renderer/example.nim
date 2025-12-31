# Ray Renderer Nim Bindings - Example Usage
#
# Demonstrates working bindings for the Ray path tracer.
# Build: nim cpp -d:release --passC:"-I./headers -I./headers/build" --passL:"./headers/build/libRay.a" -o:example_bin example.nim

{.emit: """
#include "Ray.h"

static Ray::RendererBase* createRayRenderer() {
  Ray::settings_t s;
  s.w = 256;
  s.h = 256;
  s.use_tex_compression = true;
  s.use_hwrt = false;
  s.use_bindless = true;
  s.use_spatial_cache = false;
  s.validation_level = 0;
  return Ray::CreateRenderer(s, &Ray::g_stdout_log, Ray::parallel_for_serial);
}

// Cornell box mesh - requires Span types, so done in C++
static void setupCornellBox(Ray::SceneBase* scene,
                            Ray::MaterialHandle mat1, Ray::MaterialHandle mat2,
                            Ray::MaterialHandle mat3, Ray::MaterialHandle mat4) {
  // pos(3), normal(3), uv(2) per vertex
  static const float attrs[] = {
    // floor
    0.0f,0.0f,-0.5592f, 0.0f,1.0f,0.0f, 1.0f,1.0f,
    0.0f,0.0f,0.0f, 0.0f,1.0f,0.0f, 1.0f,0.0f,
    -0.5528f,0.0f,0.0f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    -0.5496f,0.0f,-0.5592f, 0.0f,1.0f,0.0f, 0.0f,1.0f,
    // back wall
    0.0f,0.0f,-0.5592f, 0.0f,0.0f,1.0f, 0.0f,0.0f,
    -0.5496f,0.0f,-0.5592f, 0.0f,0.0f,1.0f, 0.0f,0.0f,
    -0.556f,0.5488f,-0.5592f, 0.0f,0.0f,1.0f, 0.0f,0.0f,
    0.0f,0.5488f,-0.5592f, 0.0f,0.0f,1.0f, 0.0f,0.0f,
    // ceiling
    -0.556f,0.5488f,-0.5592f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    0.0f,0.5488f,-0.5592f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    0.0f,0.5488f,0.0f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    -0.556f,0.5488f,0.0f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    // left wall (red)
    -0.5528f,0.0f,0.0f, 1.0f,0.0f,0.0f, 0.0f,0.0f,
    -0.5496f,0.0f,-0.5592f, 1.0f,0.0f,0.0f, 0.0f,0.0f,
    -0.556f,0.5488f,0.0f, 1.0f,0.0f,0.0f, 0.0f,0.0f,
    -0.556f,0.5488f,-0.5592f, 1.0f,0.0f,0.0f, 0.0f,0.0f,
    // right wall (green)
    0.0f,0.0f,-0.5592f, -1.0f,0.0f,0.0f, 0.0f,0.0f,
    0.0f,0.0f,0.0f, -1.0f,0.0f,0.0f, 0.0f,0.0f,
    0.0f,0.5488f,-0.5592f, -1.0f,0.0f,0.0f, 0.0f,0.0f,
    0.0f,0.5488f,0.0f, -1.0f,0.0f,0.0f, 0.0f,0.0f,
    // light
    -0.213f,0.5478f,-0.227f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    -0.343f,0.5478f,-0.227f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    -0.343f,0.5478f,-0.332f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    -0.213f,0.5478f,-0.332f, 0.0f,-1.0f,0.0f, 0.0f,0.0f,
    // short block (5 faces x 4 verts = 20 verts)
    -0.240464f,0.0f,-0.271646f, 0.286f,0.0f,-0.958f, 0.0f,0.0f,
    -0.240464f,0.165f,-0.271646f, 0.286f,0.0f,-0.958f, 0.0f,0.0f,
    -0.082354f,0.165f,-0.224464f, 0.286f,0.0f,-0.958f, 0.0f,0.0f,
    -0.082354f,0.0f,-0.224464f, 0.286f,0.0f,-0.958f, 0.0f,0.0f,
    -0.240464f,0.0f,-0.271646f, -0.958f,0.0f,-0.286f, 0.0f,0.0f,
    -0.240464f,0.165f,-0.271646f, -0.958f,0.0f,-0.286f, 0.0f,0.0f,
    -0.287646f,0.165f,-0.113536f, -0.958f,0.0f,-0.286f, 0.0f,0.0f,
    -0.287646f,0.0f,-0.113536f, -0.958f,0.0f,-0.286f, 0.0f,0.0f,
    -0.082354f,0.0f,-0.224464f, 0.958f,0.0f,0.286f, 0.0f,0.0f,
    -0.082354f,0.165f,-0.224464f, 0.958f,0.0f,0.286f, 0.0f,0.0f,
    -0.129536f,0.165f,-0.066354f, 0.958f,0.0f,0.286f, 0.0f,0.0f,
    -0.129536f,0.0f,-0.066354f, 0.958f,0.0f,0.286f, 0.0f,0.0f,
    -0.287646f,0.0f,-0.113536f, -0.286f,0.0f,0.958f, 0.0f,0.0f,
    -0.287646f,0.165f,-0.113536f, -0.286f,0.0f,0.958f, 0.0f,0.0f,
    -0.129536f,0.165f,-0.066354f, -0.286f,0.0f,0.958f, 0.0f,0.0f,
    -0.129536f,0.0f,-0.066354f, -0.286f,0.0f,0.958f, 0.0f,0.0f,
    -0.240464f,0.165f,-0.271646f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    -0.082354f,0.165f,-0.224464f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    -0.129536f,0.165f,-0.066354f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    -0.287646f,0.165f,-0.113536f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    // tall block (5 faces x 4 verts = 20 verts)
    -0.471239f,0.0f,-0.405353f, -0.296f,0.0f,-0.955f, 0.0f,0.0f,
    -0.471239f,0.33f,-0.405353f, -0.296f,0.0f,-0.955f, 0.0f,0.0f,
    -0.313647f,0.33f,-0.454239f, -0.296f,0.0f,-0.955f, 0.0f,0.0f,
    -0.313647f,0.0f,-0.454239f, -0.296f,0.0f,-0.955f, 0.0f,0.0f,
    -0.264761f,0.0f,-0.296647f, 0.955f,0.0f,-0.296f, 0.0f,0.0f,
    -0.264761f,0.33f,-0.296647f, 0.955f,0.0f,-0.296f, 0.0f,0.0f,
    -0.313647f,0.33f,-0.454239f, 0.955f,0.0f,-0.296f, 0.0f,0.0f,
    -0.313647f,0.0f,-0.454239f, 0.955f,0.0f,-0.296f, 0.0f,0.0f,
    -0.471239f,0.0f,-0.405353f, -0.955f,0.0f,0.296f, 0.0f,0.0f,
    -0.471239f,0.33f,-0.405353f, -0.955f,0.0f,0.296f, 0.0f,0.0f,
    -0.422353f,0.33f,-0.247761f, -0.955f,0.0f,0.296f, 0.0f,0.0f,
    -0.422353f,0.0f,-0.247761f, -0.955f,0.0f,0.296f, 0.0f,0.0f,
    -0.422353f,0.0f,-0.247761f, 0.296f,0.0f,0.955f, 0.0f,0.0f,
    -0.422353f,0.33f,-0.247761f, 0.296f,0.0f,0.955f, 0.0f,0.0f,
    -0.264761f,0.33f,-0.296647f, 0.296f,0.0f,0.955f, 0.0f,0.0f,
    -0.264761f,0.0f,-0.296647f, 0.296f,0.0f,0.955f, 0.0f,0.0f,
    -0.471239f,0.33f,-0.405353f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    -0.313647f,0.33f,-0.454239f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    -0.264761f,0.33f,-0.296647f, 0.0f,1.0f,0.0f, 0.0f,0.0f,
    -0.422353f,0.33f,-0.247761f, 0.0f,1.0f,0.0f, 0.0f,0.0f
  };
  static const uint32_t indices[] = {
    0,2,1, 0,3,2,        // floor
    4,6,5, 4,7,6,        // back wall
    8,9,10, 8,10,11,     // ceiling
    12,13,14, 13,15,14,  // left wall (red)
    16,17,18, 18,17,19,  // right wall (green)
    20,21,22, 20,22,23,  // light
    24,25,26, 24,26,27, 28,30,29, 28,31,30, 32,33,34, 32,34,35, 36,38,37, 36,39,38, 40,42,41, 40,43,42, // short block
    44,45,46, 44,46,47, 48,50,49, 48,51,50, 52,54,53, 52,55,54, 56,58,57, 56,59,58, 60,62,61, 60,63,62  // tall block
  };
  Ray::mesh_desc_t mesh_desc;
  mesh_desc.prim_type = Ray::ePrimType::TriangleList;
  mesh_desc.vtx_positions = {attrs, 0, 8};
  mesh_desc.vtx_normals = {attrs, 3, 8};
  mesh_desc.vtx_uvs = {attrs, 6, 8};
  mesh_desc.vtx_indices = indices;
  // Groups: floor+back+ceiling(grey), left(red), right(green), light(emissive), blocks(grey)
  const Ray::mat_group_desc_t groups[] = {
    {mat1, 0, 18}, {mat2, 18, 6}, {mat3, 24, 6},
    {mat4, Ray::InvalidMaterialHandle, 30, 6}, {mat1, 36, 60}
  };
  mesh_desc.groups = groups;
  Ray::MeshHandle mesh = scene->AddMesh(mesh_desc);
  const float xform[] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
  scene->AddMeshInstance(mesh, xform);
}
""".}

import output/[shared_types, Types, Log, SceneBase, RendererBase]

proc createRayRenderer(): ptr RendererBase {.importc, nodecl.}
proc setupCornellBox(scene: ptr SceneBase, mat1, mat2, mat3, mat4: MaterialHandle) {.importc, nodecl.}

proc floatToByte(val: float32): uint8 =
  if val <= 0.0: 0'u8
  elif val > (1.0 - 0.5/255.0): 255'u8
  else: uint8(255.0 * val + 0.5)

proc saveTGA(filename: string, pixels: color_data_rgba_t, width, height: int) =
  ## Save float RGBA pixels to TGA image file
  var f = open(filename, fmWrite)
  defer: f.close()

  # TGA header (18 bytes)
  var header: array[18, uint8]
  header[2] = 2  # Uncompressed true-color
  header[12] = uint8(width and 0xFF)
  header[13] = uint8((width shr 8) and 0xFF)
  header[14] = uint8(height and 0xFF)
  header[15] = uint8((height shr 8) and 0xFF)
  header[16] = 24  # 24-bit RGB
  header[17] = 0x20  # Origin upper-left
  discard f.writeBuffer(addr header[0], 18)

  let data = cast[ptr UncheckedArray[color_rgba_t]](pixels.`ptr`)
  for y in 0..<height:
    for x in 0..<width:
      let idx = y * pixels.pitch + x
      let c = data[idx]
      # TGA uses BGR order
      let bgr = [floatToByte(c.v[2]), floatToByte(c.v[1]), floatToByte(c.v[0])]
      discard f.writeBuffer(unsafeAddr bgr[0], 3)

proc main() =
  echo "Ray Renderer Nim Bindings Example"
  echo "================================="
  echo ""

  echo "Creating renderer..."
  let renderer = createRayRenderer()
  echo "  Renderer ptr: ", cast[int](renderer)
  if renderer.isNil:
    echo "Failed to create renderer!"
    return

  # Note: device_name() returns std::string_view, needs wrapper for Nim
  echo "  Type: ", renderer.`type`()
  echo "  HWRT: ", renderer.is_hwrt()
  echo ""

  # Create a scene
  echo "Creating scene..."
  let scene = renderer.createScene()
  if scene.isNil:
    echo "Failed to create scene!"
    return

  # Set up camera (matching Cornell box sample)
  var cam: camera_desc_t
  cam.`type` = eCamType.Persp
  cam.filter = ePixelFilter.Box
  cam.origin = [-0.278'f32, 0.273, 0.8]  # Standard Cornell box view
  cam.fwd = [0.0'f32, 0.0, -1.0]
  cam.up = [0.0'f32, 1.0, 0.0]
  cam.fov = 39.1463  # Standard Cornell box FOV
  cam.gamma = 2.2
  cam.exposure = 1.0
  cam.focus_distance = 1.0
  cam.clip_start = 0.01
  cam.clip_end = 100.0
  cam.max_diff_depth = 4
  cam.max_spec_depth = 4
  cam.max_refr_depth = 4
  cam.max_transp_depth = 4
  cam.max_total_depth = 8

  let camHandle = scene.addCamera(cam)
  scene.set_current_cam(camHandle)
  echo "  Camera added"

  # No explicit light - Cornell box uses emissive ceiling quad

  # Set environment (dark background)
  var env: environment_desc_t
  env.env_col = [0.0'f32, 0.0, 0.0]
  env.back_col = [0.0'f32, 0.0, 0.0]
  scene.setEnvironment(env)

  # Create materials using shading_node_desc_t (simpler API)
  var mat_grey: shading_node_desc_t
  mat_grey.`type` = eShadingNode.Diffuse
  mat_grey.base_color = [0.5'f32, 0.5, 0.5]
  let mat1 = scene.addMaterial(mat_grey)

  var mat_red: shading_node_desc_t
  mat_red.`type` = eShadingNode.Diffuse
  mat_red.base_color = [0.5'f32, 0.0, 0.0]
  let mat2 = scene.addMaterial(mat_red)

  var mat_green: shading_node_desc_t
  mat_green.`type` = eShadingNode.Diffuse
  mat_green.base_color = [0.0'f32, 0.5, 0.0]
  let mat3 = scene.addMaterial(mat_green)

  var mat_emit: shading_node_desc_t
  mat_emit.`type` = eShadingNode.Emissive
  mat_emit.strength = 100.0
  mat_emit.importance_sample = true
  let mat4 = scene.addMaterial(mat_emit)
  echo "  Materials added"

  # Add Cornell box mesh (uses C++ helper due to Span types)
  setupCornellBox(scene, mat1, mat2, mat3, mat4)
  echo "  Cornell box mesh added"

  # Finalize scene (build acceleration structures)
  scene.finalize(nil)

  echo "  Scene finalized"
  echo "  Triangles: ", scene.triangle_count()
  echo "  BVH nodes: ", scene.node_count()
  echo ""

  # Set up render region (full image)
  var region = newRegionContext(rect_t(x: 0, y: 0, w: 256, h: 256))

  # Render iterations
  let sampleCount = 64  # More samples for cleaner image
  echo "Rendering ", sampleCount, " samples..."
  for i in 0..<sampleCount:
    renderer.renderScene(scene[], region)
    region.iteration.inc
    if (i + 1) mod 16 == 0:
      echo "  ", i + 1, "/", sampleCount, " samples"

  echo "Rendered ", region.iteration, " samples"

  # Get pixel data and save image
  let pixels = renderer.get_pixels_ref()
  echo "Pixel data pitch: ", pixels.pitch

  let outputFile = "render_output.tga"
  saveTGA(outputFile, pixels, 256, 256)
  echo "Saved: ", outputFile

  # Get stats
  var stats: stats_t
  renderer.getStats(stats)
  echo ""
  echo "Render stats:"
  echo "  Primary ray gen: ", stats.time_primary_ray_gen_us, " us"
  echo "  Primary trace: ", stats.time_primary_trace_us, " us"
  echo "  Primary shade: ", stats.time_primary_shade_us, " us"

  echo ""
  echo "Done!"

when isMainModule:
  main()
