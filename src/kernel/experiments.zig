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
    exp6_timer_inc_print_art,
    exp7_timer_non_aeoi,
    exp8_timer_manual_eoi,
    exp9_nested_irq_overflow,
};

pub fn run(allocator: std.mem.Allocator, comptime exp: Experiment) noreturn {
    switch (exp) {
        .exp1_hang => {
            interrupts.setup(allocator, .{ .aeoi = false }) catch unreachable;
            StiAndHalt();
        },

        .exp2_timer_panic => {
            interrupts.setup(allocator, .{ .aeoi = false }) catch unreachable;

            drivers.pit.init(100) catch unreachable;
            interrupts.handler.register(.timer, null);

            StiAndHalt();
        },

        .exp3_keyboard_panic => {
            interrupts.setup(allocator, .{ .aeoi = false }) catch unreachable;

            drivers.ps2.init() catch unreachable;
            drivers.keyboard.init(allocator) catch unreachable;
            interrupts.handler.register(.keyboard, null);

            StiAndHalt();
        },

        .exp4_timer_aeoi_print => {
            interrupts.setup(allocator, .{ .aeoi = true }) catch unreachable;

            drivers.pit.init(100) catch unreachable;
            interrupts.handler.register(.timer, timerPrintHandler);

            StiAndHalt();
        },

        .exp5_timer_zeroing_print => {
            interrupts.setup(allocator, .{ .aeoi = true }) catch unreachable;

            drivers.pit.init(100000) catch unreachable;
            interrupts.handler.register(.timer, timerZeroHandler);

            asm volatile ("sti");

            timerIncPrintEndless();
        },

        .exp6_timer_inc_print_art => {
            interrupts.setup(allocator, .{ .aeoi = true }) catch unreachable;

            drivers.pit.init(1000) catch unreachable;
            interrupts.handler.register(.timer, timerPrintHandler);

            asm volatile ("sti");

            timerIncPrintEndless();
        },

        .exp7_timer_non_aeoi => {
            interrupts.setup(allocator, .{ .aeoi = false, .should_send_eoi = false }) catch unreachable;

            drivers.pit.init(100) catch unreachable;
            interrupts.handler.register(.timer, timerPrintHandler);

            StiAndHalt();
        },

        .exp8_timer_manual_eoi => {
            interrupts.setup(allocator, .{ .aeoi = false, .should_send_eoi = false }) catch unreachable;

            drivers.pit.init(100) catch unreachable;
            interrupts.handler.register(.timer, timerPrintEoiHandler);

            StiAndHalt();
        },

        .exp9_nested_irq_overflow => {
            interrupts.setup(allocator, .{ .aeoi = false, .should_send_eoi = false }) catch unreachable;

            drivers.pit.init(100) catch unreachable;
            interrupts.handler.register(.timer, timerNestedOverflowHandler);

            StiAndHalt();
        },
    }
}

fn StiAndHalt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("");
    }
}

fn timerIncPrintEndless() noreturn {
    var val: u32 = 0;
    const w = printer.getWriter();
    while (true) : (val = global_ticks.fetchAdd(1, .monotonic)) {
        w.print("{d} ", .{val}) catch {};
    }
}

var global_ticks = std.atomic.Value(u32).init(0);

fn timerPrintHandler(_: *interrupts.Context) void {
    const val = global_ticks.fetchAdd(1, .monotonic) +% 1;
    printer.getWriter().print("{d} ", .{val}) catch {};
}

fn timerZeroHandler(_: *interrupts.Context) void {
    global_ticks.store(0, .monotonic);
}

fn timerPrintEoiHandler(ctx: *interrupts.Context) void {
    timerPrintHandler(ctx);
    if (interrupts.InterruptVector.timer.toPicIrq()) |irq| {
        interrupts.pic.sendEOI(@backingInt(irq));
    }
}

fn timerNestedOverflowHandler(ctx: *interrupts.Context) void {
    timerPrintEoiHandler(ctx);
    StiAndHalt();
}
