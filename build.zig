const std = @import("std");

// ====================================

const src_dir = "src";

const kernel_zig = "main.zig";
const linker_script = "link.ld";
const asm_sources = [_][]const u8{
    "loader.asm",
    "mem.asm",
};

const kernel_elf_name = "os.elf";
const final_bin_name = "os.bin";

// ====================================

const disabled_cpu_features = std.Target.x86.featureSet(&.{ .sse, .sse2 });

fn srcPath(b: *std.Build, comptime rel: []const u8) std.Build.LazyPath {
    return b.path(src_dir ++ "/" ++ rel);
}

fn objName(comptime src: []const u8) []const u8 {
    return comptime blk: {
        const dot = std.mem.indexOfScalar(u8, src, '.') orelse src.len;
        break :blk src[0..dot] ++ ".o";
    };
}

fn nasmObject(
    b: *std.Build,
    comptime src_rel: []const u8,
    obj_name: []const u8,
) std.Build.LazyPath {
    const cmd = b.addSystemCommand(&.{ "nasm", "-f", "elf32" });
    cmd.addFileArg(srcPath(b, src_rel));
    cmd.addArg("-o");
    return cmd.addOutputFileArg(obj_name);
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_sub = disabled_cpu_features,
    });

    const os_elf = b.addExecutable(.{
        .name = kernel_elf_name,
        .root_module = b.createModule(.{
            .root_source_file = srcPath(b, kernel_zig),
            .target = target,
            .optimize = optimize,
            .code_model = .kernel,
        }),
    });
    os_elf.entry = .disabled;
    os_elf.setLinkerScript(srcPath(b, linker_script));

    inline for (asm_sources) |asm_src| {
        const obj = nasmObject(b, asm_src, objName(asm_src));
        os_elf.root_module.addObjectFile(obj);
    }

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
