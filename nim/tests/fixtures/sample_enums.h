// Sample enum declarations for testing

/// Simple enum
enum Color {
    RED = 0,
    GREEN = 1,
    BLUE = 2
};

/// Enum class (C++11)
enum class Status {
    OK = 0,
    ERROR = 1,
    PENDING = 2
};

/// Enum with explicit type
enum Flags : unsigned int {
    FLAG_NONE = 0,
    FLAG_READ = 1,
    FLAG_WRITE = 2,
    FLAG_EXEC = 4
};

/// Anonymous enum (constants)
enum {
    MAX_SIZE = 1024,
    MIN_SIZE = 64
};
