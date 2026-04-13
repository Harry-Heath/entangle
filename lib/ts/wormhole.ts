
/*---------------------------- Read Write Utility ----------------------------*/

class Buffer
{
    private _buffer: DataView;
    private _index: number = 0;
    private _error: boolean = false;

    public constructor(buffer: DataView)
    {
        this._buffer = buffer;
    }

    public error(): boolean { return this._error; }
    public success(): boolean { return !this._error; }
    public done(): boolean { return this._index == this._buffer.byteLength; }
    public index(): number { return this._index; }
    
    public take(count: number): DataView
    {
        if ((this._index + count) > this._buffer.byteLength)
            this._error = true;

        if (this._error)
            return new DataView(this._buffer.buffer, this._index, 0);

        let span = new DataView(this._buffer.buffer, this._index, count);
        this._index += count;
        return span;
    }
}

export class Reader extends Buffer
{
    public constructor(buffer: DataView)
    {
        super(buffer);
    }
}

export class Writer extends Buffer
{
    public constructor(buffer: DataView)
    {
        super(buffer);
    }
}

export type TypeDesc<T> = {
    read: (reader: Reader) => T;
    write: (writer: Writer, value: T) => void;
    default: () => T,
    validate: (value: T) => void;
};


/// uint8_t
const U8: TypeDesc<number> = {
    read: (reader: Reader) => {
        let span = reader.take(1);
        if (span.byteLength == 0) return 0;
        return span.getUint8(0);    
    },

    write: (writer: Writer, value: number) => {
        let span = writer.take(1);
        if (span.byteLength == 0) return;
        span.setUint8(0, value);
    },

    default: () => 0,

    validate: (value: number) => {
        if (!Number.isInteger(value))
            throw new Error("Value is not an integer");

        if ((value < 0) || (value > 0xFF))
            throw new Error("Value is not within U8 range");
    },
};


/// uint16_t
const U16: TypeDesc<number> = {
    read: (reader: Reader) => {
        let span = reader.take(2);
        if (span.byteLength == 0) return 0;
        return span.getUint16(0);
    },

    write: (writer: Writer, value: number) => {
        let span = writer.take(2);
        if (span.byteLength == 0) return;
        span.setUint16(0, value);
    },

    default: () => 0,

    validate: (value: number) => {
        if (!Number.isInteger(value))
            throw new Error("Value is not an integer");

        if ((value < 0) || (value > 0xFF_FF))
            throw new Error("Value is not within U16 range");
    },
};


/// uint32_t
const U32: TypeDesc<number> = {
    read: (reader: Reader) => {
        let span = reader.take(4);
        if (span.byteLength == 0) return 0;
        return span.getUint32(0);
    },

    write: (writer: Writer, value: number) => {
        let span = writer.take(4);
        if (span.byteLength == 0) return;
        span.setUint32(0, value);
    },

    default: () => 0,

    validate: (value: number) => {
        if (!Number.isInteger(value))
            throw new Error("Value is not an integer");

        if ((value < 0) || (value > 0xFF_FF_FF_FF))
            throw new Error("Value is not within U32 range");
    },
};


/// uint64_t
const U64: TypeDesc<bigint> = {
    read: (reader: Reader) => {
        let span = reader.take(8);
        if (span.byteLength == 0) return BigInt(0);
        return span.getBigUint64(0);
    },

    write: (writer: Writer, value: bigint) => {
        let span = writer.take(8);
        if (span.byteLength == 0) return;
        span.setBigUint64(0, value);
    },

    default: () => BigInt(0),

    validate: (value: bigint) => {},
};


/// float
const F32: TypeDesc<number> = {
    read: (reader: Reader) => {
        let span = reader.take(4);
        if (span.byteLength == 0) return 0;
        return span.getFloat32(0);
    },

    write: (writer: Writer, value: number) => {
        let span = writer.take(4);
        if (span.byteLength == 0) return;
        span.setFloat32(0, value);
    },

    default: () => 0,

    validate: (value: number) => {},
};


/// double
const F64: TypeDesc<number> = {
    read: (reader: Reader) => {
        let span = reader.take(8);
        if (span.byteLength == 0) return 0;
        return span.getFloat64(0);
    },
    
    write: (writer: Writer, value: number) => {
        let span = writer.take(8);
        if (span.byteLength == 0) return;
        span.setFloat64(0, value);
    },

    default: () => 0,

    validate: (value: number) => {},
};


