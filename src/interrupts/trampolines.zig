const std = @import("std");

const InterruptVector = @import("interruptVector.zig").InterruptVector;

const NUM_VECTORS = @import("idt.zig").NUM_VECTORS;

const STUB_INTERVAL = 30;
const JMP_REL32_SIZE = 5;
const JMP_REL8_SIZE = 2;
const PUSH_IMM8_SIZE = 2;

const VECTOR_TRAMP_SIZE = JMP_REL8_SIZE + PUSH_IMM8_SIZE;
const STUB_COUNT = 2 + (NUM_VECTORS - 1) / STUB_INTERVAL;

pub const TRAMPOLINES_SIZE = STUB_COUNT * JMP_REL32_SIZE + NUM_VECTORS * VECTOR_TRAMP_SIZE;

const Opcode = enum(u8) {
    jmp_rel32 = 0xE9,
    jmp_rel8 = 0xEB,
    push_imm8 = 0x6A,
};

extern fn collect_ctx() void;
extern fn collect_ctx_noerr() void;

pub const Trampolines = struct {
    buffer: *[TRAMPOLINES_SIZE]u8,

    pub fn init(allocator: std.mem.Allocator) !Trampolines {
        const buf = try allocator.create([TRAMPOLINES_SIZE]u8);

        var writer = std.Io.Writer.fixed(buf);
        try emitTrampolines(
            &writer,
            @intFromPtr(buf),
            @intFromPtr(&collect_ctx),
            @intFromPtr(&collect_ctx_noerr),
        );
        return .{ .buffer = buf };
    }

    pub fn vectorAddr(self: Trampolines, vec: usize) usize {
        const base = @intFromPtr(self.buffer);
        const k = vec / STUB_INTERVAL;
        return base + 2 * JMP_REL32_SIZE + k * JMP_REL32_SIZE + vec * VECTOR_TRAMP_SIZE;
    }
};

pub fn emitTrampolines(
    writer: *std.Io.Writer,
    base: usize,
    err_target: usize,
    noerr_target: usize,
) !void {
    const err_stub_addr = base;
    try writeJmpRel32(writer, err_stub_addr, err_target);

    var last_noerr_stub_addr = base + writer.end;
    try writeJmpRel32(writer, last_noerr_stub_addr, noerr_target);

    for (0..NUM_VECTORS) |i| {
        const vec: u8 = @intCast(i);

        if (i != 0 and i % STUB_INTERVAL == 0) {
            last_noerr_stub_addr = base + writer.end;
            try writeJmpRel32(writer, base, noerr_target);
        }
        try writer.writeByte(@backingInt(Opcode.push_imm8));
        try writer.writeByte(vec);

        const target = if (@as(InterruptVector, @fromBackingInt(@intCast(vec))).hasErrorCode())
            err_stub_addr
        else
            last_noerr_stub_addr;
        try writeJmpRel8(writer, base, target);
    }
}

fn writeJmpRel32(writer: *std.Io.Writer, addr: usize, target: usize) !void {
    const next_instr_addr = addr + writer.end + JMP_REL32_SIZE;
    const rel = getRel32(next_instr_addr, target);
    try writer.writeByte(@backingInt(Opcode.jmp_rel32));
    try writer.writeInt(i32, rel, .little);
}

fn writeJmpRel8(writer: *std.Io.Writer, addr: usize, target: usize) !void {
    const next_instr_addr = addr + writer.end + JMP_REL8_SIZE;
    const rel = getRel8(next_instr_addr, target);
    try writer.writeByte(@backingInt(Opcode.jmp_rel8));
    try writer.writeInt(i8, rel, .little);
}

fn getRel32(from: usize, to: usize) i32 {
    return @bitCast(@as(u32, @truncate(to -% from)));
}

fn getRel8(from: usize, to: usize) i8 {
    const diff = getRel32(from, to);
    if (std.math.maxInt(i8) < diff or diff < std.math.minInt(i8)) {
        @panic("jmp short out of bounds");
    }
    return @intCast(diff);
}

comptime {
    @setEvalBranchQuota(10_000);
    var dummy: [TRAMPOLINES_SIZE]u8 = undefined;
    var writer = std.Io.Writer.fixed(&dummy);
    emitTrampolines(&writer, 0x1000, 0x2000, 0x3000) catch @compileError("trampoline buffer overflow");
    if (writer.end != TRAMPOLINES_SIZE) {
        @compileError("TRAMPOLINES_SIZE mismatch");
    }
}
