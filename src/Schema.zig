types: []const Type = &.{},
objects: []const Object,

pub const Type = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    fields: ?[]const Field = null,
    values: ?[]const EnumValue = null,
    range: ?Range = null,
};

pub const Object = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    properties: []const Property,
};

pub const Property = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    id: u8,
    array: ?Array = null,
    type: []const u8,
};

pub const Field = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    array: ?Array = null,
    type: []const u8,
};

pub const EnumValue = struct {
    name: []const u8,
    value: u8,
};

pub const Range = struct {
    min: f32,
    max: f32,
    bytes: u32,
};

pub const Array = union(enum) {
    variable_length,
    length: u8,
};
