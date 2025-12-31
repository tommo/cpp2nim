// Math header - depends on dep_types.h
#pragma once
#include "dep_types.h"

namespace math {

using core::Flags;

struct Vec2 {
    float x, y;
};

struct Vec3 {
    float x, y, z;
};

struct Transform {
    Vec3 position;
    Vec3 rotation;
    Vec3 scale;
    core::Flags flags;
};

// Uses EntityId from types
core::Result moveEntity(core::EntityId id, const Vec3& delta);
core::Result rotateEntity(core::EntityId id, const Vec3& angles);

// Math utilities
float dot(const Vec3& a, const Vec3& b);
Vec3 cross(const Vec3& a, const Vec3& b);
float length(const Vec3& v);
Vec3 normalize(const Vec3& v);

} // namespace math
