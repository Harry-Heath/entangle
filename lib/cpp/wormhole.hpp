
#ifndef WORMHOLE_HPP
#define WORMHOLE_HPP

#include <cstdint>
#include <cstddef>
#include <cmath>
#include <vector>
#include <map>
#include <span>
#include <array>
#include <variant>
#include <functional>
#include <memory>

namespace wh
{

/*---------------------------- Read Write Utility ----------------------------*/

class Reader
{
    std::span<const uint8_t> mBuffer;
    size_t mIndex = 0;
    bool mError = false;

public:
    Reader(std::span<const uint8_t> buffer) : mBuffer(buffer) {}

    bool error() { return mError; }
    bool success() { return !mError; }
    bool done() { return mIndex == mBuffer.size(); }
    size_t index() { return mIndex; }

    std::span<const uint8_t> take(size_t count)
    {
        if ((mIndex + count) > mBuffer.size())
            mError = true;

        if (mError)
            return {};

        std::span<const uint8_t> span = mBuffer.subspan(mIndex, count);
        mIndex += count;
        return span;
    }

    template<typename T>
    void read(T& value)
    {
        read_from(*this, value);
    }
};


class Writer
{
    std::span<uint8_t> mBuffer;
    size_t mIndex = 0;
    bool mError = false;

public:
    Writer(std::span<uint8_t> buffer) : mBuffer(buffer) {}

    bool error() { return mError; }
    bool success() { return !mError; }
    size_t index() { return mIndex; }

    std::span<uint8_t> take(size_t count)
    {
        if ((mIndex + count) > mBuffer.size())
            mError = true;

        if (mError)
            return {};

        std::span<uint8_t> span = mBuffer.subspan(mIndex, count);
        mIndex += count;
        return span;
    }

