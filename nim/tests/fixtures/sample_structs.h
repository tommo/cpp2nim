// Sample struct/class declarations for testing

/// A simple 2D point
struct Point {
    float x;
    float y;
};

/// A 3D vector with methods
struct Vector3 {
    float x, y, z;

    float length() const;
    Vector3 normalized() const;
};

/// Struct with inheritance
struct ColorPoint : public Point {
    unsigned char r, g, b, a;
};

/// Struct with anonymous union
struct Variant {
    int type;
    union {
        int intValue;
        float floatValue;
        char* stringValue;
    };
};

/// Template struct
template<typename T>
struct Container {
    T* data;
    unsigned int size;
    unsigned int capacity;
};

/// Incomplete/opaque struct
struct OpaqueHandle;

/// Union type
union Data {
    int asInt;
    float asFloat;
    char asBytes[4];
};

namespace math {
    /// Namespaced struct
    struct Matrix4x4 {
        float m[16];
    };
}

// Anonymous typedef struct (stb-style pattern)
typedef struct {
    int (*read)(void *user, char *data, int size);
    void (*skip)(void *user, int n);
    int (*eof)(void *user);
} IoCallbacks;

// Simple anonymous typedef struct
typedef struct {
    int x;
    int y;
} SimplePoint;
