const std = @import("std");
const printer = @import("printer.zig");
const interrupts = @import("interrupts.zig");

pub extern fn endless_loop() noreturn;

fn halt() noreturn {
    interrupts.disableInterrupts();
    endless_loop();
}

pub const Reason = union(enum) {
    message: []const u8,
    format: struct { fmt: [*:0]const u8, args: *std.builtin.VaList },
    zig_runtime: struct { msg: []const u8, ret_addr: ?usize },
};

var panicking: bool = false;

fn report(reason: Reason) noreturn {
    if (panicking) halt();
    panicking = true;

    interrupts.disableInterrupts();

    const w = printer.getWriter();
    w.writeAll("\n=== PANIC AT CORE! ===\n") catch {};
    switch (reason) {
        .message => |m| {
            w.writeAll(m) catch {};
            w.writeAll("\n") catch {};
        },
        .format => |f| printer.vprintf(f.fmt, f.args),
        .zig_runtime => |z| {
            w.writeAll("zig runtime: ") catch {};
            w.writeAll(z.msg) catch {};
            w.writeAll("\n") catch {};
            if (z.ret_addr) |a| {
                w.print("  at 0x{x}\n", .{a}) catch {};
            }
        },
    }
    halt();
}

pub fn panicFmt(fmt: [*:0]const u8, args: *std.builtin.VaList) noreturn {
    report(.{ .format = .{ .fmt = fmt, .args = args } });
}

pub fn panic(fmt: [*:0]const u8, ...) callconv(.c) noreturn {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);
    panicFmt(fmt, &ap);
}

pub fn zigPanic(msg: []const u8, ret_addr: ?usize) noreturn {
    report(.{ .zig_runtime = .{ .msg = msg, .ret_addr = ret_addr } });
}
