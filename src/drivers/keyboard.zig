const std = @import("std");
const ps2 = @import("ps2.zig");
const interrupts = @import("interrupts");

const Command = enum(u8) {
    set_leds = 0xED,
    echo = 0xEE,
    scancode_set = 0xF0,
    identify = 0xF2,
    typematic_rate = 0xF3,
    enable_scanning = 0xF4,
    disable_scanning = 0xF5,
    set_defaults = 0xF6,
    resend = 0xFE,
    reset = 0xFF,
};

const Response = enum(u8) {
    buffer_overrun_0 = 0x00,
    self_test_passed = 0xAA,
    echo = 0xEE,
    ack = 0xFA,
    self_test_failed1 = 0xFC,
    self_test_failed2 = 0xFD,
    resend = 0xFE,
    buffer_overrun_ff = 0xFF,
    _,
};

const ScanCodeSet = enum(u8) {
    set_1 = 1,
    set_2 = 2,
    set_3 = 3,

    pub fn toByte(self: ScanCodeSet) u8 {
        return @backingInt(self);
    }
};

const LedState = packed struct(u8) {
    scroll_lock: bool = false,
    num_lock: bool = false,
    caps_lock: bool = false,
    _res: u5 = 0,

    pub fn toByte(self: LedState) u8 {
        return @bitCast(self);
    }
};

const TypematicConfig = packed struct(u8) {
    repeat_rate: Rate = .default_10_9hz,
    delay: Delay = .ms_500,
    _res: u1 = 0,

    pub const Rate = enum(u5) {
        fastest_30hz = 0x00,
        default_10_9hz = 0x0B,
        slowest_2hz = 0x1F,
        _,
    };

    pub const Delay = enum(u2) {
        ms_250 = 0b00,
        ms_500 = 0b01,
        ms_750 = 0b10,
        ms_1000 = 0b11,
    };

    pub fn toByte(self: TypematicConfig) u8 {
        return @bitCast(self);
    }
};

const BUFFER_CAPACITY = 64;

const EventQueue = struct {
    buf: []KeyEvent,
    mask: usize,
    head: std.atomic.Value(usize),
    tail: std.atomic.Value(usize),

    fn init(allocator: std.mem.Allocator, comptime capacity: usize) !EventQueue {
        comptime {
            if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
                @compileError("EventQueue capacity must be a power of 2");
            }
        }
        return .{
            .buf = try allocator.alloc(KeyEvent, capacity),
            .mask = capacity - 1,
            .head = std.atomic.Value(usize).init(0),
            .tail = std.atomic.Value(usize).init(0),
        };
    }

    fn push(self: *EventQueue, event: KeyEvent) void {
        const head = self.head.load(.monotonic);
        const tail = self.tail.load(.acquire);

        if ((head -% tail) == self.buf.len) return;

        self.buf[head & self.mask] = event;
        self.head.store(head +% 1, .release);
    }

    fn pop(self: *EventQueue) ?KeyEvent {
        const tail = self.tail.load(.monotonic);
        const head = self.head.load(.acquire);

        if (tail == head) return null;

        const item = self.buf[tail & self.mask];
        self.tail.store(tail +% 1, .release);
        return item;
    }
};

const MAX_COMMAND_RETRIES = 3;

var kbd: Keyboard = .{};
var event_queue: ?EventQueue = null;

pub const Error = ps2.Error || std.mem.Allocator.Error || error{
    ResetFailed,
    CommandRejected,
};

pub fn init(allocator: std.mem.Allocator) Error!void {
    event_queue = try EventQueue.init(allocator, BUFFER_CAPACITY);

    ps2.flushOutputBuffer();

    try resetDevice();
    try setScanCodeSet(.set_2);
    try setLeds(.{});
    try setTypematic(.{});

    ps2.flushOutputBuffer();
    try sendCommand(.enable_scanning);

    interrupts.handler.register(.keyboard, onKeyboardIRQ);
    interrupts.pic.unmask(.keyboard);
}

fn resetDevice() Error!void {
    try sendCommand(.reset);
    if (try ps2.readData() != @backingInt(Response.self_test_passed)) {
        return Error.ResetFailed;
    }
}