/// array
function makeArrayDesc<T>(size: number, child: TypeDesc<T>): TypeDesc<T[]>
{
    return {
        read: (reader: Reader) => {
            let array: T[] = new Array(size);
            for (let i = 0; i < size; i++)
            {
                array[i] = child.read(reader);
            }
            return array;
        },
        
        write: (writer: Writer, values: T[]) => {
            for (let i = 0; i < size; i++)
            {
                child.write(writer, values[i]);
            }
        },

        default: () => {
            let array: T[] = new Array(size);
            for (let i = 0; i < size; i++)
            {
                array[i] = child.default();
            }
            return array;
        },

        validate: (values: T[]) => {
            if (values.length != size)
                throw new Error("Array is wrong size");

            for (let i = 0; i < size; i++)
            {
                child.validate(values[i]);
            }
        },
    };
}


/// vector
function makeVectorDesc<T>(child: TypeDesc<T>): TypeDesc<T[]>
{
    return {
        read: (reader: Reader) => {
            let size = U8.read(reader);
            let array: T[] = new Array(size);
            for (let i = 0; i < size; i++)
            {
                array.push(child.read(reader));
            }
            return array;
        },

        write: (writer: Writer, values: T[]) => {
            let size = values.length;
            U8.write(writer, size);
            for (let i = 0; i < size; i++)
            {
                child.write(writer, values[i]);
            }
        },

        default: () => [],

        validate: (values: T[]) => {
            if (values.length > 255)
                throw new Error("Vector is too large");

            for (let i = 0; i < values.length; i++)
            {
                child.validate(values[i]);
            }
        },
    };
}


/// range
function maxValue(bytes: number)
{
    return (1 << (bytes * 8)) - 1;
}

function makeRangeDesc(bytes: number, min: number, max: number): TypeDesc<number>
{
    return {
        read: (reader: Reader) => {
            let encoded = 0;
            for (let i = bytes; i--;)
            {
                let step = U8.read(reader);
                encoded |= step << (i * 8);
            }
            let t = encoded / maxValue(bytes);
            return min * (1 - t) + max * t;
        },

        write: (writer: Writer, value: number) => {
            let t = (value - min) / (max - min);
            let encoded = Math.round(t * maxValue(bytes));
            for (let i = bytes; i--;)
            {
                let step = (encoded >> (i * 8)) & 0xff;
                U8.write(writer, step);
            }
        },

        default: () => min,

        validate: (value: number) => {
            if (value < min || value > max)
                throw new Error("Value outside of range");
        },
    };
}


function makeTypeDesc<T>(
    fields: { [K in keyof T]: TypeDesc<T[K]> }
): TypeDesc<T> {
    return {
        read: (reader: Reader) => {
            let result = {} as T;
            for (const key in fields) {
                result[key] = fields[key].read(reader);
            }
            return result;
        },

        write: (writer: Writer, value: T) => {
            for (const key in fields) {
                fields[key].write(writer, value[key]);
            }
        },

        default: () => {
            let result = {} as T;
            for (const key in fields) {
                result[key] = fields[key].default();
            }
            return result;
        },

        validate: (value: T) => {
            for (const key in fields) {
                fields[key].validate(value[key]);
            }
        },
    };
}

export const types = {
    U8: U8,
    U16: U16,
    U32: U32,
    U64: U64,

    F32: F32,
    F64: F64,

    makeArrayDesc: makeArrayDesc,
    makeVectorDesc: makeVectorDesc,
    makeTypeDesc: makeTypeDesc,
    makeRangeDesc: makeRangeDesc,
};


/*------------------------------ Wormhole Types ------------------------------*/


export class Packet
{
    public static readonly MAX_SIZE = 32;
    public buffer: Uint8Array;
    public length: number;

    constructor(length: number);
    constructor(data: Uint8Array);
    constructor(param: number | Uint8Array)
    {
        if (typeof param === "number")
        {
            this.buffer = new Uint8Array(Packet.MAX_SIZE);
            this.length = param;
        }
        else
        {
            this.buffer = param;
            this.length = this.buffer.byteLength;
        }
    }

    view(): DataView
    {
        return new DataView(this.buffer.buffer, 0, this.length);
    }
}

interface IProperty
{
    read(reader: Reader): void
}

type Node = Map<number, Node> | IProperty;

export type Params = { 
    id: number, 
    prefix: number[], 
    root: WhObject 
};

function makeParams(id: number, prefix: number[], root: WhObject): Params
{
    return {
        id: id,
        prefix: prefix,
        root: root,
    };
}

