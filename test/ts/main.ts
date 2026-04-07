
import * as rw from '../../lib/ts/reader_writer';
import {Object2, Packet, Params, Property, PropertyArray} from '../../lib/ts/state';

type VectorTwo = {
    x: number,
    y: number,
};

const VectorTwoDesc = rw.makeTypeDesc<VectorTwo>({
    x: rw.F32,
    y: rw.F32,
});

enum Resolution {
    R1080P = 0,
    R720P = 1,
};

class SensorSettings extends Object2
{
    resolution: Property<Resolution>;
    zoom: PropertyArray<Property<number>>;
    constructor(params?: Params)
    {
        super(params);
        this.resolution = new Property(this.makeParams(0), rw.U8);
        this.zoom = new PropertyArray(this.makeParams(1), (params) => { return new Property<number>(params, rw.F32); } );
    }
};

class ControlSettings extends Object2
{
    velocity: Property<VectorTwo>;
    constructor(params?: Params)
    {
        super(params);
        this.velocity = new Property(this.makeParams(0), VectorTwoDesc);
    }
};

class Example extends Object2
{
    sensors: PropertyArray<SensorSettings>;
    controls: ControlSettings;
    constructor(params?: Params)
    {
        super(params);
        this.sensors = new PropertyArray(this.makeParams(0), (params) => { return new SensorSettings(params);}, 4);
        this.controls = new ControlSettings(this.makeParams(1));
    }
};

const properties = new Example();
properties.controls.velocity.set({x: 3, y: 4});
// properties.sensors.resize(4);
properties.sensors.at(0).resolution.set(Resolution.R1080P);
properties.sensors.at(1).zoom.resize(3);
properties.sensors.at(1).zoom.at(0).set(1);

console.log(properties._queue);