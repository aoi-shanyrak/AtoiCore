const std = @import("std");
const defs = @import("defs.zig");
const tramp = @import("trampolines.zig");
const idt_mod = @import("idt.zig");
const printer = @import("printer.zig");

pub fn setup(allocator: std.mem.Allocator) !void {
    const tramps_buf = try allocator.alloc(u8, tramp.TRAMPOLINES_SIZE);
    const tramps: *[tramp.TRAMPOLINES_SIZE]u8 = @ptrCast(tramps_buf.ptr);
    try tramp.genTrampolines(tramps);

    const idt_ptr = try allocator.create(idt_mod.Idt);

    const base = @intFromPtr(tramps);
    for (0..defs.NUM_VECTORS) |i| {
        idt_ptr.setGate(@intCast(i), tramp.vectorAddr(base, i));
    }
    idt_ptr.load();
}
