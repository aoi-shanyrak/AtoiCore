const std = @import("std");

const src_dir = "src";
const boot_asm = src_dir ++ "/boot.asm";
const kernel_zig = src_dir ++ "/kernel.zig";
const linker_script = src_dir ++ "/link.ld";

const boot_obj_name = "boot.o";
const kernel_elf_name = "os.elf";
const final_bin_name = "os.bin";

const disabled_cpu_features = std.Target.x86.featureSet(&.{ .sse, .sse2 });

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_sub = disabled_cpu_features,
    });

    const nasm = b.addSystemCommand(&.{ "nasm", "-f", "elf32" });
    nasm.addFileArg(b.path(boot_asm));
    nasm.addArg("-o");
    const boot_obj = nasm.addOutputFileArg(boot_obj_name);

    const os_elf = b.addExecutable(.{
        .name = kernel_elf_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(kernel_zig),
            .target = target,
            .optimize = .ReleaseSmall,
            .code_model = .kernel,
        }),
    });
    os_elf.entry = .disabled;
    os_elf.setLinkerScript(b.path(linker_script));

    os_elf.root_module.addObjectFile(boot_obj);

    const os_bin = b.addObjCopy(
        os_elf.getEmittedBin(),
        .{ .format = .binary },
    );

    const install = b.addInstallFileWithDir(
        os_bin.getOutput(),
        .bin,
        final_bin_name,
    );
    b.getInstallStep().dependOn(&install.step);
}
