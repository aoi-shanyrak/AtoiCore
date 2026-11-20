const std = @import("std");

// ====================================

const linker_script = "src/x86_32/boot/link.ld";

const asm_sources = [_][]const u8{
    "src/x86_32/boot/loader.asm",
    "src/x86_32/interrupts.asm",
};

const kernel_elf_name = "os.elf";
const final_bin_name = "os.bin";

// ====================================

const disabled_cpu_features = std.Target.x86.featureSet(&.{ .sse, .sse2 });

const KernelBuildCtx = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    fn module(
        self: KernelBuildCtx,
        root_source: []const u8,
        imports: []const std.Build.Module.Import,
    ) *std.Build.Module {
        return self.b.createModule(.{
            .root_source_file = self.b.path(root_source),
            .target = self.target,
            .optimize = self.optimize,
            .code_model = .kernel,
            .imports = imports,
        });
    }
};

fn objName(comptime src: []const u8) []const u8 {
    return comptime blk: {
        const base = std.fs.path.basename(src);
        const dot = std.mem.indexOfScalar(u8, base, '.') orelse base.len;
        break :blk base[0..dot] ++ ".o";
    };
}

fn nasmObject(
    b: *std.Build,
    comptime src_rel: []const u8,
    obj_name: []const u8,
) std.Build.LazyPath {
    const cmd = b.addSystemCommand(&.{ "nasm", "-f", "elf32" });
    cmd.addFileArg(b.path(src_rel));
    cmd.addArg("-o");
    return cmd.addOutputFileArg(obj_name);
}

pub fn build(b: *std.Build) void {
    const ctx = KernelBuildCtx{
        .b = b,
        .optimize = b.standardOptimizeOption(.{}),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .abi = .none,
            .cpu_features_sub = disabled_cpu_features,
        }),
    };

    const drivers_mod = ctx.module("src/drivers/drivers.zig", &.{});

    const panic_mod = ctx.module("src/kernel/panic.zig", &.{});

    const x86_32_mod = ctx.module("src/x86_32/x86_32.zig", &.{});

    const memory_mod = ctx.module("src/memory/memory.zig", &.{
        .{ .name = "x86_32", .module = x86_32_mod },
        .{ .name = "panic", .module = panic_mod },
    });

    const kernel_mod = ctx.module("src/kernel/main.zig", &.{
        .{ .name = "x86_32", .module = x86_32_mod },
        .{ .name = "drivers", .module = drivers_mod },
        .{ .name = "memory", .module = memory_mod },
        .{ .name = "panic", .module = panic_mod },
    });

    const os_elf = b.addExecutable(.{
        .name = kernel_elf_name,
        .root_module = kernel_mod,
    });
    os_elf.entry = .disabled;
    os_elf.setLinkerScript(b.path(linker_script));

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
