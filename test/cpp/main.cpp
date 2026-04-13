
#include "example.zon.hpp"

int main()
{
    Example properties{};
    properties.controls.velocity.set({3, 4});
    properties.sensors.resize(4);
    properties.sensors[0].resolution.set(Resolution::R1080P);
    // properties.sensors[1].zoom.resize(3);
    properties.sensors[1].zoom.set(100.f);

    printf("%lld\n", properties.mQueue.size());

    for (const wh::Packet& packet : properties.mQueue)
    {
        printf("{ ");
        for (int i = 0; i < packet.mLength; i++)
        {
            printf("%02X ", packet.mpData[i]);
        }
        printf("}\n");
    }

    wh::Packet test{.mLength = 3, .mpData = {0, 0xFF, 0}};
    properties.receive(test);

    printf("%d\n", (uint8_t)properties.sensors.size());


    // PROPERTIES[0].index();
    // Properties properties{};
    // properties.sensors[0].resolution.set({1920, 1080});
    // uint8_t zoom = properties.sensors[1].zoom_level.get();
    // properties.controls.velocity_demand.fetch();
    

    return 0;
}