// C-mode test fixtures for bug fixes (BUGS.md)

// Bug 1: typedef void should generate opaque object
typedef void OpaqueHandle;

// Bug 2: union should get "union" not "struct" in importc
typedef union {
    int asInt;
    float asFloat;
    char asBytes[4];
} CTestUnion;

union CNamedUnion {
    int x;
    float y;
};

// Bug 3: functions with uppercase prefix
void CLIB_initialize(int flags);
void CLIB_shutdown(void);

// Bug 5: struct with ignoreable field
struct IgnoredInner {
    int platform_data[4];
};

struct OuterStruct {
    int id;
    struct IgnoredInner src;
    float value;
};