    template<typename T>
    void write(const T& value)
    {
        write_to(*this, value);
    }
};


template<typename T>
static void read_from(Reader& reader, T& value) { read(reader, value); }

template<typename T>
static void write_to(Writer& writer, const T& value) { write(writer, value); }


/// uint8_t
static void read(Reader& reader, uint8_t& value)
{
    auto span = reader.take(1);
    if (span.size() == 0) 
        return;

    value = span[0];
}

static void write(Writer& writer, const uint8_t& value)
{
    auto span = writer.take(1);
    if (span.size() == 0) 
        return;

    span[0] = value;
}


/// uint16_t
static void read(Reader& reader, uint16_t& value)
{
    auto span = reader.take(2);
    if (span.size() == 0) 
        return;

    value = ((uint16_t)span[0] << 8) |
            (uint16_t)span[1];
}

static void write(Writer& writer, const uint16_t& value)
{
    auto span = writer.take(2);
    if (span.size() == 0) 
        return;

    span[0] = (value >> 8) & 0xff;
    span[1] = value & 0xff;
}


/// uint32_t
static void read(Reader& reader, uint32_t& value)
{
    auto span = reader.take(4);
    if (span.size() == 0) 
        return;

    value = ((uint32_t)span[0] << 24) |
            ((uint32_t)span[1] << 16) |
            ((uint32_t)span[2] << 8) |
            (uint32_t)span[3];
}

static void write(Writer& writer, const uint32_t& value)
{
    auto span = writer.take(4);
    if (span.size() == 0) 
        return;

    span[0] = (value >> 24) & 0xff;
    span[1] = (value >> 16) & 0xff;
    span[2] = (value >> 8) & 0xff;
    span[3] = value & 0xff;
}


/// uint64_t
static void read(Reader& reader, uint64_t& value)
{
    auto span = reader.take(8);
    if (span.size() == 0) 
        return;

    value = ((uint64_t)span[0] << 56) |
            ((uint64_t)span[1] << 48) |
            ((uint64_t)span[2] << 40) |
            ((uint64_t)span[3] << 32) |
            ((uint64_t)span[4] << 24) |
            ((uint64_t)span[5] << 16) |
            ((uint64_t)span[6] << 8) |
            (uint64_t)span[7];
}

static void write(Writer& writer, const uint64_t& value)
{
    auto span = writer.take(8);
    if (span.size() == 0) 
        return;

    span[0] = (value >> 56) & 0xff;
    span[1] = (value >> 48) & 0xff;
    span[2] = (value >> 40) & 0xff;
    span[3] = (value >> 32) & 0xff;
    span[4] = (value >> 24) & 0xff;
    span[5] = (value >> 16) & 0xff;
    span[6] = (value >> 8) & 0xff;
    span[7] = value & 0xff;
}


/// float
static void read(Reader& reader, float& value)
{
    union Cast
    {
        float mFloat; 
        uint32_t mInt;
    };

    Cast cast{0.f};
    reader.read(cast.mInt);
    value = cast.mFloat;
}

static void write(Writer& writer, const float& value)
{
    union Cast
    {
        float mFloat; 
        uint32_t mInt;
    };

    Cast cast{value};
    writer.write(cast.mInt);
}


/// double
static void read(Reader& reader, double& value)
{
    union Cast
    {
        double mFloat; 
        uint64_t mInt;
    };

    Cast cast{0.f};
    reader.read(cast.mInt);
    value = cast.mFloat;
}

static void write(Writer& writer, const double& value)
{
    union Cast
    {
        double mFloat; 
        uint64_t mInt;
    };

    Cast cast{value};
    writer.write(cast.mInt);
}


/// std::array
template<typename T, size_t L>
static void read(Reader& reader, std::array<T, L>& value)
{
    for (int i = 0; i < L; i++)
    {
        reader.read(value[i]);
    }
}

template<typename T, size_t L>
static void write(Writer& writer, const std::array<T, L>& value)
{
    for (int i = 0; i < L; i++)
    {
        writer.write(value[i]);
    }
}


/// std::vector
template<typename T>
static void read(Reader& reader, std::vector<T>& value)
{
    uint8_t size{};
    reader.read(size);
    value.resize(size);
    for (int i = 0; i < size; i++)
    {
        reader.read(value[i]);
    }
}

template<typename T>
static void write(Writer& writer, const std::vector<T>& value)
{
    uint8_t size = (uint8_t)value.size();
    writer.write(size);
    for (int i = 0; i < size; i++)
    {
        writer.write(value[i]);
    }
}


/// range
static uint64_t max_value(uint8_t bytes)
{
    return ((uint64_t)1 << (bytes * 8)) - 1;
}

static void read_range(Reader& reader, float& value, uint8_t bytes, float min, float max)
{
    // Read encoded
    uint64_t encoded = 0;
    for (uint8_t i = bytes; i--;)
    {
        uint8_t step{};
        reader.read(step);
        encoded |= (uint64_t)step << (i * 8);
    }

    // Lerp between min max
    double t = encoded / (double)max_value(bytes);
    value = min * (1.0 - t) + max * t;
}

static void write_range(Writer& writer, float value, uint8_t bytes, float min, float max)
{
    // Inverse lerp between min max
    double t = (value - min) / (max - min);
    uint64_t encoded = round(t * max_value(bytes));

    // Write encoded
    for (uint8_t i = bytes; i--;)
    {
        uint8_t step = encoded >> (i * 8);
        writer.write(step);
    }
}


/*------------------------------ Wormhole Types ------------------------------*/


struct Packet
{
    static constexpr uint8_t MAX_SIZE = 32;
    
    uint8_t mLength{};
    uint8_t mpData[MAX_SIZE]{};

    uint8_t* begin() { return mpData; }
    uint8_t* end() { return mpData + mLength; }

    const uint8_t* begin() const { return mpData; }
    const uint8_t* end() const { return mpData + mLength; }
};


struct IProperty
{
    virtual ~IProperty() = default;
    virtual void read(Reader& reader) = 0;
};


struct Node
{
    using Map = std::map<uint8_t, Node>;
    std::variant<Map, IProperty*> mValue;

    template<typename... Args>
    Node(Args&&... args) : mValue{std::forward<Args>(args)...} {}
};


static std::vector<uint8_t> make_prefix(std::span<const uint8_t> prefix, uint8_t id) 
{
    std::vector<uint8_t> vector(prefix.begin(), prefix.end());
    vector.push_back(id);
    return vector;
}


struct Object
{
    std::vector<uint8_t> mPrefix;
    Object& mRoot;

    Node::Map mMap{};
    std::vector<Packet> mQueue{};

    Object()
        : mPrefix({})
        , mRoot(*this)
    {
    }

    Object(uint8_t id, std::span<const uint8_t> prefix, Object& root)
        : mPrefix(make_prefix(prefix, id))
        , mRoot(root)
    {
    }

    void addProperty(std::span<const uint8_t> prefix, IProperty* property)
    {
        if (prefix.size() == 0) return;

        Node::Map* map = &mMap;
        for (int i = 0; i < prefix.size() - 1; i++)
        {
            uint8_t id = prefix[i];
            auto it = map->find(id);
            if (it == map->end())
                it = map->insert({id, Node::Map{}}).first;

            // TODO: Make sure this is a map
            auto& variant = it->second.mValue;
            map = &std::get<Node::Map>(variant);
        }

        map->insert({prefix[prefix.size() - 1], property});
    }

