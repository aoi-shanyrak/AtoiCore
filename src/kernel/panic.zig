const std = @import("std");

var panicking: bool = false;
var panic_writer: ?*std.Io.Writer = null;

pub fn setWriter(w: *std.Io.Writer) void {
    panic_writer = w;
}

fn endless_loop() noreturn {
    while (true) {
        asm volatile ("");
    }
}

pub fn halt() noreturn {
    asm volatile ("cli");
    endless_loop();
}

pub fn beginPanic() ?*std.Io.Writer {
    if (panicking) halt();
    panicking = true;
    asm volatile ("cli");

    if (panic_writer) |w|
        w.writeAll("\nKernel panic: ") catch {};
    return panic_writer;
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    if (beginPanic()) |w|
        w.print(fmt, args) catch {};
    halt();
}

pub fn zigPanic(msg: []const u8, ret_addr: ?usize) noreturn {
    if (beginPanic()) |w| {
        w.writeAll("zig runtime: ") catch {};
        w.writeAll(msg) catch {};
        w.writeAll("\n") catch {};
        if (ret_addr) |a| {
            w.print("  at 0x{x}\n", .{a}) catch {};
        }
    }
    halt();
}
