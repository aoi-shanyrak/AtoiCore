const std = @import("std");
const drivers = @import("drivers");
const printer = @import("printer");
const interrupts = @import("interrupts");

pub const Experiment = enum {
    exp1_hang,
    exp2_timer_panic,
    exp3_keyboard_panic,
    exp4_timer_aeoi_print,
    exp5_timer_zeroing_print,
};

pub fn run(allocator: std.mem.Allocator, comptime exp: Experiment) noreturn {
    switch (exp) {
        .exp1_hang => {
            interrupts.setup(allocator, .{ .aeoi = false, .force_trap = false }) catch unreachable;
            StiAndHalt();
        },

        .exp2_timer_panic => {
            interrupts.setup(allocator, .{ .aeoi = false, .force_trap = false }) catch unreachable;

            drivers.pit.init(100) catch unreachable;
            interrupts.handler.register(.timer, null);

            StiAndHalt();
        },

        .exp3_keyboard_panic => {
            interrupts.setup(allocator, .{ .aeoi = false, .force_trap = false }) catch unreachable;

            drivers.ps2.init() catch unreachable;
            drivers.keyboard.init(allocator) catch unreachable;

            StiAndHalt();
        },

        .exp4_timer_aeoi_print => {
            interrupts.setup(allocator, .{ .aeoi = true, .force_trap = false }) catch unreachable;

            drivers.pit.init(1000) catch unreachable;
            interrupts.handler.register(.timer, timerPrintHandler);

            StiAndHalt();
        },

        .exp5_timer_zeroing_print => {
            interrupts.setup(allocator, .{ .aeoi = true, .force_trap = false }) catch unreachable;

            drivers.pit.init(1000) catch unreachable;
            interrupts.handler.register(.timer, timerZeroHandler);

            asm volatile ("sti");

            const w = printer.getWriter();
            while (true) : (global_ticks +%= 1) {
                w.print("{d} ", .{global_ticks}) catch {};
            }
        },
    }
}

fn StiAndHalt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("");
    }
}

var global_ticks: u32 = 0;

fn timerPrintHandler(_: *interrupts.Context) void {
    global_ticks +%= 1;
    if (printer.getWriter()) |w| {
        w.print("{d} ", .{global_ticks}) catch {};
    }
}

fn timerZeroHandler(_: *interrupts.Context) void {
    global_ticks = 0;
}
