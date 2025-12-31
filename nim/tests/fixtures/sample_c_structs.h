// Sample C struct declarations for testing C mode

// Simple struct
struct CPoint {
    float x;
    float y;
};

// Anonymous typedef struct with function pointers (stb-style pattern)
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

// Union type
union CData {
    int asInt;
    float asFloat;
    char asBytes[4];
};
