extern const __kernel_end: u8;

const KERNEL_END: usize = @intFromPtr(&__kernel_end);
const ARENA0_START: usize = KERNEL_END;
const ARENA0_END: usize = 0xA0000;

extern fn endless_loop() noreturn;

export fn kernel_entry() callconv(.c) noreturn {
    const vga_buffer: [*]volatile u16 = @ptrFromInt(0xB8000);

    vga_buffer[0] = 0;

    endless_loop();
}
