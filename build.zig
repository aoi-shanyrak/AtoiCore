const std = @import("std");
const config = @import("build/config.zig");
const kernel = @import("build/kernel.zig");
const @"asm" = @import("build/asm.zig");
const image = @import("build/image.zig");
const tasks = @import("build/tasks.zig");

pub fn build(b: *std.Build) void {
    const ctx = config.Context.init(b);

    const kernel_mod = kernel.createKernelModules(ctx);
    const os_elf = kernel.addKernelElf(b, kernel_mod);
    @"asm".addAssemblyObjects(b, os_elf);

    const check = b.step("check", "Check if kernel compiles");
    check.dependOn(&os_elf.step);

    const os_bin = b.addObjCopy(os_elf.getEmittedBin(), .{ .format = .binary });
    const os_img = image.addFloppyImage(b, os_bin.getOutput());

    const install = b.getInstallStep();

    b.installArtifact(os_elf);

    const install_bin = b.addInstallFileWithDir(os_bin.getOutput(), .bin, config.bin_name);
    install.dependOn(&install_bin.step);

    const install_img = b.addInstallFileWithDir(os_img, .prefix, config.img_name);
    install.dependOn(&install_img.step);

    tasks.addRunStep(b, install, os_img);
    tasks.addCleanStep(b);
}
