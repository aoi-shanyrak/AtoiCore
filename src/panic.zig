const std = @import("std");
const printer = @import("printer.zig");
const interrupts = @import("interrupts.zig");

pub extern fn endless_loop() noreturn;

var panicking: bool = false;

fn halt() noreturn {
    interrupts.disableInterrupts();
    endless_loop();
}

fn beginPanic() *std.Io.Writer {
    if (panicking) halt();
    panicking = true;
    interrupts.disableInterrupts();

    const w = printer.getWriter();
    w.writeAll("\n=== PANIC AT CORE! ===\n") catch {};
    return w;
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    const w = beginPanic();
    w.print(fmt, args) catch {};
    w.writeAll("\n=======================\n") catch {};
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
    w.writeAll("=======================\n") catch {};
    halt();
}
