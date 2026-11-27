const std = @import("std");
const kpanic = @import("panic");
const drivers = @import("drivers");
const printer = @import("printer");
const interrupts = @import("interrupts");
const experiments = @import("experiments");

const allocator_undead = @import("arena.zig");

pub const panic = std.debug.FullPanic(kpanic.zigPanic);

var kernel_arena: allocator_undead.Arena = undefined;

export fn kernelEntry() callconv(.c) noreturn {
    const allocator = kernelSetup();

    experiments.run(allocator, .exp3_keyboard_panic);
}

fn kernelSetup() std.mem.Allocator {
    kernel_arena.init();
    const allocator = kernel_arena.allocator();

    printer.initPrinter();
    kpanic.setWriter(printer.getWriter());

    return allocator;
}
