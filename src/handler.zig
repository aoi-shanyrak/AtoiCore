const std = @import("std");
const defs = @import("defs.zig");
const panic = @import("panic.zig");
const interruptVector = @import("interruptVector.zig");

const Eflags = packed struct(u32) {
    cf: u1,
    _res0: u1,
    pf: u1,
    _res1: u1,
    af: u1,
    _res2: u1,
    zf: u1,
    sf: u1,
    tf: u1,
    if_: u1,
    df: u1,
    of: u1,
    iopl: u2,
    nt: u1,
    _res3: u1,
    rf: u1,
    vm: u1,
    ac: u1,
    vif: u1,
    vip: u1,
    id: u1,
    _res4: u10,

    pub fn format(
        self: Eflags,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("EFLAGS: 0x{x:0>8}", .{@as(u32, @bitCast(self))});
        try writer.print(
            \\    CF:{d} PF :{d} AF :{d} ZF:{d} SF:{d} TF :{d} IF :{d} DF:{d} 
            \\    OF:{d} NT :{d} RF :{d} VM:{d} AC:{d} VIF:{d} VIP:{d} ID:{d}
            \\
        , .{
            self.cf, self.pf, self.af, self.zf, self.sf, self.tf,  self.if_, self.df,
            self.of, self.nt, self.rf, self.vm, self.ac, self.vif, self.vip, self.id,
        });
    }
};

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

    pub fn format(
        self: Context,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        const flags: Eflags = @bitCast(self.eflags);

        try writer.print(
            \\Registers:
            \\    EAX: 0x{x:0>8} EBX: 0x{x:0>8} ECX: 0x{x:0>8} EDX: 0x{x:0>8}
            \\    ESI: 0x{x:0>8} EDI: 0x{x:0>8} EBP: 0x{x:0>8} ESP: 0x{x:0>8}
            \\    DS : 0x{x:0>8} ES : 0x{x:0>8} FS : 0x{x:0>8} GS : 0x{x:0>8}
            \\
        , .{
            self.eax, self.ebx, self.ecx, self.edx,
            self.esi, self.edi, self.ebp, self.esp,
            self.ds,  self.es,  self.fs,  self.gs,
        });

        try writer.print("{f}", .{flags});

        const vector: interruptVector.InterruptVector = @fromBackingInt(@intCast(@as(u8, @truncate(self.vector))));
        if (vector.hasErrorCode()) {
            try writer.print(
                \\Error Code: 0x{x:0>8}
                \\
            , .{self.error_code});
        }
    }
};

export fn universal_handler(ctx: *Context) callconv(.c) void {
    const w = panic.beginPanic();

    const vec: u8 = @truncate(ctx.vector);
    const vector: interruptVector.InterruptVector = @fromBackingInt(@intCast(vec));

    const int_name = vector.mnemonic() orelse "ERR";

    w.print(
        \\unhandled interrupt {s} at 0x{x:0>4}:0x{x:0>8}
        \\
        \\{f}
    , .{
        int_name,
        ctx.cs,
        ctx.eip,
        ctx.*,
    }) catch {};

    panic.halt();
}
