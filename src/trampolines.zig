const std = @import("std");
const defs = @import("defs.zig");
const handler = @import("handler.zig");

const NUM_VECTORS = defs.NUM_VECTORS;

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

var ctx_addr: usize = undefined;
var ctx_addr_noerr: usize = undefined;

fn initHandlers() void {
    ctx_addr = @intFromPtr(&collect_ctx);
    ctx_addr_noerr = @intFromPtr(&collect_ctx_noerr);
}

pub fn genTrampolines(buffer: *[TRAMPOLINES_SIZE]u8) !void {
    initHandlers();

    var writer = std.Io.Writer.fixed(buffer[0..]);
    const base = @intFromPtr(buffer);

    const err_stub_addr = base;
    try writeJmpRel32(&writer, err_stub_addr, ctx_addr);
    var last_noerr_stub_addr = base + writer.end;
    try writeJmpRel32(&writer, last_noerr_stub_addr, ctx_addr_noerr);

    for (0..NUM_VECTORS) |i| {
        const vec: u8 = @intCast(i);

        if (i != 0 and i % STUB_INTERVAL == 0) {
            last_noerr_stub_addr = base + writer.end;
            try writeJmpRel32(&writer, base, ctx_addr_noerr);
        }
        try writer.writeByte(@backingInt(Opcode.push_imm8));
        try writer.writeByte(vec);

        const target = if (handler.hasErrorCode(vec)) err_stub_addr else last_noerr_stub_addr;
        try writeJmpRel8(&writer, base, target);
    }
    std.debug.assert(writer.end == TRAMPOLINES_SIZE);
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
    return @as(i32, @intCast(to)) - @as(i32, @intCast(from));
}

fn getRel8(from: usize, to: usize) i8 {
    const diff = getRel32(from, to);
    if (std.math.maxInt(i8) < diff or diff < std.math.minInt(i8)) {
        @panic("jmp short out of bounds");
    }
    return @intCast(diff);
}

pub fn vectorAddr(base: usize, vec: usize) usize {
    const k = vec / STUB_INTERVAL;
    return base + 2 * JMP_REL32_SIZE + k * JMP_REL32_SIZE + vec * VECTOR_TRAMP_SIZE;
}