fn setScanCodeSet(set: ScanCodeSet) Error!void {
    try sendCommandWithData(.scancode_set, set.toByte());
}

fn setLeds(leds: LedState) Error!void {
    try sendCommandWithData(.set_leds, leds.toByte());
}

fn setTypematic(cfg: TypematicConfig) Error!void {
    try sendCommandWithData(.typematic_rate, cfg.toByte());
}

fn sendCommand(cmd: Command) Error!void {
    try sendPacket(&.{@backingInt(cmd)});
}

fn sendCommandWithData(cmd: Command, data: u8) Error!void {
    try sendPacket(&.{ @backingInt(cmd), data });
}

fn sendPacket(bytes: []const u8) Error!void {
    var retries: usize = MAX_COMMAND_RETRIES;
    retry_loop: while (retries > 0) : (retries -= 1) {
        for (bytes) |byte| {
            try ps2.writeData(byte);
            const resp: Response = @fromBackingInt(@intCast(try ps2.readData()));
            switch (resp) {
                .ack => {},
                .resend => continue :retry_loop,
                else => return Error.CommandRejected,
            }
        }
        return;
    }
    return Error.CommandRejected;
}

fn onKeyboardIRQ(_: *interrupts.Context) void {
    const byte = ps2.readData() catch return;
    if (kbd.processByte(byte)) |event| {
        if (event_queue) |*q| {
            q.push(event);
        }
    }
}

pub fn pollEvent() ?KeyEvent {
    if (kbd.leds_dirty.swap(false, .acq_rel)) {
        interrupts.pic.mask(.keyboard);
        kbd.syncLeds();
        interrupts.pic.unmask(.keyboard);
    }
    if (event_queue) |*q| {
        return q.pop();
    }
    return null;
}

pub const Modifiers = packed struct(u8) {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
    caps_lock: bool = false,
    num_lock: bool = false,
    scroll_lock: bool = false,
    _res1: u1 = 0,
};

pub const KeyEvent = struct {
    key: KeyCode,
    pressed: bool,
    char: ?u8,
    modifiers: Modifiers,
};

const ScanCode = struct {
    const prefix_extended: u8 = 0xE0;
    const prefix_pause: u8 = 0xE1;
    const pause_trailing_bytes = 5;

    const release_bit_mask: u8 = 0b10000000;
    const code_mask: u8 = 0b01111111;

    const fake_lshift_press: u8 = 0x2A;
    const fake_lshift_release: u8 = 0xAA;
    const fake_rshift_press: u8 = 0x36;
    const fake_rshift_release: u8 = 0xB6;
};

