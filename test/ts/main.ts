
import * as example from './example.zon';


const properties = new example.Example();
properties.controls.velocity.set({x: 3, y: 4});
properties.sensors.resize(4);
properties.sensors.at(0).resolution.set(example.Resolution.R1080P);
// properties.sensors.at(1).zoom.resize(3);
properties.sensors.at(1).zoom.set(100);

console.log(properties._queue);