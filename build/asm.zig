const std = @import("std");
const cfg = @import("config.zig");

pub fn addAssemblyObjects(b: *std.Build, exe: *std.Build.Step.Compile) void {
    inline for (cfg.asm_sources) |asm_src| {
        const obj = compileNasm(b, asm_src, asmObjName(asm_src));
        exe.root_module.addObjectFile(obj);
    }
}

fn compileNasm(
    b: *std.Build,
    comptime src_rel: []const u8,
    obj_name: []const u8,
) std.Build.LazyPath {
    const cmd = b.addSystemCommand(&.{ "nasm", "-f", "elf32" });
    cmd.addFileArg(b.path(src_rel));
    cmd.addArg("-o");
    return cmd.addOutputFileArg(obj_name);
}

fn asmObjName(comptime src: []const u8) []const u8 {
    return comptime blk: {
        const base = std.fs.path.basename(src);
        const dot = std.mem.indexOfScalar(u8, base, '.') orelse base.len;
        break :blk base[0..dot] ++ ".o";
    };
}
