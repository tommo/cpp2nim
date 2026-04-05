// Test fixtures for bug fixes (BUGS.md)
// Tests: typedef void, union importc, camelCase, anonymous enums, padding

// Bug 1: typedef void should generate opaque object
typedef void OpaqueType;

// Bug 2: union should get correct importc
typedef union {
    int asInt;
    float asFloat;
    char asBytes[4];
} TestUnion;

// Also test named union
union NamedUnion {
    int x;
    float y;
};

// Bug 3: camelCase should preserve first character
void MYLIB_doSomething(int value);
void myFunc(int x);

// Bug 4 + Feature A: anonymous enum from typedef pattern
typedef unsigned char mylib_key_type;
enum { MYLIB_KEY_A = 1, MYLIB_KEY_B = 2, MYLIB_KEY_C = 3 };

// Bug 5: struct with a field whose type may be ignored
struct InternalData {
    int x;
    int y;
};

struct MyStruct {
    int id;
    InternalData internal;
    float value;
};
