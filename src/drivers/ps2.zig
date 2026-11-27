const io = @import("io");

const Port = struct {
    const data: u16 = 0x60;
    const status: u16 = 0x64;
    const command: u16 = 0x64;
};

const Status = packed struct(u8) {
    output_full: bool,
    input_full: bool,
    system_flag: bool,
    command_data: u1,
    inhibit_switch: u1,
    tx_timeout: bool,
    rx_timeout: bool,
    parity_error: bool,
};

const CommandByte = packed struct(u8) {
    irq1_enable: bool,
    irq12_enable: bool,
    system_flag: bool,
    _res0: u1,
    disable_port1: bool,
    disable_port2: bool,
    translation: bool,
    _res1: u1,
};

const ControllerCmd = enum(u8) {
    read_config = 0x20,
    write_config = 0x60,
    disable_port2 = 0xA7,
    enable_port2 = 0xA8,
    self_test = 0xAA,
    test_port1 = 0xAB,
    disable_port1 = 0xAD,
    enable_port1 = 0xAE,
};

const SELF_TEST_OK: u8 = 0x55;
const PORT_TEST_OK: u8 = 0x00;
const TIMEOUT_SPINS: usize = 10_000_000;

pub const Error = error{
    Timeout,
    SelfTestFailed,
    PortTestFailed,
};

pub fn init() Error!void {
    try sendCommand(.disable_port1);
    try sendCommand(.disable_port2);
    flushOutputBuffer();

    var cfg = try readConfig();
    cfg.irq1_enable = false;
    cfg.irq12_enable = false;
    cfg.disable_port1 = false;
    cfg.disable_port2 = true;
    cfg.translation = true;
    try writeConfig(cfg);

    try runSelfTest(cfg);
    try testPort1();

    try sendCommand(.enable_port1);

    flushOutputBuffer();
}

pub fn enablePort1Irq() Error!void {
    var cfg = try readConfig();
    cfg.irq1_enable = true;
    try writeConfig(cfg);
}

fn runSelfTest(saved_cfg: CommandByte) Error!void {
    try sendCommand(.self_test);
    if (try readData() != SELF_TEST_OK) {
        return Error.SelfTestFailed;
    }
    try writeConfig(saved_cfg);
}

fn testPort1() Error!void {
    try sendCommand(.test_port1);
    if (try readData() != PORT_TEST_OK) {
        return Error.PortTestFailed;
    }
}

fn readConfig() Error!CommandByte {
    try sendCommand(.read_config);
    return @bitCast(try readData());
}

fn writeConfig(cfg: CommandByte) Error!void {
    try sendCommand(.write_config);
    try writeData(@bitCast(cfg));
}

fn sendCommand(cmd: ControllerCmd) Error!void {
    try waitInputEmpty();
    io.outb(Port.command, @backingInt(cmd));
}

pub fn readData() Error!u8 {
    try waitOutputFull();
    return io.inb(Port.data);
}

pub fn writeData(data: u8) Error!void {
    try waitInputEmpty();
    io.outb(Port.data, data);
}

fn waitInputEmpty() Error!void {
    for (0..TIMEOUT_SPINS) |_| {
        if (!readStatus().input_full) return;
    }
    return Error.Timeout;
}

fn waitOutputFull() Error!void {
    for (0..TIMEOUT_SPINS) |_| {
        if (readStatus().output_full) return;
    }
    return Error.Timeout;
}

fn readStatus() Status {
    return @bitCast(io.inb(Port.status));
}

pub fn flushOutputBuffer() void {
    while (readStatus().output_full) {
        _ = io.inb(Port.data);
    }
}
