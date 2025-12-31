// Graphics header - depends on dep_types.h and dep_math.h
#pragma once
#include "dep_types.h"
#include "dep_math.h"

namespace graphics {

using core::EntityId;
using core::Flags;
using math::Vec2;
using math::Vec3;
using math::Transform;

struct Color {
    float r, g, b, a;
};

struct Vertex {
    Vec3 position;
    Vec3 normal;
    Vec2 texcoord;
    Color color;
};

struct Mesh {
    EntityId id;
    Vertex* vertices;
    unsigned int vertexCount;
    unsigned int* indices;
    unsigned int indexCount;
    Flags flags;
};

class Renderer {
public:
    Renderer();
    ~Renderer();

    core::Result initialize(int width, int height);
    core::Result shutdown();

    void setTransform(const Transform& transform);
    void drawMesh(const Mesh& mesh);
    void drawLine(const Vec3& start, const Vec3& end, const Color& color);

    EntityId createMesh(const Vertex* vertices, unsigned int count);
    void destroyMesh(EntityId meshId);

private:
    void* context_;
};

// Utility functions
Color lerp(const Color& a, const Color& b, float t);
Color fromHex(unsigned int hex);

} // namespace graphics
