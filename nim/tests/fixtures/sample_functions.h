// Sample function declarations for testing

/// Simple function
int add(int a, int b);

/// Function with pointer params
void processBuffer(const char* data, unsigned int size);

/// Function returning pointer
const char* getName();

/// Function with default param
void setColor(int r, int g, int b, int a = 255);

/// Void function
void doNothing();

/// Function pointer typedef
typedef void (*Callback)(int status, void* userData);

/// Function with callback
void registerCallback(Callback cb, void* userData);

/// Variadic function (should be marked)
void logMessage(const char* format, ...);

namespace utils {
    /// Namespaced function
    int clamp(int value, int min, int max);
}

class Widget {
public:
    /// Constructor
    Widget(int width, int height);

    /// Destructor
    ~Widget();

    /// Const method
    int getWidth() const;

    /// Mutable method
    void setWidth(int width);

    /// Static method
    static Widget* create(int w, int h);

private:
    int m_width;
    int m_height;
};