    void removeProperty(std::span<const uint8_t> prefix)
    {
        if (prefix.size() == 0) return;

        Node::Map* map = &mMap;
        for (int i = 0; i < prefix.size() - 1; i++)
        {
            uint8_t id = prefix[i];
            auto it = map->find(id);
            if (it == map->end()) return;

            // TODO: Make sure this is a map
            auto& variant = it->second.mValue;
            map = &std::get<Node::Map>(variant);
        }

        map->erase(prefix[prefix.size() - 1]);
    }

    void receive(const Packet& packet)
    {
        Reader reader{packet};

        Node::Map* map = &mMap;
        while (true)
        {
            uint8_t id{};
            reader.read(id);

            if (reader.error()) 
                break;

            auto it = map->find(id);
            if (it == map->end()) 
                break;

            std::variant<Node::Map, IProperty*>& variant = it->second.mValue;
            if (Node::Map* next_map = std::get_if<Node::Map>(&variant))
            {
                map = next_map;
            }
            else if (IProperty** property = std::get_if<IProperty*>(&variant))
            {
                (*property)->read(reader);
                break;
            }
        }
    }

    template<typename Func>
    void send(Func&& func)
    {
        for (Packet& packet : mQueue)
        {
            func(packet);
        }
        mQueue.clear();
    }
};





template<typename T>
struct Property : public IProperty
{
    std::vector<uint8_t> mPrefix;
    Object& mRoot;
    
    T mValue{};
    std::function<void(const T&)> mChanged{};

    Property(uint8_t id, std::span<const uint8_t> prefix, Object& root)
        : mPrefix(make_prefix(prefix, id))
        , mRoot(root)
    {
        mRoot.addProperty(mPrefix, this);
    }

    Property(const Property&) = delete;
    Property& operator=(const Property&) = delete;

    void read(Reader& reader) final 
    {
        T temp{};
        reader.read(temp);

        if (!reader.done())
            reader.take(10000); // TODO: set error

        if (reader.error())
            return;
        
        mValue = temp;

        if (mChanged) 
            mChanged(mValue);
    }

    void set(const T& value)
    {
        mValue = value;

        Packet packet{Packet::MAX_SIZE};
        Writer writer{packet};

        for (const uint8_t& b : mPrefix)
            writer.write(b);

        writer.write(mValue);
        packet.mLength = writer.index();
        
        if (writer.success())
            mRoot.mQueue.push_back(packet);
    }

    const T& value() const
    {
        return mValue;
    }
};


template<typename T>
struct PropertyArray
{
    std::vector<uint8_t> mPrefix;
    Object& mRoot;

    bool mResizable{};
    uint8_t mSize{};

    std::vector<std::unique_ptr<T>> mProperties{};
    std::unique_ptr<Property<uint8_t>> mpSizeProperty{};
    std::function<void(uint8_t)> mSizeChanged{};

    PropertyArray(uint8_t id, std::span<const uint8_t> prefix, Object& root, uint8_t size = 0)
        : mPrefix(make_prefix(prefix, id))
        , mRoot(root)
        , mResizable(size == 0)
        , mSize(size)
    {
        if (mResizable)
        {
            mpSizeProperty = std::make_unique<Property<uint8_t>>(UINT8_MAX, mPrefix, mRoot);
            mpSizeProperty->mChanged = [this](uint8_t size)
            {
                this->resizeArray(size);
                if (this->mSizeChanged) this->mSizeChanged(size);
            };
        }
        else
        {
            resizeArray(mSize);
        }
    }

    void resizeArray(uint8_t size)
    {
        mRoot.removeProperty(mPrefix);

        if (mResizable) 
            mRoot.addProperty(mpSizeProperty->mPrefix, mpSizeProperty.get());

        mProperties.clear();
        for (uint8_t i = 0; i < size; i++)
        {
            mProperties.push_back(std::make_unique<T>(i, mPrefix, mRoot));
        }
    }

    void resize(uint8_t size)
    {
        if (!mResizable) 
            return;

        resizeArray(size);
        mpSizeProperty->set(size);
    }

    uint8_t size() const { return (uint8_t)mProperties.size(); }
    bool resizable() const { return mResizable; }

    T& operator[](uint8_t index)
    {
        return *mProperties[index];
    } 

    const T& operator[](uint8_t index) const
    {
        return *mProperties[index];
    }
};



} // namespace wh

#endif