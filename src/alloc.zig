const std = @import("std");
const panic_mod = @import("panic.zig");

extern const __kernel_end: u8;

pub const ARENA1_END: usize = 0x80000;
pub const ARENA2_START: usize = 0x100000;
pub const ARENA2_END: usize = 0x4000000;

pub const Arena = struct {
    arena1_ptr: usize,
    arena2_ptr: usize,

    pub fn init(self: *Arena) void {
        self.arena1_ptr = @intFromPtr(&__kernel_end);
        self.arena2_ptr = ARENA2_START;
    }

    pub fn allocator(self: *Arena) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn alignForward(addr: usize, alignment: usize) usize {
        return (addr + alignment - 1) & ~(alignment - 1);
    }

    pub const Error = error{OutOfMemory};

    pub fn tryAllocUndead(self: *Arena, size: usize, alignment: usize) Error![]u8 {
        const a = if (alignment == 0) 1 else alignment;

        const aligned1 = alignForward(self.arena1_ptr, a);
        if (aligned1 <= ARENA1_END and size <= ARENA1_END - aligned1) {
            self.arena1_ptr = aligned1 + size;
            return @as([*]u8, @ptrFromInt(aligned1))[0..size];
        }

        const aligned2 = alignForward(self.arena2_ptr, a);
        if (aligned2 <= ARENA2_END and size <= ARENA2_END - aligned2) {
            self.arena2_ptr = aligned2 + size;
            return @as([*]u8, @ptrFromInt(aligned2))[0..size];
        }

        return Error.OutOfMemory;
    }

    pub fn allocUndead(self: *Arena, size: usize, alignment: usize) []u8 {
        return self.tryAllocUndead(size, alignment) catch |e| switch (e) {
            error.OutOfMemory => panic_mod.panic(
                "arena out of memory: need {d} bytes",
                .{size},
            ),
        };
    }
};

fn vtableAlloc(
    ctx: *anyopaque,
    len: usize,
    alignment: std.mem.Alignment,
    _: usize,
) ?[*]u8 {
    const self: *Arena = @ptrCast(@alignCast(ctx));
    const a = alignment.toByteUnits();

    const buf = self.tryAllocUndead(len, a) catch {
        panic_mod.panic("arena out of memory: need {d} bytes\n", .{len});
    };
    return buf.ptr;
}

fn vtableResize(
    ctx: *anyopaque,
    memory: []u8,
    _: std.mem.Alignment,
    new_len: usize,
    _: usize,
) bool {
    const self: *Arena = @ptrCast(@alignCast(ctx));

    if (new_len <= memory.len) return true;

    const mem_end = @intFromPtr(memory.ptr) + memory.len;
    const extra = new_len - memory.len;

    if (mem_end == self.arena1_ptr and extra <= ARENA1_END - self.arena1_ptr) {
        self.arena1_ptr += extra;
        return true;
    }
    if (mem_end == self.arena2_ptr and extra <= ARENA2_END - self.arena2_ptr) {
        self.arena2_ptr += extra;
        return true;
    }
    return false;
}

fn vtableRemap(
    ctx: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) ?[*]u8 {
    if (vtableResize(ctx, memory, alignment, new_len, ret_addr)) return memory.ptr;
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