pub const Keyboard = struct {
    state: State = .normal,
    pause_skip: u8 = 0,
    pressed_keys: std.EnumSet(KeyCode) = .empty,

    caps_lock: bool = false,
    num_lock: bool = false,
    scroll_lock: bool = false,

    leds_dirty: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    const State = enum {
        normal,
        extended,
        pause_seq,
    };

    const SequenceStep = union(enum) {
        pending,
        complete_pause,
        ready: struct { raw: u8, extended: bool },
    };

    pub fn processByte(self: *Keyboard, byte: u8) ?KeyEvent {
        if (isBufferOverrun(byte)) {
            self.resetState();
            return null;
        }

        switch (self.advanceSequence(byte)) {
            .pending => return null,
            .complete_pause => return self.emitEvent(.pause, true),
            .ready => |byte_info| {
                if (isFakeShift(byte_info.extended, byte_info.raw)) return null;

                const is_pressed = (byte_info.raw & ScanCode.release_bit_mask) == 0;
                const scancode = byte_info.raw & ScanCode.code_mask;
                const key = lookupKey(scancode, byte_info.extended);

                if (key == .unknown) return null;
                return self.emitEvent(key, is_pressed);
            },
        }
    }

    fn advanceSequence(self: *Keyboard, byte: u8) SequenceStep {
        switch (self.state) {
            .normal => {
                if (byte == ScanCode.prefix_extended) {
                    self.state = .extended;
                    return .pending;
                }
                if (byte == ScanCode.prefix_pause) {
                    self.state = .pause_seq;
                    self.pause_skip = ScanCode.pause_trailing_bytes;
                    return .pending;
                }
                return .{ .ready = .{ .raw = byte, .extended = false } };
            },
            .extended => {
                self.state = .normal;
                return .{ .ready = .{ .raw = byte, .extended = true } };
            },
            .pause_seq => {
                self.pause_skip -= 1;
                if (self.pause_skip == 0) {
                    self.state = .normal;
                    return .complete_pause;
                }
                return .pending;
            },
        }
    }

    fn emitEvent(self: *Keyboard, key: KeyCode, is_pressed: bool) ?KeyEvent {
        if (key != .pause) {
            if (is_pressed) {
                self.pressed_keys.insert(key);
                if (self.toggleLock(key)) {
                    self.leds_dirty.store(true, .release);
                }
            } else {
                self.pressed_keys.remove(key);
            }
        }
        const mods = self.getModifiers();
        const ascii = if (is_pressed) mapToAscii(key, mods) else null;

        return .{
            .key = key,
            .pressed = is_pressed,
            .char = ascii,
            .modifiers = mods,
        };
    }

    fn toggleLock(self: *Keyboard, key: KeyCode) bool {
        switch (key) {
            .caps_lock => self.caps_lock = !self.caps_lock,
            .num_lock => self.num_lock = !self.num_lock,
            .scroll_lock => self.scroll_lock = !self.scroll_lock,
            else => return false,
        }
        return true;
    }

    fn getModifiers(self: *const Keyboard) Modifiers {
        return .{
            .shift = self.isAnyPressed(shift_keys),
            .ctrl = self.isAnyPressed(ctrl_keys),
            .alt = self.isAnyPressed(alt_keys),
            .super = self.isAnyPressed(super_keys),
            .caps_lock = self.caps_lock,
            .num_lock = self.num_lock,
            .scroll_lock = self.scroll_lock,
        };
    }

    const shift_keys = std.EnumSet(KeyCode).initMany(&.{ .left_shift, .right_shift });
    const ctrl_keys = std.EnumSet(KeyCode).initMany(&.{ .left_ctrl, .right_ctrl });
    const alt_keys = std.EnumSet(KeyCode).initMany(&.{ .left_alt, .right_alt });
    const super_keys = std.EnumSet(KeyCode).initMany(&.{ .left_super, .right_super });

    fn isAnyPressed(self: *const Keyboard, keys: std.EnumSet(KeyCode)) bool {
        return self.pressed_keys.intersectWith(keys).count() > 0;
    }

    fn isFakeShift(extended: bool, byte: u8) bool {
        if (!extended) return false;
        return switch (byte) {
            ScanCode.fake_lshift_press,
            ScanCode.fake_lshift_release,
            ScanCode.fake_rshift_press,
            ScanCode.fake_rshift_release,
            => true,
            else => false,
        };
    }

    fn lookupKey(scancode: u8, extended: bool) KeyCode {
        return if (extended) set1_extended[scancode] else set1_normal[scancode];
    }

    fn isKeyPressed(self: *const Keyboard, key: KeyCode) bool {
        return self.pressed_keys.contains(key);
    }

    fn isBufferOverrun(raw_byte: u8) bool {
        const resp: Response = @fromBackingInt(@intCast(raw_byte));
        return resp == .buffer_overrun_0 or resp == .buffer_overrun_ff;
    }

    fn resetState(self: *Keyboard) void {
        self.state = .normal;
        self.pause_skip = 0;
    }

    pub fn syncLeds(self: *Keyboard) void {
        setLeds(.{
            .caps_lock = self.caps_lock,
            .num_lock = self.num_lock,
            .scroll_lock = self.scroll_lock,
        }) catch {};
    }
};

