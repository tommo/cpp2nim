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

// Bug 12: typedef'd struct should not have "struct" prefix in importc
typedef struct {
    int width;
    int height;
} CSize;

// Bug 12: typedef'd enum should not have "enum" prefix in importc
typedef enum {
    MODE_A = 0,
    MODE_B = 1,
    MODE_C = 2
} CMode;

// Bug 13: opaque handle typedef (ptr to forward-declared struct)
struct _CHandle_t;
typedef struct _CHandle_t* CHandle;

// Forward-declared struct used in function params (ggml_context pattern)
struct ForwardDeclared;
void usesForwardDecl(struct ForwardDeclared *ctx);

// Bug 7: ignored type used as pointer param
struct PlatformData {
    int internal[8];
};
void usesPlatformPtr(struct PlatformData *data);

// Bug 15: unsigned char should map to uint8
typedef struct {
    unsigned char r;
    unsigned char g;
    unsigned char b;
} CColor;

// Bug 5: struct with ignoreable field
struct IgnoredInner {
    int platform_data[4];
};

struct OuterStruct {
    int id;
    struct IgnoredInner src;
    float value;
};
