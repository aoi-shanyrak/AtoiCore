const io = @import("io");
const std = @import("std");

const EOI: u8 = 0x20;

const MASTER_CMD_PORT: u16 = 0x20;
const MASTER_DATA_PORT: u16 = 0x21;
const SLAVE_CMD_PORT: u16 = 0xA0;
const SLAVE_DATA_PORT: u16 = 0xA1;

pub const MASTER_VECTOR_OFFSET: u8 = 32;
pub const SLAVE_VECTOR_OFFSET: u8 = 40;

pub const IRQ_COUNT: u8 = 16;
pub const LINES_PER_PIC: u8 = 8;

pub const Irq = enum(u4) {
    timer = 0,
    keyboard = 1,
    cascade = 2,
    _,
};

const Icw1 = packed struct(u8) {
    icw4_needed: bool = true,
    single: bool = false,
    _mcs80: u1 = 0,
    level_triggered: bool = false,
    init: bool = true,
    _mcs80_3: u3 = 0,
};

const Icw4 = packed struct(u8) {
    fnm_0: u1 = 1,
    aeoi: bool = false,
    fnm_234: u3 = 0,
    _res3: u3 = 0,
};

pub const Config = struct {
    irq_mask: u16 = 0,
    aeoi: bool = false,
};

var cur_cfg: Config = .{};

pub fn init(cfg: Config) void {
    cur_cfg = cfg;

    const icw1: u8 = @bitCast(Icw1{});
    const icw4: u8 = @bitCast(Icw4{ .aeoi = cur_cfg.aeoi });

    send(MASTER_CMD_PORT, icw1);
    send(SLAVE_CMD_PORT, icw1);

    send(MASTER_DATA_PORT, 0x20);
    send(SLAVE_DATA_PORT, 0x28);

    send(MASTER_DATA_PORT, 1 << 2);
    send(SLAVE_DATA_PORT, 2);

    send(MASTER_DATA_PORT, icw4);
    send(SLAVE_DATA_PORT, icw4);

    var irq_mask: u16 = ~cfg.irq_mask;
    if ((cfg.irq_mask & 0xFF00) != 0)
        irq_mask &= ~(@as(u16, 1) << 2);
    send(MASTER_DATA_PORT, @truncate(irq_mask));
    send(SLAVE_DATA_PORT, @truncate(irq_mask >> 8));
}

inline fn send(port: u16, val: u8) void {
    io.outb(port, val);
    io.wait();
}

pub fn sendEOI(irq: u8) void {
    if (cur_cfg.aeoi) return;

    if (irq >= LINES_PER_PIC)
        send(SLAVE_CMD_PORT, EOI);
    send(MASTER_CMD_PORT, EOI);
}

pub fn mask(irq: Irq) void {
    const line = @backingInt(irq);
    if (line < LINES_PER_PIC) {
        const bit: u8 = @as(u8, 1) << @intCast(line);
        send(MASTER_DATA_PORT, io.inb(MASTER_DATA_PORT) | bit);
    } else {
        const bit: u8 = @as(u8, 1) << @intCast(LINES_PER_PIC - line);
        send(SLAVE_DATA_PORT, io.inb(SLAVE_DATA_PORT) | bit);
    }
}

pub fn unmask(irq: Irq) void {
    const line = @backingInt(irq);
    if (line < LINES_PER_PIC) {
        const bit: u8 = @as(u8, 1) << @intCast(line);
        send(MASTER_DATA_PORT, io.inb(MASTER_DATA_PORT) & ~bit);
    } else {
        const cascade_bit: u8 = @as(u8, 1) << @backingInt(Irq.cascade);
        send(MASTER_DATA_PORT, io.inb(MASTER_DATA_PORT) & ~cascade_bit);

        const bit: u8 = @as(u8, 1) << @intCast(LINES_PER_PIC - line);
        send(SLAVE_DATA_PORT, io.inb(SLAVE_DATA_PORT) & ~bit);
    }
}
