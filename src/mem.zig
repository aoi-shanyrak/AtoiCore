pub extern fn memcpy(dst: [*]u8, src: [*]const u8, n: usize) callconv(.c) [*]u8;
pub extern fn memmove(dst: [*]u8, src: [*]const u8, n: usize) callconv(.c) [*]u8;
pub extern fn memset(dst: [*]u8, c: c_int, n: usize) callconv(.c) [*]u8;
pub extern fn memzero(dst: [*]u8, n: usize) callconv(.c) [*]u8;
pub extern fn memcmp(a: [*]const u8, b: [*]const u8, n: usize) callconv(.c) c_int;
