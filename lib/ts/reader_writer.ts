
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
};


/// uint8_t
export const U8: TypeDesc<number> = {
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
};


/// uint16_t
export const U16: TypeDesc<number> = {
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
};


/// uint32_t
export const U32: TypeDesc<number> = {
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
};


/// uint64_t
export const U64: TypeDesc<bigint> = {
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
};


/// float
export const F32: TypeDesc<number> = {
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
};


/// double
export const F64: TypeDesc<number> = {
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
};


/// array
export function makeArray<T>(size: number, child: TypeDesc<T>): TypeDesc<T[]>
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
    };
}


/// vector
export function makeVector<T>(child: TypeDesc<T>): TypeDesc<T[]>
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
    };
}
