// Base types header - no dependencies
#pragma once

namespace core {

// Basic ID type used across all modules
typedef unsigned int EntityId;
typedef unsigned int ComponentId;

// Flags enum used by multiple modules
enum Flags {
    FLAG_NONE = 0,
    FLAG_ACTIVE = 1 << 0,
    FLAG_VISIBLE = 1 << 1,
    FLAG_ENABLED = 1 << 2
};

// Base result type
struct Result {
    int code;
    const char* message;
};

// Callback type
typedef void (*Callback)(EntityId id, void* userData);

} // namespace core
