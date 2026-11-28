const std = @import("std");
const kpanic = @import("panic");
const drivers = @import("drivers");
const printer = @import("printer.zig");
const interrupts = @import("interrupts");

const allocator_undead = @import("arena.zig");

pub const panic = std.debug.FullPanic(kpanic.zigPanic);

var kernel_arena: allocator_undead.Arena = undefined;

export fn kernelEntry() callconv(.c) noreturn {
    _ = kernelSetup();
    main();
}

fn kernelSetup() void {
    kernel_arena.init();
    const allocator = kernel_arena.allocator();

    printer.initPrinter();
    kpanic.setWriter(printer.getWriter());

    interrupts.setup(allocator) catch unreachable;

    drivers.pit.init(100) catch unreachable;
    drivers.ps2.init() catch unreachable;
    drivers.keyboard.init(allocator) catch unreachable;

    asm volatile ("sti");
}

fn main() noreturn {
    const writer = printer.getWriter();

    while (true) {
        while (drivers.keyboard.pollEvent()) |ev| {
            if (!ev.pressed) continue;

            if (ev.char) |ch| {
                writer.writeByte(ch) catch {};
            } else {
                writer.print("[{s}]", .{@tagName(ev.key)}) catch {};
            }
        }
    }
    asm volatile ("hlt");
}
