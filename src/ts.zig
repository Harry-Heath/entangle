const std = @import("std");
const Schema = @import("Schema.zig");
const IndentedWriter = @import("IndentedWriter.zig");
const case = @import("case");
const Self = @This();

schema: Schema,
gpa: std.mem.Allocator,
writer: *IndentedWriter,
type_map: std.StringHashMap(TypeInfo),
object_map: std.StringHashMap([]const u8),

const TypeInfo = struct {
    type_name: []const u8,
    desc_name: []const u8,
};

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

    try map.put("u8", .{ .type_name = "number", .desc_name = "rw.U8" });
    try map.put("u16", .{ .type_name = "number", .desc_name = "rw.U16" });
    try map.put("u32", .{ .type_name = "number", .desc_name = "rw.U32" });
    try map.put("u64", .{ .type_name = "bigint", .desc_name = "rw.U64" });

    // TODO: signed

    try map.put("f32", .{ .type_name = "number", .desc_name = "rw.F32" });
    try map.put("f64", .{ .type_name = "number", .desc_name = "rw.F64" });

    for (self.schema.types) |t| {

        // Must have either fields or values
        if ((t.fields != null) == (t.values != null)) {
            // TODO: print error
            return error.BadZon;
        }

        const type_name = try case.allocTo(self.gpa, .pascal, t.name);
        const rw_type = if (t.values != null) "rw.U8" else try std.fmt.allocPrint(self.gpa, "{s}Desc", .{type_name});
        try map.put(t.name, .{ .type_name = type_name, .desc_name = rw_type });
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
    const type_info = self.type_map.get(t.name).?;

    // Write type
    if (t.fields) |fields| {

        // Type definition
        try writer.print("type {s} = {{", .{type_info.type_name});
        writer.indent();

        for (fields) |field| {
            const field_type = self.type_map.get(field.type) orelse {
                // TODO: print error
                return error.BadZon;
            };
            const field_name = try case.allocTo(self.gpa, .snake, field.name);

            if (field.array) |_|
                try writer.print("{s}: {s}[],", .{ field_name, field_type.type_name })
            else
                try writer.print("{s}: {s},", .{ field_name, field_type.type_name });
        }

        writer.deindent();
        try writer.print("}};\n", .{});

        // Desc definition
        try writer.print("const {s} = rw.makeTypeDesc<{s}>({{", .{ type_info.desc_name, type_info.type_name });
        writer.indent();

        for (fields) |field| {
            const field_type = self.type_map.get(field.type).?;
            const field_name = try case.allocTo(self.gpa, .snake, field.name);

            if (field.array) |array| switch (array) {
                .variable_length => try writer.print("{s}: rw.makeVectorDesc({s}),", .{ field_name, field_type.desc_name }),
                .length => |length| try writer.print("{s}: rw.makeArrayDesc({}, {s}),", .{ field_name, length, field_type.desc_name }),
            } else try writer.print("{s}: {s},", .{ field_name, field_type.desc_name });
        }

        writer.deindent();
        try writer.print("}});\n", .{});
    }

    // Write enum
    if (t.values) |values| {

        // Enum definition
        try writer.print("enum {s} {{", .{type_info.type_name});
        writer.indent();

        for (values) |value| {
            const value_name = try case.allocTo(self.gpa, .constant, value.name);
            try writer.print("{s} = {},", .{ value_name, value.value });
        }

        writer.deindent();
        try writer.print("}};\n", .{});
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

    try writer.print("class {s} extends Object2", .{object_name});
    try writer.print("{{", .{});
    writer.indent();

    var constructor_string: std.Io.Writer.Allocating = .init(self.gpa);
    var constructor_writer: IndentedWriter = .init(&constructor_string.writer);
    constructor_writer.indent_level = writer.indent_level + 1;

    for (o.properties) |p| {
        try self.writeProperty(p, &constructor_writer);
    }

    try writer.print("constructor(params?: Params)", .{});
    try writer.print("{{", .{});
    writer.indent();

    try writer.print("super(params);", .{});
    try writer.write(constructor_string.written());

    writer.deindent();
    try writer.print("}}", .{});

    writer.deindent();
    try writer.print("}};\n", .{});
}

fn writeProperty(self: *Self, p: Schema.Property, constructor_writer: *IndentedWriter) !void {
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
                    "{s}: PropertyArray<Property<{s}>>;",
                    .{ field_name, t.type_name },
                );
                try constructor_writer.print(
                    "this.{s} = new PropertyArray(this.makeParams({}), (params) => {{ return new Property<{s}>(params, {s}); }} );",
                    .{ field_name, p.id, t.type_name, t.desc_name },
                );
            },
            .length => |length| {
                try writer.print(
                    "{s}: PropertyArray<Property<{s}>>;",
                    .{ field_name, t.type_name },
                );
                try constructor_writer.print(
                    "this.{s} = new PropertyArray(this.makeParams({}), (params) => {{ return new Property<{s}>(params, {s}); }}, {} );",
                    .{ field_name, p.id, t.type_name, t.desc_name, length },
                );
            },
        }
        // Otherwise just property
        else {
            try writer.print("{s}: Property<{s}>;", .{ field_name, t.type_name });
            try constructor_writer.print(
                "this.{s} = new Property(this.makeParams({}), {s});",
                .{ field_name, p.id, t.desc_name },
            );
        }
    }

    if (object_opt) |o| {
        // Add array property
        if (p.array) |array| switch (array) {
            .variable_length => {
                try writer.print(
                    "{s}: PropertyArray<{s}>;",
                    .{ field_name, o },
                );
                try constructor_writer.print(
                    "this.{s} = new PropertyArray(this.makeParams({}), (params) => {{ return new {s}(params); }} );",
                    .{ field_name, p.id, o },
                );
            },
            .length => |length| {
                try writer.print(
                    "{s}: PropertyArray<{s}>;",
                    .{ field_name, o },
                );
                try constructor_writer.print(
                    "this.{s} = new PropertyArray(this.makeParams({}), (params) => {{ return new {s}(params);}}, {} );",
                    .{ field_name, p.id, o, length },
                );
            },
        }
        // Otherwise just property
        else {
            try writer.print(
                "{s}: {s};",
                .{ field_name, o },
            );
            try constructor_writer.print(
                "this.{s} = new {s}(this.makeParams({}));",
                .{ field_name, o, p.id },
            );
        }
    }
}
