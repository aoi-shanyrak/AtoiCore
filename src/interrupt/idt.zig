const std = @import("std");

pub const NUM_VECTORS: u32 = 256;

const kernel_code_segment = @extern(*const anyopaque, .{ .name = "KERNEL_CODE_SEGMENT" });

const InterruptVector = @import("interruptVector.zig").InterruptVector;

const IdtGate = packed struct(u64) {
    offset_low: u16,
    segment_selector: u16,
    zero1: u8,
    type: u3,
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
    entries: [NUM_VECTORS]IdtGate align(16),

    pub fn setGate(self: *Idt, vec: u8, handler_addr: usize) void {
        const vector: InterruptVector = @fromBackingInt(@intCast(vec));
        self.entries[vec] = .{
            .offset_low = @truncate(handler_addr),
            .segment_selector = @truncate(@intFromPtr(kernel_code_segment)),
            .zero1 = 0,
            .type = @backingInt(vector.gateType()),
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
};

comptime {
    std.debug.assert(@sizeOf(Idt) == 2048);
    std.debug.assert(@bitSizeOf(IdtGate) == 64);
}
