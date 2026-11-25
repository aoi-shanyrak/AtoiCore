const GateType = enum(u3) {
    interrupt = 0b110,
    trap = 0b111,
};

pub const InterruptVector = enum(u8) {
    // CPU
    divide_error = 0,
    debug = 1,
    nmi = 2,
    breakpoint = 3,
    overflow = 4,
    bound_range = 5,
    invalid_opcode = 6,
    device_not_available = 7,
    double_fault = 8,
    coprocessor_segment = 9,
    invalid_tss = 10,
    segment_not_present = 11,
    stack_segment_fault = 12,
    general_protection = 13,
    page_fault = 14,
    _reserved15 = 15,
    math_fault = 16,
    alignment_check = 17,
    machine_check = 18,
    simd_floating_point = 19,
    virtualization = 20,
    control_protection = 21,
    // PIC
    timer = 32,
    keyboard = 33,
    pic_cascade = 34,
    _,

    pub fn hasErrorCode(self: InterruptVector) bool {
        return switch (self) {
            .double_fault,
            .invalid_tss,
            .segment_not_present,
            .stack_segment_fault,
            .general_protection,
            .page_fault,
            .alignment_check,
            .control_protection,
            => true,
            else => false,
        };
    }

    pub fn gateType(self: InterruptVector) GateType {
        return switch (self) {
            .breakpoint, .overflow => .trap,
            else => .interrupt,
        };
    }

    pub fn isPicIrq(self: InterruptVector) bool {
        const v: u8 = @backingInt(self);
        return v >= 32 and v < 48;
    }

    pub fn picIrqNum(self: InterruptVector) u8 {
        return @as(u8, @fromBackingInt(@intCast(self))) - 32;
    }

    pub fn mnemonic(self: InterruptVector) ?*const [3:0]u8 {
        return switch (self) {
            .divide_error => "#DE",
            .debug => "#DB",
            .nmi => null,
            .breakpoint => "#BP",
            .overflow => "#OF",
            .bound_range => "#BR",
            .invalid_opcode => "#UD",
            .device_not_available => "#NM",
            .double_fault => "#DF",
            .coprocessor_segment => null,
            .invalid_tss => "#TS",
            .segment_not_present => "#NP",
            .stack_segment_fault => "#SS",
            .general_protection => "#GP",
            .page_fault => "#PF",
            ._reserved15 => null,
            .math_fault => "#MF",
            .alignment_check => "#AC",
            .machine_check => "#MC",
            .simd_floating_point => "#XM",
            .virtualization => "#VE",
            .control_protection => "#CP",
            else => null,
        };
    }
};
