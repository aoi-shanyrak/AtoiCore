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
    var kernel_arena: arena.Arena = undefined;
    kernel_arena.init();

    printer.initPrinter();

    const alloc = kernel_arena.allocator();
    const writer = printer.getWriter();

    {
        writer.print("\n[2] StringHashMap OOM test\n", .{}) catch {};
        var map = std.StringHashMap(u32).init(alloc);

        var i: u32 = 0;
        while (true) : (i += 1) {
            const key = std.fmt.allocPrint(alloc, "key_{d}", .{i}) catch unreachable;

            map.put(key, i) catch unreachable;

            if (i % 10 == 0) {
                writer.print("iter: {d}, map count: {d}\n", .{ i, map.count() }) catch {};
            }
        }
    }

    endless_loop();
}
