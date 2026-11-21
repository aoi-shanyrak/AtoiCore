const std = @import("std");
const defs = @import("src/x86_32/defs.zig");

const Config = struct {
    const defs_inc_name = "defs.inc";
    const linker_script = "src/x86_32/boot/link.ld";
    const kernel_elf_name = "os.elf";
    const bin_name = "os.bin";
    const img_name = "os.img";

    const asm_sources = [_][]const u8{
        "src/x86_32/boot/loader.asm",
        "src/x86_32/interrupts.asm",
    };

    const mkimage = "build/mkimage.zig";

    const sector_size: usize = 512;
    const floppy_sectors: usize = 2880;

    const disabled_cpu_features = std.Target.x86.featureSet(&.{ .sse, .sse2 });
};

pub fn build(b: *std.Build) void {
    const ctx = KernelBuildCtx.init(b);

    const kernel_mod = createKernelModules(ctx);
    const os_elf = createKernelElf(b, kernel_mod);
    addAssemblyObjects(b, os_elf);

    const os_bin = b.addObjCopy(os_elf.getEmittedBin(), .{ .format = .binary });
    const os_img = createFloppyImage(b, os_bin.getOutput());

    const install = b.getInstallStep();

    const install_bin = b.addInstallFileWithDir(os_bin.getOutput(), .bin, Config.bin_name);
    install.dependOn(&install_bin.step);

    const install_img = b.addInstallFileWithDir(os_img, .prefix, Config.img_name);
    install.dependOn(&install_img.step);

    addRunStep(b, install, os_img);
    addCleanStep(b);
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

fn createKernelElf(b: *std.Build, kernel_mod: *std.Build.Module) *std.Build.Step.Compile {
    const os_elf = b.addExecutable(.{
        .name = Config.kernel_elf_name,
        .root_module = kernel_mod,
    });
    os_elf.entry = .disabled;
    os_elf.setLinkerScript(b.path(Config.linker_script));
    return os_elf;
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

fn createFloppyImage(b: *std.Build, payload: std.Build.LazyPath) std.Build.LazyPath {
    const mkimage_exe = b.addExecutable(.{
        .name = "mkimage",
        .root_module = b.createModule(.{
            .root_source_file = b.path(Config.mkimage),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });
    const run = b.addRunArtifact(mkimage_exe);
    run.addFileArg(payload);
    const out_img = run.addOutputFileArg(Config.img_name);
    run.addArg(b.fmt("{d}", .{Config.floppy_sectors * Config.sector_size}));

    return out_img;
}

fn addRunStep(b: *std.Build, install: *std.Build.Step, img_path: std.Build.LazyPath) void {
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

fn addCleanStep(b: *std.Build) void {
    const clean_step = b.step("clean", "Remove builded files");
    const rm = b.addSystemCommand(&.{
        "rm", "-rf", "zig-out/", ".zig-cache/",
    });
    clean_step.dependOn(&rm.step);
}
