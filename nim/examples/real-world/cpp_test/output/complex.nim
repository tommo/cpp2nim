# Auto-generated Nim bindings for complex.hpp
# Generated: 2025-12-31T13:41:21+08:00

type
  ccstring* = cstring  ## const char*
  ConstPointer* = pointer  ## const void*

type
  Axis* {.size:sizeof(cint), header: "complex.hpp", importcpp: "math::Axis", pure.} = enum
    X = 0,
    Y = 1,
    Z = 2

  TransformFlags* {.size:sizeof(cuint), header: "complex.hpp", importcpp: "math::TransformFlags", pure.} = enum
    TRANSFORM_NONE = 0,
    TRANSFORM_TRANSLATE = 1,
    TRANSFORM_ROTATE = 2,
    TRANSFORM_SCALE = 4,
    TRANSFORM_ALL = 7

  Color* {.header: "complex.hpp", importcpp: "math::Color".} = object of RootObj
    r*: cfloat
    g*: cfloat
    b*: cfloat
    a*: cfloat
  EventHandler* {.header: "complex.hpp", importcpp: "math::EventHandler".} = object of RootObj
    onUpdate*: proc(arg_0:cfloat){.cdecl}
    onRender*: proc(arg_0:Matrix4){.cdecl}
    onDestroy*: proc(){.cdecl}
    userData*: pointer
  Vector3*[T] {.header: "complex.hpp", importcpp: "math::Vector3", byref.} = object
    x*: T
    y*: T
    z*: T
  Transform* {.header: "complex.hpp", importcpp: "math::Transform", byref.} = object of RootObj
    position* {.importcpp:"position_".}: Vec3f
    rotation* {.importcpp:"rotation_".}: Vec3f
    scale* {.importcpp:"scale_".}: Vec3f
  AnimatedTransform* {.header: "complex.hpp", importcpp: "math::AnimatedTransform", byref.} = object of Transform
  Matrix4* {.header: "complex.hpp", importcpp: "math::Matrix4", byref.} = object
    m*: array[16,cfloat]
  Vec3f* {.header: "complex.hpp", importcpp: "math::Vec3f".} = Vector3[float]
  Vec3d* {.header: "complex.hpp", importcpp: "math::Vec3d".} = Vector3[double]
  Vec3i* {.header: "complex.hpp", importcpp: "math::Vec3i".} = Vector3[int]
  UpdateCallback* {.header: "complex.hpp", importcpp: "math::UpdateCallback".} = proc (deltaTime: cfloat, userData: pointer) {.cdecl.}
  CollisionCallback* {.header: "complex.hpp", importcpp: "math::CollisionCallback".} = proc (a: Transform, b: Transform): bool {.cdecl.}

