const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add CLI
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    const exe = b.addExecutable(.{
        .name = "wormhole",
        .root_module = mod,
    });
    b.installArtifact(exe);

    mod.addImport("case", b.dependency("case", .{}).module("case"));
    mod.addAnonymousImport("lib/cpp", .{ .root_source_file = b.path("lib/cpp/wormhole.hpp") });
    mod.addAnonymousImport("lib/ts", .{ .root_source_file = b.path("lib/ts/wormhole.ts") });

    const run_step = b.step("run", "Runs");
    const run = b.addRunArtifact(exe);
    if (b.args) |args| {
        run.addArgs(args);
    }
    run_step.dependOn(&run.step);

    // Setup tests
    const test_step = b.step("test", "Run all tests");

    // Cpp tests
    const cpp_test_mod = b.createModule(.{
        .target = target,
        .optimize = .Debug,
        .link_libc = true,
        .link_libcpp = true,
    });
    cpp_test_mod.addCSourceFile(.{
        .file = b.path("test/cpp/main.cpp"),
        .flags = &.{"-std=c++20"},
    });

    const cpp_gen_run = b.addRunArtifact(exe);
    cpp_gen_run.addArg("-e");
    cpp_gen_run.addArgs(&.{ "-l", "cpp" });
    cpp_gen_run.addArg("-i");
    cpp_gen_run.addFileArg(b.path("test/example.zon"));
    cpp_gen_run.addArg("-o");
    const cpp_gen = cpp_gen_run.addOutputFileArg("example.zon.hpp");
    cpp_test_mod.addIncludePath(cpp_gen.dirname());

    const cpp_test_exe = b.addExecutable(.{
        .name = "cpp_test",
        .root_module = cpp_test_mod,
    });
    const cpp_test_run = b.addRunArtifact(cpp_test_exe);
    const cpp_test_step = b.step("test-cpp", "Run cpp tests");
    cpp_test_step.dependOn(&cpp_test_run.step);
    test_step.dependOn(&cpp_test_run.step);

    // Ts tests
    const ts_gen_run = b.addRunArtifact(exe);
    ts_gen_run.addArg("-e");
    ts_gen_run.addArgs(&.{ "-l", "ts" });
    ts_gen_run.addArg("-i");
    ts_gen_run.addFileArg(b.path("test/example.zon"));
    ts_gen_run.addArg("-o");
    ts_gen_run.addArg("test/ts/example.zon.ts");

    const ts_test_run = b.addSystemCommand(&.{ "npx", "ts-node", "test/ts/main.ts" });
    const ts_test_step = b.step("test-ts", "Run ts tests");
    ts_test_run.step.dependOn(&ts_gen_run.step);
    ts_test_step.dependOn(&ts_test_run.step);
    test_step.dependOn(&ts_test_run.step);
}
