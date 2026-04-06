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
        .name = "statey2",
        .root_module = mod,
    });
    b.installArtifact(exe);

    mod.addImport("case", b.dependency("case", .{}).module("case"));

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
    cpp_test_mod.addIncludePath(b.path("lib/cpp"));
    const cpp_test_exe = b.addExecutable(.{
        .name = "cpp_test",
        .root_module = cpp_test_mod,
    });
    const cpp_test_run = b.addRunArtifact(cpp_test_exe);
    const cpp_test_step = b.step("test-cpp", "Run cpp tests");
    cpp_test_step.dependOn(&cpp_test_run.step);
    test_step.dependOn(&cpp_test_run.step);

    // Ts tests
    const ts_test_run = b.addSystemCommand(&.{ "npx", "ts-node", "test/ts/main.ts" });
    const ts_test_step = b.step("test-ts", "Run ts tests");
    ts_test_step.dependOn(&ts_test_run.step);
    test_step.dependOn(&ts_test_run.step);
}
