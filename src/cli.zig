const std = @import("std");
const log = std.log;

pub const Language = enum {
    cpp,
    ts,
};

pub const Args = struct {
    input: []const u8,
    output: []const u8,
    embed_library: bool,
    language: Language,
};

fn equalAny(string: []const u8, options: []const []const u8) bool {
    for (options) |option| {
        if (std.mem.eql(u8, string, option))
            return true;
    }
    return false;
}

pub fn printHelp(io: std.Io) !void {
    try std.Io.File.stderr().writeStreamingAll(io,
        \\
        \\Options:
        \\    -i, --input <FILE>      Input .zon file
        \\    -o, --output <FILE>     Output generated source file
        \\    -l, --language <LANG>   Language to generated (cpp, ts)
        \\    -e, --embed-lib         Whether to embed library file within output file
        \\    -h, --help              Prints help
        \\
        \\
    );
}

const ParseError = error{ Help, BadArgs, MissingArgs };

pub fn parseArgs(ar: []const []const u8) ParseError!Args {
    if (ar.len == 0) return error.Help;

    var it: ArgIterator = .init(ar);
    _ = it.next(); // Skip executable

    var input: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    var embed_library = false;
    var language: ?Language = null;

    while (it.next()) |arg| {
        // Help
        if (equalAny(arg, &.{ "-h", "--help" })) {
            return error.Help;
        }
        // Input
        else if (equalAny(arg, &.{ "-i", "--input" })) {
            if (input != null) {
                log.err("Multiple input arguments, only one can be used", .{});
                return error.BadArgs;
            }

            input = it.next();

            if ((input == null) or
                (input.?.len == 0) or
                (input.?[0] == '-'))
            {
                log.err("Missing input file after input flag", .{});
                return error.BadArgs;
            }
        }
        // Output
        else if (equalAny(arg, &.{ "-o", "--output" })) {
            if (output != null) {
                log.err("Multiple output arguments, only one can be used", .{});
                return error.BadArgs;
            }

            output = it.next();

            if ((output == null) or
                (output.?.len == 0) or
                (output.?[0] == '-'))
            {
                log.err("Missing output file after output flag", .{});
                return error.BadArgs;
            }
        }
        // Language
        else if (equalAny(arg, &.{ "-l", "--language" })) {
            if (language != null) {
                log.err("Multiple language arguments, only one can be used", .{});
                return error.BadArgs;
            }

            const language_string = it.next();

            if (language_string == null) {
                log.err("Missing language value after language flag", .{});
                return error.BadArgs;
            }

            language = std.meta.stringToEnum(Language, language_string.?) orelse {
                log.err("Invalid language value '{?s}'", .{language_string});
                return error.BadArgs;
            };
        }
        // Embed library
        else if (equalAny(arg, &.{ "-e", "--embed-lib" })) {
            if (embed_library) {
                log.err("Multiple embed library arguments, only one can be used", .{});
                return error.BadArgs;
            }

            embed_library = true;
        }
        // Unknown arg
        else {
            log.err("Unknown argument '{s}'", .{arg});
            return error.BadArgs;
        }
    }

    if (input == null) {
        log.err("Missing input argument", .{});
        return error.MissingArgs;
    }
    if (output == null) {
        log.err("Missing output argument", .{});
        return error.MissingArgs;
    }
    if (language == null) {
        log.err("Missing language argument", .{});
        return error.MissingArgs;
    }

    return .{
        .input = input.?,
        .output = output.?,
        .embed_library = embed_library,
        .language = language.?,
    };
}

const ArgIterator = SliceIter([]const u8);

fn SliceIter(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []const T,
        index: usize,

        fn init(data: []const T) Self {
            return Self{ .data = data, .index = 0 };
        }

        fn next(self: *Self) ?T {
            if (self.index >= self.data.len) return null;

            const value = self.data[self.index];
            self.index += 1;
            return value;
        }
    };
}
