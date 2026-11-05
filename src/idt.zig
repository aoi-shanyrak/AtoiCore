const std = @import("std");

const NUM_VECTORS = @import("defs.zig").NUM_VECTORS;

const IdtGate = packed struct(64) {
    offset_low: u16,
    segment_selector: u16,
    zero: u8,
    type_: u4,
    storage: u1,
    dpl: u2,
    present: u1,
    offset_high: u16,
};

const IdtPtr = packed struct {
    limit: u16,
    base: u32,
};

pub const Idt = struct {
    entries: [NUM_VECTORS]IdtGate,

    pub fn setGate(self: *Idt, vec: u8, handler_addr: usize) void {
        self.entries[vec] = .{
            .offset_low = @truncate(handler_addr),
            .segment_selector = 
        };
    }
};