export class WhObject
{
    _prefix: number[];
    _root: WhObject;

    _map: Map<number, Node> = new Map();
    _queue: Packet[] = [];

    constructor(params?: Params)
    {
        if (params != undefined)
        {
            this._prefix = [...params.prefix, params.id];
            this._root = params.root;
        }   
        else
        {
            this._prefix = [];
            this._root = this;
        }     
    }

    makeParams(id: number): Params
    {
        return makeParams(id, this._prefix, this._root);
    }

    addProperty(prefix: number[], property: IProperty): void
    {
        if (prefix.length == 0) return;

        let map = this._map;
        for (let i = 0; i < prefix.length - 1; i++)
        {
            let id = prefix[i];
            let value = map.get(id);
            if (value == undefined)
            {
                value = new Map();
                map.set(id, value);
            }

            // TODO: make sure this a map
            map = value as Map<number, Node>;
        }

        map.set(prefix[prefix.length - 1], property);
    }

    removeProperty(prefix: number[]): void
    {
        if (prefix.length == 0) return;

        let map = this._map;
        for (let i = 0; i < prefix.length - 1; i++)
        {
            let id = prefix[i];
            let value = map.get(id);
            if (value == undefined) return;

            // TODO: make sure this a map
            map = value as Map<number, Node>;
        }

        map.delete(prefix[prefix.length - 1]);
    }

    receive(packet: Packet): void
    {
        let reader = new Reader(packet.view());

        let map = this._map;
        while (true)
        {
            let id = U8.read(reader);
            if (reader.error())
                break;

            let value = map.get(id);
            if (value == undefined) 
                break;

            if (value instanceof Map)
            {
                map = value;
            }
            else
            {
                value.read(reader);
            }
        }
    }
}


export class Property<T> implements IProperty
{
    _prefix: number[];
    _root: WhObject;
    _typeDesc: TypeDesc<T>;

    _value: T;
    _changed: (value: T) => void = () => {};

    constructor(params: Params, typeDesc: TypeDesc<T>)
    {
        this._prefix = [...params.prefix, params.id];
        this._root = params.root;
        this._typeDesc = typeDesc;
        this._value = typeDesc.default();
        
        this._root.addProperty(this._prefix, this);
    }

    read(reader: Reader): void
    {
        let temp = this._typeDesc.read(reader);
        if (!reader.done())
        {
            reader.take(10000); // TODO: set error
            return;
        }

        if (reader.error())
            return;

        this._value = temp;
        this._changed(this._value);
    }

    set(value: T): void
    {
        this._typeDesc.validate(value);
        this._value = value;
        
        let packet = new Packet(Packet.MAX_SIZE);
        let writer = new Writer(packet.view());

        for (let i = 0; i < this._prefix.length; i++)
            U8.write(writer, this._prefix[i]);

        this._typeDesc.write(writer, this._value);
        packet.length = writer.index();

        if (writer.success())
            this._root._queue.push(packet);
    }

    value(): T
    {
        return this._value;
    }
}


export class PropertyArray<T>
{
    _prefix: number[];
    _root: WhObject;

    _resizable: boolean;
    _size: number;

    _properties: T[];
    _sizeProperty?: Property<number>;
    _sizeChanged: (value: number) => void = () => {};

    _factory: (params: Params) => T;

    constructor(params: Params, factory: (params: Params) => T, size: number = 0)
    {
        this._prefix = [...params.prefix, params.id];
        this._root = params.root;

        this._resizable = size == 0;
        this._size = size;

        this._properties = [];
        this._factory = factory;

        if (this._resizable)
        {
            this._sizeProperty = new Property(makeParams(255, this._prefix, this._root), U8);
            this._sizeProperty._changed = (size: number) => {
                this.resizeArray(size);
                this._sizeChanged(size);
            };
        }
        else
        {
            this.resizeArray(this._size);
        }
    }

    resizeArray(size: number): void
    {
        this._root.removeProperty(this._prefix);

        if (this._resizable)
            this._root.addProperty(this._sizeProperty!._prefix, this._sizeProperty!);

        this._properties = [];
        for (let i = 0; i < size; i++)
        {
            this._properties.push(this._factory(makeParams(i, this._prefix, this._root)));
        }
    }

    resize(size: number): void
    {
        if (!this._resizable) return;

        this.resizeArray(size);
        this._sizeProperty!.set(size);
    }

    size(): number { return this._properties.length; }

    resizable(): boolean { return this._resizable; }

    at(index: number): T { return this._properties[index]; }
}