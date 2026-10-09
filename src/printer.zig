const std = @import("std");
const vga = @import("vga.zig");

const TOP: usize = 0;
const BOTTOM: usize = vga.VGA_ROWS - 1;
const LEFT: usize = 0;
const RIGHT: usize = vga.VGA_COLUMNS - 1;

const VgaWriter = struct {
    interface: std.Io.Writer,
    cursor: Cursor = .{},

    const Cursor = struct { x: usize = 0, y: usize = 0 };

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *VgaWriter = @alignCast(@fieldParentPtr("interface", w));

        var total_written: usize = 0;

        for (data[0 .. data.len - 1]) |slice| {
            for (slice) |b| self.putchar(b);
            total_written += slice.len;
        }
        const last_slice = data[data.len - 1];
        for (0..splat) |_| {
            for (last_slice) |b| self.putchar(b);
            total_written += last_slice.len;
        }
        return total_written;
    }

    fn putchar(self: *VgaWriter, c: u8) void {
        switch (c) {
            '\n' => self.newline(),
            '\r' => self.cursor.x = LEFT,
            else => {
                vga.printChar(c, self.cursor.x, self.cursor.y);
                self.cursor.x += 1;
                if (self.cursor.x > RIGHT) self.newline();
            },
        }
    }

    fn newline(self: *VgaWriter) void {
        self.cursor.x = 0;
        self.cursor.y += 1;
        if (self.cursor.y > BOTTOM) {
            vga.scrollDown();
            self.cursor.y = BOTTOM;
        }
    }
};

var vga_writer = VgaWriter{
    .interface = .{ .buffer = &.{}, .vtable = &.{ .drain = &VgaWriter.drain } },
};

pub fn initPrinter() void {
    vga.clearScreen();
    vga_writer.cursor = .{};
}

pub fn getWriter() *std.Io.Writer {
    return &vga_writer.interface;
}

pub fn vprintf(fmt: [*:0]const u8, args: *std.builtin.VaList) callconv(.c) void {
    const w = getWriter();
    var i: usize = 0;
    while (fmt[i] != 0) : (i += 1) {
        if (fmt[i] != '%') {
            w.writeByte(fmt[i]) catch {};
            continue;
        }
        i += 1;
        switch (fmt[i]) {
            'd' => w.print("{d}", .{@cVaArg(args, c_int)}) catch {},
            'u' => w.print("{d}", .{@cVaArg(args, c_uint)}) catch {},
            'x' => w.print("{x}", .{@cVaArg(args, c_uint)}) catch {},
            'c' => w.writeByte(@intCast(@cVaArg(args, c_int))) catch {},
            's' => {
                const s = std.mem.span(@cVaArg(args, [*:0]const u8));
                w.writeAll(s) catch {};
            },
            '%' => w.writeByte('%') catch {},
            else => {
                w.writeByte('%') catch {};
                w.writeByte(fmt[i]) catch {};
            },
        }
    }
}

pub fn printf(fmt: [*:0]const u8, ...) callconv(.c) void {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);
    vprintf(fmt, &ap);
}
