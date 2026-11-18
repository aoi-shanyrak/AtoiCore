const std = @import("std");
const defs = @import("defs.zig");
const trampolines = @import("trampolines.zig");
const idt = @import("idt.zig");

pub fn setup(allocator: std.mem.Allocator) !void {
    const tramps_buf = try allocator.alloc(u8, trampolines.TRAMPOLINES_SIZE);
    const tramps: *[trampolines.TRAMPOLINES_SIZE]u8 = @ptrCast(tramps_buf.ptr);
    try trampolines.genTrampolines(tramps);

    const idt_ptr = try allocator.create(idt.Idt);

    const base = @intFromPtr(tramps);
    for (0..defs.NUM_VECTORS) |i| {
        idt_ptr.setGate(@intCast(i), trampolines.vectorAddr(base, i));
    }
    idt_ptr.load();
}
