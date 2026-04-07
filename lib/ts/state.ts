
import * as rw from './reader_writer';

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
    read(reader: rw.Reader): void
}

type Node = Map<number, Node> | IProperty;

export type Params = { 
    id: number, 
    prefix: number[], 
    root: Object2 
};

export function makeParams(id: number, prefix: number[], root: Object2): Params
{
    return {
        id: id,
        prefix: prefix,
        root: root,
    };
}

export class Object2
{
    _prefix: number[];
    _root: Object2;

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
        let reader = new rw.Reader(packet.view());

        let map = this._map;
        while (true)
        {
            let id = rw.U8.read(reader);
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
    _root: Object2;
    _typeDesc: rw.TypeDesc<T>;

    _value: T;
    _changed: (value: T) => void = () => {};

    constructor(params: Params, typeDesc: rw.TypeDesc<T>)
    {
        this._prefix = [...params.prefix, params.id];
        this._root = params.root;
        this._typeDesc = typeDesc;
        this._value = typeDesc.default();
        
        this._root.addProperty(this._prefix, this);
    }

    read(reader: rw.Reader): void
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
        let writer = new rw.Writer(packet.view());

        for (let i = 0; i < this._prefix.length; i++)
            rw.U8.write(writer, this._prefix[i]);

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
    _root: Object2;

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
            this._sizeProperty = new Property(makeParams(255, this._prefix, this._root), rw.U8);
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