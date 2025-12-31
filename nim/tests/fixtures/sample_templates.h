// Sample template declarations for testing

/// Simple template class
template<typename T>
class Array {
public:
    T* data;
    unsigned int count;

    T& operator[](unsigned int index);
    const T& operator[](unsigned int index) const;
    void push(const T& value);
    T pop();
};

/// Template with multiple params
template<typename K, typename V>
class Map {
public:
    void insert(const K& key, const V& value);
    V* find(const K& key);
    bool remove(const K& key);
};

/// Template with non-type param
template<typename T, unsigned int N>
class FixedArray {
public:
    T data[N];
    T& operator[](unsigned int index);
};

/// Template specialization usage
typedef Array<int> IntArray;
typedef Array<float> FloatArray;
typedef Map<const char*, int> StringIntMap;

/// Nested template
typedef Array<Array<float>> Matrix;

namespace containers {
    /// Namespaced template
    template<typename T>
    class List {
    public:
        void append(const T& value);
        T* front();
        T* back();
    };
}
