// Advanced example - inheritance and templates

#ifndef VEHICLE_H
#define VEHICLE_H

#include <string>
#include <vector>

namespace Transport {

// Base class
class Vehicle {
protected:
    std::string model;
    int year;

public:
    Vehicle(const std::string& model, int year);
    virtual ~Vehicle();

    virtual double maxSpeed() const = 0;
    virtual std::string getType() const = 0;

    std::string getModel() const { return model; }
    int getYear() const { return year; }
};

// Derived class
class Car : public Vehicle {
private:
    int numDoors;

public:
    Car(const std::string& model, int year, int doors);

    double maxSpeed() const override;
    std::string getType() const override;
    int getDoors() const { return numDoors; }
};

// Template class
template<typename T>
class Container {
private:
    std::vector<T> items;

public:
    void add(const T& item) {
        items.push_back(item);
    }

    size_t size() const {
        return items.size();
    }

    T get(size_t index) const {
        return items[index];
    }
};

// Typedef
typedef Container<Vehicle*> VehicleList;

} // namespace Transport

#endif
