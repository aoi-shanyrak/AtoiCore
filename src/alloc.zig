const std = @import("std");
const panic_mod = @import("panic.zig");

extern const __kernel_end: u8;

const ARENA_END: usize = 0x80000;
var arena_start: usize = 0;
var arena_ptr: usize = 0;

pub fn init() void {
    arena_start = @intFromPtr(&__kernel_end);
    arena_ptr = arena_start;
}

fn alignForward(addr: usize, alignment: usize) usize {
    return (addr + alignment - 1) & ~(alignment - 1);
}

pub const Error = error{OutOfMemory};

pub fn tryAllocUndead(size: usize, alignment: usize) Error![]u8 {
    const a = if (alignment == 0) 1 else alignment;
    const aligned = alignForward(arena_ptr, a);
    if (aligned > ARENA_END or size > ARENA_END - aligned) {
        return Error.OutOfMemory;
    }
    arena_ptr = aligned + size;
    return @as([*]u8, @ptrFromInt(aligned))[0..size];
}

pub fn allocUndead(size: usize, alignment: usize) []u8 {
    return tryAllocUndead(size, alignment) catch |e| switch (e) {
        error.OutOfMemory => panic_mod.panic(
            "arena out of memory: need %d bytes",
            @as(c_uint, @intCast(size)),
        ),
    };
}

fn vtableAlloc(
    _: *anyopaque,
    len: usize,
    alignment: std.mem.Alignment,
    _: usize,
) ?[*]u8 {
    const a = alignment.toByteUnits();
    const buf = tryAllocUndead(len, a) catch {
        panic_mod.panic("arena out of memory: need %u bytes\n", @as(c_uint, @intCast(len)));
    };
    return buf.ptr;
}

fn vtableResize(
    _: *anyopaque,
    memory: []u8,
    _: std.mem.Alignment,
    new_len: usize,
    _: usize,
) bool {
    if (new_len <= memory.len) return true;

    const mem_end = @intFromPtr(memory.ptr) + memory.len;
    if (mem_end != arena_ptr) return false;

    const extra = new_len - memory.len;
    if (extra > ARENA_END - arena_ptr) return false;

    arena_ptr += extra;
    return true;
}

fn vtableRemap(
    ctx: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) ?[*]u8 {
    if (vtableResize(ctx, memory, alignment, new_len, ret_addr)) {
        return memory.ptr;
    }
    return null;
}

fn vtableFree(
    _: *anyopaque,
    _: []u8,
    _: std.mem.Alignment,
    _: usize,
) void {}

const vtable = std.mem.Allocator.VTable{
    .alloc = vtableAlloc,
    .resize = vtableResize,
    .remap = vtableRemap,
    .free = vtableFree,
};

pub fn allocator() std.mem.Allocator {
    return .{
        .ptr = undefined,
        .vtable = &vtable,
    };
}
