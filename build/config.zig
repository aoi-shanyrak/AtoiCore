const std = @import("std");

pub const defs_inc_name = "defs.inc";
pub const linker_script = "src/kernel/boot/link.ld";
pub const mkimage_src = "build/mkimage.zig";

pub const kernel_elf_name = "os.elf";
pub const bin_name = "os.bin";
pub const img_name = "os.img";

pub const asm_sources = [_][]const u8{
    "src/kernel/boot/loader.asm",
    "src/interrupts/collectCtx.asm",
};

pub const sector_size: usize = 512;
pub const floppy_sectors: usize = 2880;
pub const image_size = sector_size * floppy_sectors;

pub const Context = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    pub fn init(b: *std.Build) Context {
        return .{
            .b = b,
            .optimize = b.standardOptimizeOption(.{}),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86,
                .os_tag = .freestanding,
                .abi = .none,
                .cpu_features_sub = std.Target.x86.featureSet(&.{ .sse, .sse2 }),
            }),
        };
    }
};

pub const qemu_bin = "qemu-system-i386";

pub const qemu_args = [_][]const u8{
    "-cpu",
    "pentium2",
    "-m",
    "1g",
    "-no-reboot",
    "-monitor",
    "stdio",
    "-device",
    "VGA",
    "-fda",
};

pub const clean_dirs = [_][]const u8{
    "zig-out/",
    ".zig-cache/",
    "build/boot.img",
};
