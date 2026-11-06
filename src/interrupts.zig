const std = @import("std");
const idt_mod = @import("idt.zig");
const defs = @import("defs.zig");
const tramp = @import("trampolines.zig");

const Context = extern struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    gs: u32,
    fs: u32,
    es: u32,
    ds: u32,

    vector: u32,
    error_code: u32,

    eip: u32,
    cs: u32,
    eflags: u32,
};

pub fn setup(allocator: *std.mem.Allocator) !void {
    const tramps_buf = try allocator.alloc(u8, tramp.TRAMPOLINES_SIZE);
    const tramps: *[tramp.TRAMPOLINES_SIZE]u8 = @ptrCast(tramps_buf.ptr);
    try tramp.genTrampolines(tramps);

    const idt_buf = try allocator.alignedAlloc(u8, 8, @sizeOf(idt_mod.Idt));
    const idt_ptr: *idt_mod.Idt = @ptrCast(idt_buf.ptr);

    const base = @intFromPtr(tramps);
    for (0..defs.NUM_VECTORS) |i| {
        idt_ptr.setGate(@intCast(i), tramp.vectorAddr(base, i));
    }
    idt_ptr.load();
}

pub fn enableInterrupts() void {
    asm volatile ("sti");
}

pub fn disableInterrupts() void {
    asm volatile ("cli");
}