pub const KeyCode = enum(u8) {
    unknown = 0,

    escape,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    print_screen,
    scroll_lock,
    pause,

    grave,
    num_1,
    num_2,
    num_3,
    num_4,
    num_5,
    num_6,
    num_7,
    num_8,
    num_9,
    num_0,
    minus,
    equal,
    backspace,

    tab,
    q,
    w,
    e,
    r,
    t,
    y,
    u,
    i,
    o,
    p,
    left_bracket,
    right_bracket,
    backslash,

    caps_lock,
    a,
    s,
    d,
    f,
    g,
    h,
    j,
    k,
    l,
    semicolon,
    apostrophe,
    enter,

    left_shift,
    z,
    x,
    c,
    v,
    b,
    n,
    m,
    comma,
    period,
    slash,
    right_shift,

    left_ctrl,
    left_super,
    left_alt,
    space,
    right_alt,
    right_super,
    menu,
    right_ctrl,

    insert,
    home,
    page_up,
    delete,
    end,
    page_down,
    up,
    down,
    left,
    right,

    num_lock,
    kp_divide,
    kp_multiply,
    kp_minus,
    kp_7,
    kp_8,
    kp_9,
    kp_plus,
    kp_4,
    kp_5,
    kp_6,
    kp_1,
    kp_2,
    kp_3,
    kp_enter,
    kp_0,
    kp_decimal,
};

const set1_normal = init: {
    var t: [128]KeyCode = @splat(.unknown);
    t[0x01] = .escape;
    t[0x02] = .num_1;
    t[0x03] = .num_2;
    t[0x04] = .num_3;
    t[0x05] = .num_4;
    t[0x06] = .num_5;
    t[0x07] = .num_6;
    t[0x08] = .num_7;
    t[0x09] = .num_8;
    t[0x0A] = .num_9;
    t[0x0B] = .num_0;
    t[0x0C] = .minus;
    t[0x0D] = .equal;
    t[0x0E] = .backspace;
    t[0x0F] = .tab;
    t[0x10] = .q;
    t[0x11] = .w;
    t[0x12] = .e;
    t[0x13] = .r;
    t[0x14] = .t;
    t[0x15] = .y;
    t[0x16] = .u;
    t[0x17] = .i;
    t[0x18] = .o;
    t[0x19] = .p;
    t[0x1A] = .left_bracket;
    t[0x1B] = .right_bracket;
    t[0x1C] = .enter;
    t[0x1D] = .left_ctrl;
    t[0x1E] = .a;
    t[0x1F] = .s;
    t[0x20] = .d;
    t[0x21] = .f;
    t[0x22] = .g;
    t[0x23] = .h;
    t[0x24] = .j;
    t[0x25] = .k;
    t[0x26] = .l;
    t[0x27] = .semicolon;
    t[0x28] = .apostrophe;
    t[0x29] = .grave;
    t[0x2A] = .left_shift;
    t[0x2B] = .backslash;
    t[0x2C] = .z;
    t[0x2D] = .x;
    t[0x2E] = .c;
    t[0x2F] = .v;
    t[0x30] = .b;
    t[0x31] = .n;
    t[0x32] = .m;
    t[0x33] = .comma;
    t[0x34] = .period;
    t[0x35] = .slash;
    t[0x36] = .right_shift;
    t[0x37] = .kp_multiply;
    t[0x38] = .left_alt;
    t[0x39] = .space;
    t[0x3A] = .caps_lock;
    t[0x3B] = .f1;
    t[0x3C] = .f2;
    t[0x3D] = .f3;
    t[0x3E] = .f4;
    t[0x3F] = .f5;
    t[0x40] = .f6;
    t[0x41] = .f7;
    t[0x42] = .f8;
    t[0x43] = .f9;
    t[0x44] = .f10;
    t[0x45] = .num_lock;
    t[0x46] = .scroll_lock;
    t[0x47] = .kp_7;
    t[0x48] = .kp_8;
    t[0x49] = .kp_9;
    t[0x4A] = .kp_minus;
    t[0x4B] = .kp_4;
    t[0x4C] = .kp_5;
    t[0x4D] = .kp_6;
    t[0x4E] = .kp_plus;
    t[0x4F] = .kp_1;
    t[0x50] = .kp_2;
    t[0x51] = .kp_3;
    t[0x52] = .kp_0;
    t[0x53] = .kp_decimal;
    t[0x57] = .f11;
    t[0x58] = .f12;
    break :init t;
};

