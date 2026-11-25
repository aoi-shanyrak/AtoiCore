const std = @import("std");
const trampolines = @import("trampolines.zig");
const idt = @import("idt.zig");
const pic = @import("pic.zig");

pub fn setup(allocator: std.mem.Allocator, pic_cfg: pic.Config) !void {
    const tramps_buf = try allocator.alloc(u8, trampolines.TRAMPOLINES_SIZE);
    const tramps: *[trampolines.TRAMPOLINES_SIZE]u8 = @ptrCast(tramps_buf.ptr);
    try trampolines.genTrampolines(tramps);

    const idt_ptr = try allocator.create(idt.Idt);

    const base = @intFromPtr(tramps);
    for (0..idt.NUM_VECTORS) |i| {
        idt_ptr.setGate(@intCast(i), trampolines.vectorAddr(base, i));
    }
    idt_ptr.load();

    pic.init(pic_cfg);
}
