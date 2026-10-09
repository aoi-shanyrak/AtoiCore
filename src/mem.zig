pub extern "c" fn memcpy(dst: [*]u8, src: [*]const u8, n: usize) [*]u8;
pub extern "c" fn memmove(dst: [*]u8, src: [*]const u8, n: usize) [*]u8;
pub extern "c" fn memset(dst: [*]u8, c: c_int, n: usize) [*]u8;
pub extern "c" fn memzero(dst: [*]u8, n: usize) [*]u8;
pub extern "c" fn memcmp(a: [*]const u8, b: [*]const u8, n: usize) c_int;