proc `+`*(self: ptr Color, other: Color): Color {.importcpp: "# + #".}
proc `*`*(self: ptr Color, scalar: cfloat): Color {.importcpp: "# * #".}
proc `==`*(self: ptr Color, other: Color): bool {.importcpp: "# == #".}
proc red*(): Color {.importcpp: "Color::red(@)".}
proc lerp*(a: Color, b: Color, t: cfloat): Color {.importcpp: "Color::lerp(@)".}
proc dot*(self: ptr Vector3, other: Vector3[T]): T {.importcpp: "dot".}
proc cross*(self: ptr Vector3, other: Vector3[T]): Vector3[T] {.importcpp: "cross".}
proc length*(self: ptr Vector3): T {.importcpp: "length".}
proc normalized*(self: ptr Vector3): Vector3[T] {.importcpp: "normalized".}
proc `+`*(self: ptr Vector3, other: Vector3[T]): Vector3[T] {.importcpp: "# + #".}
proc `-`*(self: ptr Vector3, other: Vector3[T]): Vector3[T] {.importcpp: "# - #".}
proc `*`*(self: ptr Vector3, scalar: T): Vector3[T] {.importcpp: "# * #".}
proc `[]`*(self: ptr Vector3, index: cint): T {.importcpp: "#[#]".}
proc `[]`*(self: ptr Vector3, index: cint): var T {.importcpp: "#[#]".}
proc setPosition*(self: ptr Transform, pos: Vec3f) {.importcpp: "setPosition".}
proc setRotation*(self: ptr Transform, rot: Vec3f) {.importcpp: "setRotation".}
proc setScale*(self: ptr Transform, scale: Vec3f) {.importcpp: "setScale".}
proc getPosition*(self: ptr Transform): Vec3f {.importcpp: "getPosition".}
proc getRotation*(self: ptr Transform): Vec3f {.importcpp: "getRotation".}
proc getScale*(self: ptr Transform): Vec3f {.importcpp: "getScale".}
proc toMatrix*(self: ptr Transform): Matrix4 {.importcpp: "toMatrix".}
proc apply*(self: ptr Transform, flags: TransformFlags) {.importcpp: "apply".}
proc setAnimationTime*(self: ptr AnimatedTransform, time: cfloat) {.importcpp: "setAnimationTime".}
proc getAnimationTime*(self: ptr AnimatedTransform): cfloat {.importcpp: "getAnimationTime".}
proc setLooping*(self: ptr AnimatedTransform, loop: bool) {.importcpp: "setLooping".}
proc isLooping*(self: ptr AnimatedTransform): bool {.importcpp: "isLooping".}
proc toMatrix*(self: ptr AnimatedTransform): Matrix4 {.importcpp: "toMatrix".}
proc apply*(self: ptr AnimatedTransform, flags: TransformFlags) {.importcpp: "apply".}
proc update*(self: ptr AnimatedTransform, deltaTime: cfloat) {.importcpp: "update".}
proc identity*(): Matrix4 {.importcpp: "Matrix4::identity(@)".}
proc translation*(x: cfloat, y: cfloat, z: cfloat): Matrix4 {.importcpp: "Matrix4::translation(@)".}
proc rotation*(axis: Axis, angle: cfloat): Matrix4 {.importcpp: "Matrix4::rotation(@)".}
proc scale*(x: cfloat, y: cfloat, z: cfloat): Matrix4 {.importcpp: "Matrix4::scale(@)".}
proc perspective*(fov: cfloat, aspect: cfloat, near: cfloat, far: cfloat): Matrix4 {.importcpp: "Matrix4::perspective(@)".}
proc lookAt*(eye: Vec3f, target: Vec3f, up: Vec3f): Matrix4 {.importcpp: "Matrix4::lookAt(@)".}
proc `*`*(self: ptr Matrix4, other: Matrix4): Matrix4 {.importcpp: "# * #".}
proc `*`*(self: ptr Matrix4, v: Vec3f): Vec3f {.importcpp: "# * #".}
proc inverse*(self: ptr Matrix4): Matrix4 {.importcpp: "inverse".}
proc transpose*(self: ptr Matrix4): Matrix4 {.importcpp: "transpose".}
proc determinant*(self: ptr Matrix4): cfloat {.importcpp: "determinant".}
proc normalize*(v: Vec3f): Vec3f {.importc: "math::normalize".}
proc dot*(a: Vec3f, b: Vec3f): cfloat {.importc: "math::dot".}
proc cross*(a: Vec3f, b: Vec3f): Vec3f {.importc: "math::cross".}
proc inverse*(m: Matrix4): Matrix4 {.importc: "math::inverse".}
proc newColor*(): Color {.constructor,importcpp: "math::Color".}
proc newColor*(r: cfloat, g: cfloat, b: cfloat, a: cfloat): Color {.constructor,importcpp: "math::Color(@)".}
proc newVector3*[T](): Vector3 {.constructor,importcpp: "math::Vector3".}
proc newVector3*[T](x: T, y: T, z: T): Vector3 {.constructor,importcpp: "math::Vector3(@)".}
proc newTransform*(): Transform {.constructor,importcpp: "math::Transform".}
proc newAnimatedTransform*(): AnimatedTransform {.constructor,importcpp: "math::AnimatedTransform".}
proc newAnimatedTransform*(base: Transform): AnimatedTransform {.constructor,importcpp: "math::AnimatedTransform(@)".}
proc newMatrix4*(): Matrix4 {.constructor,importcpp: "math::Matrix4".}
proc newMatrix4*(data: ptr cfloat): Matrix4 {.constructor,importcpp: "math::Matrix4(@)".}
