const std = @import("std");
const printer = @import("printer.zig");
const panic_mod = @import("panic.zig");

pub const panic = std.debug.FullPanic(zigPanic);

fn zigPanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    const w = printer.getWriter();
    w.writeAll("ZIG PANIC: ") catch {};
    w.writeAll(msg) catch {};
    if (first_trace_addr) |addr| {
        w.print(" at 0x{x}", .{addr}) catch {};
    }
    w.writeAll("\n") catch {};
    panic_mod.halt();
}

extern fn endless_loop() noreturn;

export fn kernelEntry() callconv(.c) noreturn {
    printer.initPrinter();

    std.debug.assert(1 + 1 == 2);
    printer.printf("assert ok\n");

    std.debug.assert(1 == 2);
    printer.printf("unreachable in Debug\n");

    endless_loop();
}
