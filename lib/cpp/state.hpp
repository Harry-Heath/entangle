
#pragma once

#include <variant>
#include <functional>
#include <memory>

#include "reader_writer.hpp"


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

