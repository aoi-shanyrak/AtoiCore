const std = @import("std");
const x86 = @import("x86_32");
const panic = @import("panic");
const writer = @import("printer.zig");

const pic = x86.pic;

const Context = x86.Context;
const InterruptVector = x86.InterruptVector;

var timer_ticks: u32 = 0;

export fn universal_handler(ctx: *Context) callconv(.c) void {
    const vec: u8 = @truncate(ctx.vector);
    const vector: InterruptVector = @fromBackingInt(@intCast(vec));

    if (vector.isPicIrq()) {
        handleIRQ(vector);
        return;
    }

    if (panic.beginPanic()) |w| {
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
    }
    panic.halt();
}

fn handleIRQ(vector: InterruptVector) void {
    const w = writer.getWriter();

    switch (vector) {
        .timer => {
            timer_ticks += 1;
        },
        .keyboard => {
            const scancode = pic.inb(0x60);
            w.print("keyboard 0x{x:0>2}", .{scancode}) catch {};
        },
        else => {},
    }

    pic.sendEOI(@backingInt(vector));
}
