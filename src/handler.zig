const std = @import("std");
const defs = @import("defs.zig");
const panic_mod = @import("panic.zig");

const Context = extern struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    gs: u32,
    fs: u32,
    es: u32,
    ds: u32,

    vector: u32,
    error_code: u32,

    eip: u32,
    cs: u32,
    eflags: u32,
};

pub fn hasErrorCode(vec: u32) bool {
    return switch (vec) {
        8, 10, 11, 12, 13, 14, 17, 21 => true,
        else => false,
    };
}

export fn universal_handler(ctx: *Context) callconv(.c) void {
    const w = panic_mod.beginPanic();

    var name_buf: [8]u8 = undefined;
    const int_name: []const u8 = getInterruptName(ctx.vector) orelse std.fmt.bufPrint(&name_buf, "#{d}", .{ctx.vector}) catch "ERR";

    w.print(
        \\unhandled interrupt {s} at 0x{x:0>4}:0x{x:0>8}
        \\
    , .{
        int_name,
        ctx.cs,
        ctx.eip,
    }) catch {};

    w.print(
        \\Registers:
        \\    EAX: 0x{x:0>8} EBX: 0x{x:0>8} ECX: 0x{x:0>8} EDX: 0x{x:0>8}
        \\    ESI: 0x{x:0>8} EDI: 0x{x:0>8} EBP: 0x{x:0>8} ESP: 0x{x:0>8}
        \\    DS : 0x{x:0>8} ES : 0x{x:0>8} FS : 0x{x:0>8} GS : 0x{x:0>8}
        \\
    , .{
        ctx.eax, ctx.ebx, ctx.ecx, ctx.edx, //
        ctx.esi, ctx.edi, ctx.ebp, ctx.esp,
        ctx.ds,  ctx.es,  ctx.fs,  ctx.gs,
    }) catch {};

    w.print(
        \\EFLAGS: 0x{x:0>8}
        \\    CF:{d} PF :{d} AF :{d} ZF:{d} 
        \\    SF:{d} TF :{d} IF :{d} DF:{d} 
        \\    OF:{d} NT :{d} RF :{d} VM:{d}
        \\    AC:{d} VIF:{d} VIP:{d} ID:{d}
        \\
    , .{
        ctx.eflags, //
        getBit(ctx.eflags, 0),  getBit(ctx.eflags, 2),  getBit(ctx.eflags, 4),  getBit(ctx.eflags, 6), //
        getBit(ctx.eflags, 7),  getBit(ctx.eflags, 8),  getBit(ctx.eflags, 9),  getBit(ctx.eflags, 10),
        getBit(ctx.eflags, 11), getBit(ctx.eflags, 14), getBit(ctx.eflags, 16), getBit(ctx.eflags, 17),
        getBit(ctx.eflags, 18), getBit(ctx.eflags, 19), getBit(ctx.eflags, 20), getBit(ctx.eflags, 21),
    }) catch {};

    if (hasErrorCode(ctx.vector)) {
        w.print(
            \\Error Code: 0x{x:0>8}
            \\
        , .{ctx.error_code}) catch {};
    }

    panic_mod.halt();
}

fn getInterruptName(vec: u32) ?[]const u8 {
    return switch (vec) {
        0 => "#DE",
        1 => "#DB",
        3 => "#BP",
        4 => "#OF",
        5 => "#BR",
        6 => "#UD",
        7 => "#NM",
        8 => "#DF",
        10 => "#TS",
        11 => "#NP",
        12 => "#SS",
        13 => "#GP",
        14 => "#PF",
        16 => "#MF",
        17 => "#AC",
        18 => "#MC",
        19 => "#XM",
        20 => "#VE",
        21 => "#CP",
        else => null,
    };
}

fn getBit(val: u32, bit: u5) u1 {
    return @intFromBool(val & (@as(u32, 1) << bit) != 0);
}
