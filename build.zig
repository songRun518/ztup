const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = (b.release_mode == .fast or b.release_mode == .small),
    });

    const exe = b.addExecutable(.{
        .name = "ztup",
        .root_module = mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Run");
    run_step.dependOn(&run_exe.step);
}
