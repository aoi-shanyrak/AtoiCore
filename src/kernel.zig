extern fn endless_loop() noreturn;

export fn kernel_entry() callconv(.c) noreturn {
    const vga_buffer: [*]volatile u16 = @ptrFromInt(0xB8000);

    vga_buffer[0] = 0;

    endless_loop();
}
