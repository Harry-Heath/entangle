
#include <string>
#include <array>
#include <vector>
#include <cstdint>
#include <cstddef>
#include <variant>

#include <state.hpp>

struct VectorTwo
{
    float x;
    float y;
};

static void read(Reader& reader, VectorTwo& value)
{
    reader.read(value.x);
    reader.read(value.y);
}

static void write(Writer& writer, const VectorTwo& value)
{
    writer.write(value.x);
    writer.write(value.y);
}

enum class Resolution
{
    R1080P = 0,
    R720P = 1,
};

static void read(Reader& reader, Resolution& value)
{
    uint8_t temp{};
    reader.read(temp);
    value = static_cast<Resolution>(temp);
}

static void write(Writer& writer, const Resolution& value)
{
    writer.write(static_cast<uint8_t>(value));
}

struct SensorSettings : public Object
{
    SensorSettings() = default;
    SensorSettings(uint8_t id, std::span<const uint8_t> prefix, Object& root) : Object(id, prefix, root) {}
    Property<Resolution> resolution{ 0, mPrefix, mRoot };
    PropertyArray<Property<float>> zoom{ 1, mPrefix, mRoot };
};

struct ControlSettings : public Object
{
    ControlSettings() = default;
    ControlSettings(uint8_t id, std::span<const uint8_t> prefix, Object& root) : Object(id, prefix, root) {}
    Property<VectorTwo> velocity{ 0, mPrefix, mRoot };
};

struct Example : public Object
{
    Example() = default;
    Example(uint8_t id, std::span<const uint8_t> prefix, Object& root) : Object(id, prefix, root) {}
    PropertyArray<SensorSettings> sensors{ 0, mPrefix, mRoot, 4 };
    ControlSettings controls{ 1, mPrefix, mRoot };
};

int main()
{
    Example properties{};
    properties.controls.velocity.set({3, 4});
    // properties.sensors.resize(4);
    properties.sensors[0].resolution.set(Resolution::R1080P);
    properties.sensors[1].zoom.resize(3);
    properties.sensors[1].zoom[0].set(1);

    printf("%lld\n", properties.mQueue.size());

    for (const Packet& packet : properties.mQueue)
    {
        printf("{ ");
        for (int i = 0; i < packet.mLength; i++)
        {
            printf("%02X ", packet.mpData[i]);
        }
        printf("}\n");
    }

    Packet test{.mLength = 3, .mpData = {0, 0xFF, 0}};
    properties.receive(test);

    printf("%d\n", (uint8_t)properties.sensors.size());


    // PROPERTIES[0].index();
    // Properties properties{};
    // properties.sensors[0].resolution.set({1920, 1080});
    // uint8_t zoom = properties.sensors[1].zoom_level.get();
    // properties.controls.velocity_demand.fetch();
    

    return 0;
}