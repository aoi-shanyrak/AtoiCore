const io = @import("io");
const std = @import("std");
const interrupts = @import("interrupts");

const BASE_FREQUENCY: u32 = 1_193_182;

const MIN_DIVISOR: u32 = 2;
const MAX_DIVISOR: u32 = std.math.maxInt(u16) + 1;
const MAX_DIVISOR_HW_VALUE: u16 = 0;

var ticks: u32 = 0;

const Port = enum(u16) {
    channel0 = 0x40,
    channel1 = 0x41,
    channel2 = 0x42,
    command = 0x43,
};

const Channel = enum(u2) {
    channel0 = 0b00,
    channel1 = 0b01,
    channel2 = 0b10,
    read_back = 0b11,
};

const AccessMode = enum(u2) {
    latch = 0b00,
    lobyte = 0b01,
    hibyte = 0b10,
    lobyte_hibyte = 0b11,
};

const OperatingMode = enum(u3) {
    interrupt_on_terminal_count = 0b000,
    hardware_retriggerable_one_shot = 0b001,
    rate_generator = 0b010,
    square_wave_generator = 0b011,
    software_triggered_strobe = 0b100,
    hardware_triggered_strobe = 0b101,
};

const BcdMode = enum(u1) {
    binary = 0,
    bcd = 1,
};

const ControlWord = packed struct(u8) {
    bcd: BcdMode = .binary,
    mode: OperatingMode,
    access: AccessMode,
    channel: Channel,
};

pub const Error = error{
    InvalidFrequency,
};

pub fn init(freq_hz: u32) Error!void {
    if (freq_hz == 0) return Error.InvalidFrequency;
    const raw_div = BASE_FREQUENCY / freq_hz;
    if (raw_div < MIN_DIVISOR or raw_div > MAX_DIVISOR) return Error.InvalidFrequency;

    const div: u16 = if (raw_div == MAX_DIVISOR) MAX_DIVISOR_HW_VALUE else @intCast(raw_div);

    const cmd = ControlWord{
        .channel = .channel0,
        .access = .lobyte_hibyte,
        .mode = .rate_generator,
        .bcd = .binary,
    };

    io.outb(@backingInt(Port.command), @bitCast(cmd));

    io.outb(@backingInt(Port.channel0), @truncate(div));
    io.outb(@backingInt(Port.channel0), @truncate(div >> 8));

    interrupts.handler.register(.timer, onTimerIRQ);
    interrupts.pic.unmask(.timer);
}

fn onTimerIRQ(_: *interrupts.Context) void {
    ticks += 1;
}

pub fn getTicks() u32 {
    return ticks;
}
