const std = @import("std");
const cfg = @import("config.zig");

pub fn addRunStep(b: *std.Build, install: *std.Build.Step, img_path: std.Build.LazyPath) void {
    const run_step = b.step("run", "Build and run in QEMU (ReleaseSmall)");
    const qemu = b.addSystemCommand(&.{cfg.qemu_bin});
    qemu.addArgs(&cfg.qemu_args);
    qemu.addPrefixedFileArg(cfg.qemu_drive_prefix, img_path);

    qemu.step.dependOn(install);
    run_step.dependOn(&qemu.step);
}

pub fn addCleanStep(b: *std.Build) void {
    const clean_step = b.step("clean", "Remove builded files");
    const rm = b.addSystemCommand(&.{
        "rm", "-rf",
    });
    rm.addArgs(&cfg.clean_dirs);
    clean_step.dependOn(&rm.step);
}

pub fn addAsmDumpStep(b: *std.Build, kernel_mod: *std.Build.Module) void {
    const dump_step = b.step("asm", "Emit ReleaseSmall assembly via Zig compiler");
    const asm_obj = b.addObject(.{
        .name = "kernel_asm",
        .root_module = kernel_mod,
    });
    const asm_file = asm_obj.getEmittedAsm();
    dump_step.dependOn(&b.addInstallFileWithDir(asm_file, .prefix, "kernel.dis.asm").step);
}
