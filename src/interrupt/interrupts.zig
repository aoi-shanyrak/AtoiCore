const std = @import("std");
const idt = @import("idt.zig");
const pic = @import("pic.zig");
const handler = @import("handler.zig");
const trampolines = @import("trampolines.zig");

comptime {
    _ = @import("handler.zig");
}

pub fn setup(allocator: std.mem.Allocator, pic_cfg: pic.Config) !void {
    handler.init(allocator);

    const tramps = try trampolines.Trampolines.init(allocator);
    const idt_ptr = try allocator.create(idt.Idt);

    for (0..idt.NUM_VECTORS) |i| {
        idt_ptr.setGate(@intCast(i), tramps.vectorAddr(i));
    }
    idt_ptr.load();

    pic.init(pic_cfg);
}
