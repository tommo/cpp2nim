// Simple C++ header example for cpp2nim

#ifndef SIMPLE_TYPES_H
#define SIMPLE_TYPES_H

#include <cstdint>

namespace Graphics {

// Basic enum
enum class Color {
    Red,
    Green,
    Blue,
    Alpha
};

// Simple struct
struct Point {
    float x;
    float y;

    Point(float x, float y);
    float distance() const;
};

// Struct with constructor
struct Rectangle {
    Point topLeft;
    Point bottomRight;
    Color fillColor;

    Rectangle(Point tl, Point br, Color color);
    float area() const;
    bool contains(const Point& p) const;
};

} // namespace Graphics

#endif
