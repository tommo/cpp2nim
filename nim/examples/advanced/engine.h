// Advanced example - engine with multiple dependencies

#ifndef ENGINE_H
#define ENGINE_H

#include "vehicle.h"

namespace Transport {

// Engine type enum
enum class EngineType {
    Gasoline,
    Diesel,
    Electric,
    Hybrid
};

// Engine specs
struct EngineSpecs {
    EngineType type;
    double horsepower;
    double fuelEfficiency;  // km per liter (or kWh for electric)

    EngineSpecs(EngineType t, double hp, double eff);
    std::string toString() const;
};

// Motorcycle - another derived class
class Motorcycle : public Vehicle {
private:
    EngineSpecs engine;
    bool hasSidecar;

public:
    Motorcycle(const std::string& model, int year, EngineSpecs specs);

    double maxSpeed() const override;
    std::string getType() const override;

    bool getSidecar() const { return hasSidecar; }
    void setSidecar(bool value) { hasSidecar = value; }
    EngineSpecs getEngine() const { return engine; }
};

// Factory function with template specialization
template<typename T>
T* createVehicle(const std::string& model, int year);

// Explicit specialization declarations
template<> Car* createVehicle<Car>(const std::string& model, int year);
template<> Motorcycle* createVehicle<Motorcycle>(const std::string& model, int year);

// Fleet manager using templates
class Fleet {
private:
    Container<Vehicle*> vehicles;
    std::string name;

public:
    Fleet(const std::string& name);

    void addVehicle(Vehicle* v);
    size_t count() const;
    Vehicle* get(size_t index) const;

    double totalMaxSpeed() const;
    std::vector<std::string> listModels() const;
};

} // namespace Transport

#endif
