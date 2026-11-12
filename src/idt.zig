const std = @import("std");
const defs = @import("defs.zig");

const GateType = enum(u3) {
    interrupt = 0b110,
    trap = 0b111,
};

const IdtGate = packed struct(u64) {
    offset_low: u16,
    segment_selector: u16,
    zero1: u8,
    type_: u3,
    D: u1,
    zero2: u1,
    dpl: u2,
    present: u1,
    offset_high: u16,
};

const IdtPtr = packed struct {
    limit: u16,
    base: u32,
};

pub const Idt = struct {
    entries: [defs.NUM_VECTORS]IdtGate,

    pub fn setGate(self: *Idt, vec: u8, handler_addr: usize) void {
        self.entries[vec] = .{
            .offset_low = @truncate(handler_addr),
            .segment_selector = defs.KERNEL_CODE_SEGMENT,
            .zero1 = 0,
            .type_ = @backingInt(if (isTrapVec(vec)) GateType.trap else GateType.interrupt),
            .D = 1,
            .zero2 = 0,
            .dpl = 0,
            .present = 1,
            .offset_high = @truncate(handler_addr >> 16),
        };
    }

    pub fn load(self: *Idt) void {
        const ptr = IdtPtr{
            .limit = @sizeOf(@TypeOf(self.entries)) - 1,
            .base = @intFromPtr(&self.entries),
        };
        asm volatile ("lidt (%[ptr])"
            :
            : [ptr] "r" (&ptr),
            : .{ .memory = true });
    }

    fn isTrapVec(vec: u8) bool {
        return switch (vec) {
            3, 4 => true,
            else => false,
        };
    }
};

comptime {
    std.debug.assert(@sizeOf(Idt) == 2048);
    std.debug.assert(@bitSizeOf(IdtGate) == 64);
}
