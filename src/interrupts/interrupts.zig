pub const pic = @import("pic.zig");
pub const handler = @import("handler.zig");

pub const Context = @import("context.zig").Context;
pub const InterruptVector = @import("interruptVector.zig").InterruptVector;

const std = @import("std");
const idt = @import("idt.zig");
const trampolines = @import("trampolines.zig");

const SetupConfig = struct {
    aeoi: bool = false,
    force_trap: bool = false,
    should_send_eoi: bool = true,
};

pub fn setup(allocator: std.mem.Allocator, cfg: SetupConfig) !void {
    try handler.init(allocator, cfg.should_send_eoi);

    const tramps = try trampolines.Trampolines.init(allocator);
    const idt_ptr = try allocator.create(idt.Idt);

    for (0..idt.NUM_VECTORS) |i| {
        idt_ptr.setGate(@intCast(i), tramps.vectorAddr(i), cfg.force_trap);
    }
    idt_ptr.load();

    pic.init(.{ .aeoi = cfg.aeoi });
}
