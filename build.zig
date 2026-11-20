const std = @import("std");
const defs = @import("src/x86_32/defs.zig");

const Config = struct {
    const defs_inc_name = "defs.inc";
    const linker_script = "src/x86_32/boot/link.ld";
    const kernel_elf_name = "os.elf";
    const final_bin_name = "os.bin";

    const asm_sources = [_][]const u8{
        "src/x86_32/boot/loader.asm",
        "src/x86_32/interrupts.asm",
    };

    const disabled_cpu_features = std.Target.x86.featureSet(&.{ .sse, .sse2 });
};

pub fn build(b: *std.Build) void {
    const ctx = KernelBuildCtx.init(b);

    const kernel_mod = createKernelModules(ctx);

    const os_elf = b.addExecutable(.{
        .name = Config.kernel_elf_name,
        .root_module = kernel_mod,
    });
    os_elf.entry = .disabled;
    os_elf.setLinkerScript(b.path(Config.linker_script));

    addAssemblyObjects(b, os_elf);

    const os_bin = b.addObjCopy(os_elf.getEmittedBin(), .{ .format = .binary });
    const install = b.addInstallFileWithDir(os_bin.getOutput(), .bin, Config.final_bin_name);
    b.getInstallStep().dependOn(&install.step);
}

const KernelBuildCtx = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    fn init(b: *std.Build) KernelBuildCtx {
        return .{
            .b = b,
            .optimize = b.standardOptimizeOption(.{}),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86,
                .os_tag = .freestanding,
                .abi = .none,
                .cpu_features_sub = Config.disabled_cpu_features,
            }),
        };
    }

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

fn createKernelModules(ctx: KernelBuildCtx) *std.Build.Module {
    const drivers_mod = ctx.module("src/drivers/drivers.zig", &.{});
    const panic_mod = ctx.module("src/kernel/panic.zig", &.{});
    const x86_32_mod = ctx.module("src/x86_32/x86_32.zig", &.{});

    const memory_mod = ctx.module("src/memory/memory.zig", &.{
        .{ .name = "x86_32", .module = x86_32_mod },
        .{ .name = "panic", .module = panic_mod },
    });

    return ctx.module("src/kernel/main.zig", &.{
        .{ .name = "x86_32", .module = x86_32_mod },
        .{ .name = "drivers", .module = drivers_mod },
        .{ .name = "memory", .module = memory_mod },
        .{ .name = "panic", .module = panic_mod },
    });
}

fn addAssemblyObjects(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const inc_files = b.addWriteFiles();
    _ = inc_files.add(Config.defs_inc_name, generateDefsInc(b));
    const inc_dir = inc_files.getDirectory();

    inline for (Config.asm_sources) |asm_src| {
        const obj = compileNasm(b, asm_src, objName(asm_src), inc_dir);
        exe.root_module.addObjectFile(obj);
    }
}

fn compileNasm(
    b: *std.Build,
    comptime src_rel: []const u8,
    obj_name: []const u8,
    include_dir: std.Build.LazyPath,
) std.Build.LazyPath {
    const cmd = b.addSystemCommand(&.{ "nasm", "-f", "elf32" });
    cmd.addArg("-I");
    cmd.addDirectoryArg(include_dir);
    cmd.addFileArg(b.path(src_rel));
    cmd.addArg("-o");
    return cmd.addOutputFileArg(obj_name);
}

fn generateDefsInc(b: *std.Build) []const u8 {
    var aw: std.Io.Writer.Allocating = .init(b.allocator);
    defer aw.deinit();

    inline for (comptime std.meta.declarations(defs)) |declname| {
        const value = @field(defs, declname);
        switch (@typeInfo(@TypeOf(value))) {
            .int, .comptime_int => {
                aw.writer.print("%define {s} 0x{X}\n", .{ declname, value }) catch @panic("OOM");
            },
            else => {},
        }
    }
    return aw.toOwnedSlice() catch @panic("OOM");
}

fn objName(comptime src: []const u8) []const u8 {
    return comptime blk: {
        const base = std.fs.path.basename(src);
        const dot = std.mem.indexOfScalar(u8, base, '.') orelse base.len;
        break :blk base[0..dot] ++ ".o";
    };
}
