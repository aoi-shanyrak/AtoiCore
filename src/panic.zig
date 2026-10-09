const std = @import("std");
const printer = @import("printer.zig");
const interrupts = @import("interrupts.zig");

pub extern fn endless_loop() noreturn;

pub fn halt() noreturn {
    interrupts.disableInterrupts();
    endless_loop();
}

pub fn vpanic(fmt: [*:0]const u8, args: *std.builtin.VaList) callconv(.c) noreturn {
    interrupts.disableInterrupts();
    printer.printf("panic at core!: ");
    printer.vprintf(fmt, args);
    endless_loop();
}

pub fn panic(fmt: [*:0]const u8, ...) callconv(.c) noreturn {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);
    vpanic(fmt, &ap);
}
