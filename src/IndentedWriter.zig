const std = @import("std");
const IndentedWriter = @This();

writer: *std.Io.Writer,
indent_level: i32 = 0,

pub fn init(writer: *std.Io.Writer) IndentedWriter {
    return .{ .writer = writer };
}

pub fn print(self: *IndentedWriter, comptime format: []const u8, args: anytype) !void {
    for (0..@intCast(self.indent_level)) |_| {
        try self.writer.print("    ", .{});
    }
    try self.writer.print(format ++ "\n", args);
}

pub fn write(self: *IndentedWriter, text: []const u8) !void {
    try self.writer.writeAll(text);
}

pub fn indent(self: *IndentedWriter) void {
    self.indent_level += 1;
}

pub fn deindent(self: *IndentedWriter) void {
    self.indent_level -= 1;
}
