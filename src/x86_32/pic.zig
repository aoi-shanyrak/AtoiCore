const defs = @import("defs.zig");

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
    irq_mask: u16 = 0b0000000000000011,
    aeoi: bool = false,
};

var cur_cfg: Config = .{};

pub fn init(cfg: Config) void {
    cur_cfg = cfg;

    const icw1: u8 = @bitCast(Icw1{});
    const icw4: u8 = @bitCast(Icw4{ .aeoi = cur_cfg.aeoi });

    send(defs.MASTER_CMD_PORT, icw1);
    send(defs.SLAVE_CMD_PORT, icw1);

    send(defs.MASTER_DATA_PORT, 0x20);
    send(defs.SLAVE_DATA_PORT, 0x28);

    send(defs.MASTER_DATA_PORT, 1 << 2);
    send(defs.SLAVE_DATA_PORT, 2);

    send(defs.MASTER_DATA_PORT, icw4);
    send(defs.SLAVE_DATA_PORT, icw4);

    var mask: u16 = ~cfg.irq_mask;
    if ((cfg.irq_mask & 0xFF00) != 0)
        mask &= ~(@as(u16, 1) << 2);
    send(defs.MASTER_DATA_PORT, @truncate(mask));
    send(defs.SLAVE_DATA_PORT, @truncate(mask >> 8));
}

inline fn send(port: u16, val: u8) void {
    outb(port, val);
    ioWait();
}

inline fn ioWait() void {
    outb(0x80, 0);
}

pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub inline fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "{dx}" (port),
    );
}

pub fn sendEOI(irq: u8) void {
    if (cur_cfg.aeoi) return;

    const eoi: u8 = 0x20;
    if (irq >= 8)
        send(defs.SLAVE_CMD_PORT, eoi);
    send(defs.MASTER_CMD_PORT, eoi);
}
