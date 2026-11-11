const std = @import("std");

// ====================================

const src_dir = "src";

const kernel_zig = "main.zig";
const linker_script = "link.ld";
const defs_zig = "defs.zig";
const defs_inc_name = "defs.inc";

const asm_sources = [_][]const u8{
    "loader.asm",
    "interrupts.asm",
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

fn generateDefsInc(b: *std.Build) []const u8 {
    const path = src_dir ++ "/" ++ defs_zig;
    const source = b.root.root_dir.handle.readFileAlloc(b.graph.io, path, b.allocator, .limited(8 * 1024)) catch {
        @panic("failed to read defs.zig");
    };

    var aw: std.Io.Writer.Allocating = .init(b.allocator);
    defer aw.deinit();
    const writer = &aw.writer;

    var it = std.mem.splitScalar(u8, source, '\n');
    while (it.next()) |raw_line| {
        var line = raw_line;
        if (std.mem.indexOf(u8, line, "//")) |idx| line = line[0..idx];
        line = std.mem.trim(u8, line, " \t\r");

        const pub_const = "pub const ";
        if (!std.mem.startsWith(u8, line, pub_const)) continue;
        const rest = line[pub_const.len..];

        const colon = std.mem.indexOfScalar(u8, rest, ':') orelse continue;
        const name = std.mem.trim(u8, rest[0..colon], " \t");

        const eq = std.mem.indexOfScalar(u8, rest[colon..], '=') orelse continue;
        const val_start = colon + eq + 1;
        const semi = std.mem.indexOfScalar(u8, rest[val_start..], ';') orelse continue;
        const value = std.mem.trim(u8, rest[val_start .. val_start + semi], " \t");

        writer.print("%define {s} {s}\n", .{ name, value }) catch @panic("OOM");
    }
    return aw.toOwnedSlice() catch @panic("OOM");
}

fn nasmObject(
    b: *std.Build,
    comptime src_rel: []const u8,
    obj_name: []const u8,
    include_dir: std.Build.LazyPath,
) std.Build.LazyPath {
    const cmd = b.addSystemCommand(&.{ "nasm", "-f", "elf32" });
    cmd.addArg("-I");
    cmd.addDirectoryArg(include_dir);
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

    const inc_files = b.addWriteFiles();
    _ = inc_files.add(defs_inc_name, generateDefsInc(b));
    const inc_dir = inc_files.getDirectory();

    inline for (asm_sources) |asm_src| {
        const obj = nasmObject(b, asm_src, objName(asm_src), inc_dir);
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
