const std = @import("std");
const zon = std.zon.parse;
const Io = std.Io;
const Dir = Io.Dir;
const Schema = @import("Schema.zig");

const cpp = @import("cpp.zig");
const ts = @import("ts.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(gpa);
    const cwd = Dir.cwd();

    if (args.len != 3)
        return error.BadArgCount;

    // Read file
    const filename = args[1];
    const file = try cwd.readFileAllocOptions(io, filename, gpa, .unlimited, .of(u8), 0);

    // Parse zon
    var diag: zon.Diagnostics = .{};
    const schema = zon.fromSliceAlloc(Schema, gpa, file, &diag, .{}) catch |err| switch (err) {
        error.ParseZon => {
            const stderr = try io.lockStderr(&.{}, null);
            defer io.unlockStderr();

            const writer = &stderr.file_writer.interface;
            try writer.print("Failed to parse zon file:\n", .{});
            try diag.format(writer);
            std.process.exit(1);
        },
        else => return err,
    };

    const lang = args[2];

    if (std.mem.eql(u8, lang, "cpp")) {
        std.debug.print("{s}", .{try cpp.write(schema, gpa)});
    } else if (std.mem.eql(u8, lang, "ts")) {
        std.debug.print("{s}", .{try ts.write(schema, gpa)});
    } else return error.UnknownLang;
}
