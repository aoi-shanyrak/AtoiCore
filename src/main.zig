const std = @import("std");
const arena = @import("alloc.zig");
const printer = @import("printer.zig");
const panic_mod = @import("panic.zig");

pub const panic = std.debug.FullPanic(panicImpl);

fn panicImpl(msg: []const u8, first_trace_addr: ?usize) noreturn {
    panic_mod.zigPanic(msg, first_trace_addr);
}

extern fn endless_loop() noreturn;

export fn kernelEntry() callconv(.c) noreturn {
    arena.init();
    printer.initPrinter();

    printer.printf("=== arena test ===\n");

    const alloc = arena.allocator();

    {
        printer.printf("\n[2] StringHashMap(u32)\n");
        var map = std.StringHashMap(u32).init(alloc);

        map.put("one", 1) catch unreachable;
        map.put("two", 2) catch unreachable;
        map.put("three", 3) catch unreachable;
        map.put("four", 4) catch unreachable;

        const keys = [_][]const u8{ "one", "two", "three", "four", "five" };
        for (keys) |k| {
            const v = map.get(k) orelse 0;
            printer.printf("  %s -> %u\n", @as([*:0]const u8, @ptrCast(k.ptr)), @as(c_uint, v));
        }

        printer.printf("count = %u\n", @as(c_uint, @intCast(map.count())));

        map.deinit();
    }

    endless_loop();
}
