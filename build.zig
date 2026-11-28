const std = @import("std");
const config = @import("build/config.zig");
const kernel = @import("build/kernel.zig");
const image = @import("build/image.zig");
const tasks = @import("build/tasks.zig");

pub fn build(b: *std.Build) void {
    const ctx = config.Context.init(b);

    const os_elf = kernel.buildKernel(ctx);
    const os_bin = b.addObjCopy(os_elf.getEmittedBin(), .{ .format = .binary });
    const os_img = image.addFloppyImage(b, os_bin.getOutput());

    const install = b.getInstallStep();

    install.dependOn(&b.addInstallFileWithDir(os_bin.getOutput(), .bin, config.bin_name).step);
    install.dependOn(&b.addInstallFileWithDir(os_img, .prefix, config.img_name).step);

    b.step("check", "Check if kernel compiles").dependOn(&os_elf.step);

    tasks.addRunStep(b, install, os_img);
    tasks.addCleanStep(b);
    tasks.addAsmDumpStep(b, os_elf.root_module);
}
