const printer = @import("printer.zig");

extern fn endless_loop() noreturn;

export fn kernelEntry() callconv(.c) noreturn {
    printer.initPrinter();

    printer.printf("it just works.");

    endless_loop();
}
