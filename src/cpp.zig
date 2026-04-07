const std = @import("std");
const Schema = @import("Schema.zig");
const IndentedWriter = @import("IndentedWriter.zig");
const case = @import("case");
const Self = @This();

const Map = std.StringHashMap([]const u8);

schema: Schema,
gpa: std.mem.Allocator,
writer: *IndentedWriter,
type_map: Map,
object_map: Map,

pub fn write(schema: Schema, gpa: std.mem.Allocator) ![]const u8 {
    var string: std.Io.Writer.Allocating = .init(gpa);
    var writer: IndentedWriter = .init(&string.writer);

    var self: Self = .{
        .schema = schema,
        .gpa = gpa,
        .writer = &writer,
        .type_map = .init(gpa),
        .object_map = .init(gpa),
    };

    try self.setupTypeMap();
    try self.setupObjectMap();
    try self.writeTypes();
    try self.writeObjects();

    return string.written();
}

fn setupTypeMap(self: *Self) !void {
    const map = &self.type_map;

    try map.put("u8", "uint8_t");
    try map.put("u16", "uint16_t");
    try map.put("u32", "uint32_t");
    try map.put("u64", "uint64_t");

    try map.put("s8", "int8_t");
    try map.put("s16", "int16_t");
    try map.put("s32", "int32_t");
    try map.put("s64", "int64_t");

    try map.put("f32", "float");
    try map.put("f64", "double");

    for (self.schema.types) |t| {
        try map.put(t.name, try case.allocTo(self.gpa, .pascal, t.name));
    }
}

fn setupObjectMap(self: *Self) !void {
    const map = &self.object_map;

    for (self.schema.objects) |o| {
        try map.put(o.name, try case.allocTo(self.gpa, .pascal, o.name));
    }
}

fn writeTypes(self: *Self) !void {
    for (self.schema.types) |t| {
        try self.writeType(t);
    }
}

fn writeType(self: *Self, t: Schema.Type) !void {
    const writer = self.writer;

    // Must have either fields or values
    if ((t.fields != null) == (t.values != null)) {
        // TODO: print error
        return error.BadZon;
    }

    const type_name = self.type_map.get(t.name).?;

    // Write struct
    if (t.fields) |fields| {

        // Struct definition
        try writer.print("struct {s}", .{type_name});
        try writer.print("{{", .{});
        writer.indent();

        for (fields) |field| {
            const field_type = self.type_map.get(field.type) orelse {
                // TODO: print error
                return error.BadZon;
            };
            const field_name = try case.allocTo(self.gpa, .snake, field.name);

            // Add array field
            if (field.array) |array| switch (array) {
                .variable_length => try writer.print("std::vector<{s}> {s};", .{ field_type, field_name }),
                .length => |length| try writer.print("std::array<{s}, {}> {s};", .{ field_type, length, field_name }),
            }
            // Otherwise just type
            else try writer.print("{s} {s};", .{ field_type, field_name });
        }

        writer.deindent();
        try writer.print("}};\n", .{});

        // Read function
        try writer.print("static void read(Reader& reader, {s}& value)", .{type_name});
        try writer.print("{{", .{});
        writer.indent();

        for (fields) |field| {
            const field_name = try case.allocTo(self.gpa, .snake, field.name);
            try writer.print("reader.read(value.{s});", .{field_name});
        }

        writer.deindent();
        try writer.print("}}\n", .{});

        // Write function
        try writer.print("static void write(Writer& writer, const {s}& value)", .{type_name});
        try writer.print("{{", .{});
        writer.indent();

        for (fields) |field| {
            const field_name = try case.allocTo(self.gpa, .snake, field.name);
            try writer.print("writer.write(value.{s});", .{field_name});
        }

        writer.deindent();
        try writer.print("}}\n", .{});
    }

    // Write enum
    if (t.values) |values| {

        // Enum definition
        try writer.print("enum class {s}", .{self.type_map.get(t.name).?});
        try writer.print("{{", .{});
        writer.indent();

        for (values) |value| {
            const value_name = try case.allocTo(self.gpa, .constant, value.name);
            try writer.print("{s} = {},", .{ value_name, value.value });
        }

        writer.deindent();
        try writer.print("}};\n", .{});

        // Read function
        try writer.print("static void read(Reader& reader, {s}& value)", .{type_name});
        try writer.print("{{", .{});
        writer.indent();

        try writer.print("uint8_t temp{{}};", .{});
        try writer.print("reader.read(temp);", .{});
        try writer.print("value = static_cast<{s}>(temp);", .{type_name});

        writer.deindent();
        try writer.print("}}\n", .{});

        // Write function
        try writer.print("static void write(Writer& writer, const {s}& value)", .{type_name});
        try writer.print("{{", .{});
        writer.indent();

        try writer.print("writer.write(static_cast<uint8_t>(value));", .{});

        writer.deindent();
        try writer.print("}}\n", .{});
    }
}

fn writeObjects(self: *Self) !void {
    for (self.schema.objects) |o| {
        try self.writeObject(o);
    }
}

fn writeObject(self: *Self, o: Schema.Object) !void {
    const writer = self.writer;
    const object_name = self.object_map.get(o.name).?;

    try writer.print("struct {s} : public Object", .{object_name});
    try writer.print("{{", .{});
    writer.indent();

    try writer.print("{s}() = default;", .{object_name});
    try writer.print("{s}(uint8_t id, std::span<const uint8_t> prefix, Object& root) : Object(id, prefix, root) {{}}", .{object_name});

    for (o.properties) |p| {
        try self.writeProperty(p);
    }

    writer.deindent();
    try writer.print("}};\n", .{});
}

fn writeProperty(self: *Self, p: Schema.Property) !void {
    const writer = self.writer;

    const type_opt = self.type_map.get(p.type);
    const object_opt = self.object_map.get(p.type);

    // Must have either type or object
    if ((type_opt != null) == (object_opt != null)) {
        // TODO: print error
        return error.BadZon;
    }

    const field_name = try case.allocTo(self.gpa, .snake, p.name);

    if (type_opt) |t| {
        // Add array property
        if (p.array) |array| switch (array) {
            .variable_length => {
                try writer.print(
                    "PropertyArray<Property<{s}>> {s}{{ {}, mPrefix, mRoot }};",
                    .{ t, field_name, p.id },
                );
            },
            .length => |length| {
                try writer.print(
                    "PropertyArray<Property<{s}>> {s}{{ {}, mPrefix, mRoot, {} }};",
                    .{ t, field_name, p.id, length },
                );
            },
        }
        // Otherwise just property
        else try writer.print(
            "Property<{s}> {s}{{ {}, mPrefix, mRoot }};",
            .{ t, field_name, p.id },
        );
    }

    if (object_opt) |o| {
        // Add array property
        if (p.array) |array| switch (array) {
            .variable_length => {
                try writer.print(
                    "PropertyArray<{s}> {s}{{ {}, mPrefix, mRoot }};",
                    .{ o, field_name, p.id },
                );
            },
            .length => |length| {
                try writer.print(
                    "PropertyArray<{s}> {s}{{ {}, mPrefix, mRoot, {} }};",
                    .{ o, field_name, p.id, length },
                );
            },
        }
        // Otherwise just property
        else try writer.print(
            "{s} {s}{{ {}, mPrefix, mRoot }};",
            .{ o, field_name, p.id },
        );
    }
}
