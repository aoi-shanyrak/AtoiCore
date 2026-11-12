const std = @import("std");
const mem = @import("mem.zig");

pub const VGA_COLUMNS = 80;
pub const VGA_ROWS = 25;

const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);
const DEFAULT_ATTR: u8 = 0x07;

fn cellOffset(x: usize, y: usize) usize {
    return y * VGA_COLUMNS + x;
}

fn makeEntry(c: u8, attr: u8) u16 {
    return @as(u16, attr) << 8 | c;
}

pub fn clearScreen() void {
    @memset(VGA_BUFFER[0 .. VGA_COLUMNS * VGA_ROWS], makeEntry(' ', DEFAULT_ATTR));
}

pub fn printChar(c: u8, x: usize, y: usize) void {
    if (x >= VGA_COLUMNS or y >= VGA_ROWS) return;
    VGA_BUFFER[cellOffset(x, y)] = makeEntry(c, DEFAULT_ATTR);
}

pub fn scrollDown() void {
    var y: usize = 1;
    while (y < VGA_ROWS) : (y += 1) {
        _ = mem.memcpy( //
            @ptrCast(@volatileCast(&VGA_BUFFER[cellOffset(0, y - 1)])), //
            @ptrCast(@volatileCast(&VGA_BUFFER[cellOffset(0, y)])), //
            VGA_COLUMNS * @sizeOf(u16) //
        );
    }
    var x: usize = 0;
    while (x < VGA_COLUMNS) : (x += 1) {
        VGA_BUFFER[cellOffset(x, VGA_ROWS - 1)] = makeEntry(' ', DEFAULT_ATTR);
    }
}
