const std = @import("std");
const idt = @import("idt.zig");
const pic = @import("pic.zig");
const panic = @import("panic");

const Context = @import("context.zig").Context;
const InterruptVector = @import("interruptVector.zig").InterruptVector;

pub const HandlerFn = *const fn (ctx: *Context) void;

pub const HandlerTable = struct {
    entries: [idt.NUM_VECTORS]?HandlerFn,

    pub fn init(allocator: std.mem.Allocator) !*HandlerTable {
        const self = try allocator.create(HandlerTable);
        @memset(&self.entries, null);
        return self;
    }

    pub fn register(self: *HandlerTable, vec: InterruptVector, handler: HandlerFn) void {
        self.entries[@backingInt(vec)] = handler;
    }

    pub fn unregister(self: *HandlerTable, vec: InterruptVector) void {
        self.entries[@backingInt(vec)] = null;
    }

    pub fn get(self: *HandlerTable, vec: InterruptVector) ?HandlerFn {
        return self.entries[@backingInt(vec)];
    }
};

var table: ?*HandlerTable = null;

pub fn init(alloc: std.mem.Allocator) !void {
    table = try HandlerTable.init(alloc);
}

pub fn register(vec: InterruptVector, handler: HandlerFn) void {
    if (table) |t| {
        t.register(vec, handler);
    }
}

pub fn unregister(vec: InterruptVector) void {
    if (table) |t| {
        t.unregister(vec);
    }
}

export fn universal_handler(ctx: *Context) callconv(.c) void {
    const vec: u8 = @truncate(ctx.vector);
    const vector: InterruptVector = @fromBackingInt(@intCast(vec));

    if (table) |t| {
        if (t.get(vector)) |handler| {
            handler(ctx);
            if (vector.toPicIrq()) |irq| {
                pic.sendEOI(@backingInt(irq));
            }
            return;
        }
    }

    if (panic.beginPanic()) |w| {
        const int_name = vector.mnemonic() orelse "ERR";

        w.print(
            \\unhandled interrupt {s} at 0x{x:0>4}:0x{x:0>8}
            \\
            \\{f}
        , .{
            int_name,
            ctx.cs,
            ctx.eip,
            ctx.*,
        }) catch {};
    }
    panic.halt();
}
