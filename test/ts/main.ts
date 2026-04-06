
import * as rw from '../../lib/ts/reader_writer';
import {Object2, Packet, Params, Property, PropertyArray} from '../../lib/ts/state';


class ExampleObject extends Object2
{
    example_property: Property<number>;
    example_array: PropertyArray<Property<number>>;

    constructor(params?: Params)
    {
        super(params);

        this.example_property = new Property({id: 1, prefix: this._prefix, root: this._root}, rw.U8);
        this.example_array = new PropertyArray({id: 2, prefix: this._prefix, root: this._root}, (params) => {return new Property<number>(params, rw.U8)});
    }
}

type CustomType = {
    x: number,
    y: number,
}

const CustomTypeDesc: rw.TypeDesc<CustomType> = {
    read: (reader) => {
        return {
            x: rw.F32.read(reader),
            y: rw.F32.read(reader)
        };
    },
    write: (writer, value) => {
        rw.F32.write(writer, value.x);
        rw.F32.write(writer, value.y);        
    },
    default: () => { 
        return {
            x: rw.F32.default(), 
            y: rw.F32.default(),
        }; 
    },
};

class ExampleObject2 extends Object2
{
    custom_type: Property<CustomType>;
    example_property: ExampleObject;
    example_array: PropertyArray<ExampleObject>;

    constructor(params?: Params)
    {
        super(params);

        this.custom_type = new Property({id: 0, prefix: this._prefix, root: this._root}, CustomTypeDesc);
        this.example_property = new ExampleObject({id: 1, prefix: this._prefix, root: this._root});
        this.example_array = new PropertyArray({id: 2, prefix: this._prefix, root: this._root}, (params) => {return new ExampleObject(params)});
    }
}



let example = new ExampleObject2();
example.example_property.example_property.set(5);
example.example_array.resize(4);
example.example_array.get(2).example_property.set(13);
// example.custom_type.set({x: 3, y: 5});

let packet = new Packet(new Uint8Array([0, 64, 64, 0, 0, 64, 160, 0, 0]));
example.receive(packet);

console.log(example.custom_type.value());

// console.log(example._queue);
