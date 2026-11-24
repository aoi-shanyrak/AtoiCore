const std = @import("std");

pub fn addRunStep(b: *std.Build, install: *std.Build.Step, img_path: std.Build.LazyPath) void {
    const run_step = b.step("run", "Build and run in QEMU (ReleaseSmall)");
    const qemu = b.addSystemCommand(&.{
        "qemu-system-i386",
        "-cpu",
        "pentium2",
        "-m",
        "1g",
        "-no-reboot",
        "-fda",
    });
    qemu.addFileArg(img_path);
    qemu.addArgs(&.{
        "-monitor", "stdio",
        "-device",  "VGA",
    });
    qemu.step.dependOn(install);
    run_step.dependOn(&qemu.step);
}

pub fn addCleanStep(b: *std.Build) void {
    const clean_step = b.step("clean", "Remove builded files");
    const rm = b.addSystemCommand(&.{
        "rm", "-rf", "zig-out/", ".zig-cache/",
    });
    clean_step.dependOn(&rm.step);
}
