// Complex C++ header for testing cpp2nim
#pragma once
#include <cstdint>
#include <cstddef>

namespace math {

// Forward declarations
template<typename T> class Vector3;
class Matrix4;

// Enum class
enum class Axis { X = 0, Y = 1, Z = 2 };

// Flags enum
enum TransformFlags {
    TRANSFORM_NONE = 0,
    TRANSFORM_TRANSLATE = 1 << 0,
    TRANSFORM_ROTATE = 1 << 1,
    TRANSFORM_SCALE = 1 << 2,
    TRANSFORM_ALL = TRANSFORM_TRANSLATE | TRANSFORM_ROTATE | TRANSFORM_SCALE
};

// Simple struct with methods
struct Color {
    float r, g, b, a;

    Color() : r(0), g(0), b(0), a(1) {}
    Color(float r, float g, float b, float a = 1.0f);

    Color operator+(const Color& other) const;
    Color operator*(float scalar) const;
    bool operator==(const Color& other) const;

    static Color red() { return Color(1, 0, 0); }
    static Color lerp(const Color& a, const Color& b, float t);
};

// Template class
template<typename T>
class Vector3 {
public:
    T x, y, z;

    Vector3() : x(0), y(0), z(0) {}
    Vector3(T x, T y, T z) : x(x), y(y), z(z) {}

    T dot(const Vector3<T>& other) const;
    Vector3<T> cross(const Vector3<T>& other) const;
    T length() const;
    Vector3<T> normalized() const;

    Vector3<T> operator+(const Vector3<T>& other) const;
    Vector3<T> operator-(const Vector3<T>& other) const;
    Vector3<T> operator*(T scalar) const;
    T operator[](int index) const;
    T& operator[](int index);
};

// Type aliases
typedef Vector3<float> Vec3f;
typedef Vector3<double> Vec3d;
typedef Vector3<int> Vec3i;

// Class with inheritance
class Transform {
protected:
    Vec3f position_;
    Vec3f rotation_;
    Vec3f scale_;

public:
    Transform();
    virtual ~Transform() = default;

    void setPosition(const Vec3f& pos);
    void setRotation(const Vec3f& rot);
    void setScale(const Vec3f& scale);

    Vec3f getPosition() const { return position_; }
    Vec3f getRotation() const { return rotation_; }
    Vec3f getScale() const { return scale_; }

    virtual Matrix4 toMatrix() const;
    virtual void apply(TransformFlags flags = TRANSFORM_ALL);
};

// Derived class
class AnimatedTransform : public Transform {
private:
    float animationTime_;
    bool looping_;

public:
    AnimatedTransform();
    AnimatedTransform(const Transform& base);

    void setAnimationTime(float time) { animationTime_ = time; }
    float getAnimationTime() const { return animationTime_; }

    void setLooping(bool loop) { looping_ = loop; }
    bool isLooping() const { return looping_; }

    Matrix4 toMatrix() const override;
    void apply(TransformFlags flags = TRANSFORM_ALL) override;
    void update(float deltaTime);
};

// 4x4 Matrix class
class Matrix4 {
public:
    float m[16];

    Matrix4();
    Matrix4(const float* data);

    static Matrix4 identity();
    static Matrix4 translation(float x, float y, float z);
    static Matrix4 rotation(Axis axis, float angle);
    static Matrix4 scale(float x, float y, float z);
    static Matrix4 perspective(float fov, float aspect, float near, float far);
    static Matrix4 lookAt(const Vec3f& eye, const Vec3f& target, const Vec3f& up);

    Matrix4 operator*(const Matrix4& other) const;
    Vec3f operator*(const Vec3f& v) const;
    float& operator()(int row, int col);
    float operator()(int row, int col) const;

    Matrix4 inverse() const;
    Matrix4 transpose() const;
    float determinant() const;
};

// Callback types
typedef void (*UpdateCallback)(float deltaTime, void* userData);
typedef bool (*CollisionCallback)(const Transform& a, const Transform& b);

// Function pointer in struct
struct EventHandler {
    void (*onUpdate)(float dt);
    void (*onRender)(const Matrix4& viewProj);
    void (*onDestroy)();
    void* userData;
};

// Free functions
Vec3f normalize(const Vec3f& v);
float dot(const Vec3f& a, const Vec3f& b);
Vec3f cross(const Vec3f& a, const Vec3f& b);
Matrix4 inverse(const Matrix4& m);

// Template function
template<typename T>
T clamp(T value, T min, T max);

// Const globals
extern const float PI;
extern const float DEG_TO_RAD;
extern const float RAD_TO_DEG;

} // namespace math
