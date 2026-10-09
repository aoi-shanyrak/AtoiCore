extern const __kernel_end: u8;

const KERNEL_END: usize = @intFromPtr(&__kernel_end);
const ARENA_START: usize = KERNEL_END;
const ARENA_END: usize = 0xA0000;
