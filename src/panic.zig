const std = @import("std");
const printer = @import("printer.zig");

pub extern fn endless_loop() noreturn;

var panicking: bool = false;

pub fn halt() noreturn {
    asm volatile ("cli");
    endless_loop();
}

pub fn beginPanic() *std.Io.Writer {
    if (panicking) halt();
    panicking = true;
    asm volatile ("cli");

    const w = printer.getWriter();
    w.writeAll("\nKernel panic: ") catch {};
    return w;
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    const w = beginPanic();
    w.print(fmt, args) catch {};
    halt();
}

pub fn zigPanic(msg: []const u8, ret_addr: ?usize) noreturn {
    const w = beginPanic();
    w.writeAll("zig runtime: ") catch {};
    w.writeAll(msg) catch {};
    w.writeAll("\n") catch {};
    if (ret_addr) |a| {
        w.print("  at 0x{x}\n", .{a}) catch {};
    }
    halt();
}