const set1_extended = init: {
    var t: [128]KeyCode = @splat(.unknown);
    t[0x1C] = .kp_enter;
    t[0x1D] = .right_ctrl;
    t[0x35] = .kp_divide;
    t[0x37] = .print_screen;
    t[0x38] = .right_alt;
    t[0x47] = .home;
    t[0x48] = .up;
    t[0x49] = .page_up;
    t[0x4B] = .left;
    t[0x4D] = .right;
    t[0x4F] = .end;
    t[0x50] = .down;
    t[0x51] = .page_down;
    t[0x52] = .insert;
    t[0x53] = .delete;
    t[0x5B] = .left_super;
    t[0x5C] = .right_super;
    t[0x5D] = .menu;
    break :init t;
};

fn mapToAscii(key: KeyCode, mods: Modifiers) ?u8 {
    const upper = mods.shift != mods.caps_lock;
    switch (key) {
        .a => return if (upper) 'A' else 'a',
        .b => return if (upper) 'B' else 'b',
        .c => return if (upper) 'C' else 'c',
        .d => return if (upper) 'D' else 'd',
        .e => return if (upper) 'E' else 'e',
        .f => return if (upper) 'F' else 'f',
        .g => return if (upper) 'G' else 'g',
        .h => return if (upper) 'H' else 'h',
        .i => return if (upper) 'I' else 'i',
        .j => return if (upper) 'J' else 'j',
        .k => return if (upper) 'K' else 'k',
        .l => return if (upper) 'L' else 'l',
        .m => return if (upper) 'M' else 'm',
        .n => return if (upper) 'N' else 'n',
        .o => return if (upper) 'O' else 'o',
        .p => return if (upper) 'P' else 'p',
        .q => return if (upper) 'Q' else 'q',
        .r => return if (upper) 'R' else 'r',
        .s => return if (upper) 'S' else 's',
        .t => return if (upper) 'T' else 't',
        .u => return if (upper) 'U' else 'u',
        .v => return if (upper) 'V' else 'v',
        .w => return if (upper) 'W' else 'w',
        .x => return if (upper) 'X' else 'x',
        .y => return if (upper) 'Y' else 'y',
        .z => return if (upper) 'Z' else 'z',
        else => {},
    }
    if (mods.num_lock) {
        switch (key) {
            .kp_0 => return '0',
            .kp_1 => return '1',
            .kp_2 => return '2',
            .kp_3 => return '3',
            .kp_4 => return '4',
            .kp_5 => return '5',
            .kp_6 => return '6',
            .kp_7 => return '7',
            .kp_8 => return '8',
            .kp_9 => return '9',
            .kp_decimal => return '.',
            else => {},
        }
    }
    const shifted = mods.shift;
    return switch (key) {
        .num_0 => if (shifted) ')' else '0',
        .num_1 => if (shifted) '!' else '1',
        .num_2 => if (shifted) '@' else '2',
        .num_3 => if (shifted) '#' else '3',
        .num_4 => if (shifted) '$' else '4',
        .num_5 => if (shifted) '%' else '5',
        .num_6 => if (shifted) '^' else '6',
        .num_7 => if (shifted) '&' else '7',
        .num_8 => if (shifted) '*' else '8',
        .num_9 => if (shifted) '(' else '9',
        .minus => if (shifted) '_' else '-',
        .equal => if (shifted) '+' else '=',
        .left_bracket => if (shifted) '{' else '[',
        .right_bracket => if (shifted) '}' else ']',
        .semicolon => if (shifted) ':' else ';',
        .apostrophe => if (shifted) '"' else '\'',
        .grave => if (shifted) '~' else '`',
        .backslash => if (shifted) '|' else '\\',
        .comma => if (shifted) '<' else ',',
        .period => if (shifted) '>' else '.',
        .slash => if (shifted) '?' else '/',
        .kp_divide => '/',
        .kp_multiply => '*',
        .kp_minus => '-',
        .kp_plus => '+',
        .kp_enter, .enter => '\n',
        .space => ' ',
        .tab => '\t',
        .backspace => 0x08,
        .escape => 0x1B,
        else => null,
    };
}
