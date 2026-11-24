const std = @import("std");
const cfg = @import("config.zig");
const defs = @import("../src/x86_32/defs.zig");

pub fn addAssemblyObjects(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const inc_files = b.addWriteFiles();
    _ = inc_files.add(cfg.defs_inc_name, generateDefsInc(b));
    const inc_dir = inc_files.getDirectory();

    inline for (cfg.asm_sources) |asm_src| {
        const obj = compileNasm(b, asm_src, asmObjName(asm_src), inc_dir);
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

fn asmObjName(comptime src: []const u8) []const u8 {
    return comptime blk: {
        const base = std.fs.path.basename(src);
        const dot = std.mem.indexOfScalar(u8, base, '.') orelse base.len;
        break :blk base[0..dot] ++ ".o";
    };
}
