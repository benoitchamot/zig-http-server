const std = @import("std");

const EXE_NAME = "server";

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = EXE_NAME,
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    b.installArtifact(exe);

    // Add a run step
    // Execute as part of zig build run
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
