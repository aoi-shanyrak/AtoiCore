const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    const args = try init.minimal.args.toSlice(alloc);
    if (args.len < 4 or args.len > 5) {
        std.debug.print("Usage: mkimage <payload> <output> <size_bytes> [offset_bytes]\n", .{});
        std.process.exit(1);
    }

    const payload_path = args[1];
    const output_path = args[2];
    const img_size = try std.fmt.parseInt(u64, args[3], 10);
    const offset = if (args.len == 5) try std.fmt.parseInt(u64, args[4], 10) else 0;

    if (offset > img_size) return error.OffsetExceedsImageSize;

    const max_payload = img_size - offset;
    const payload_data = try std.Io.Dir.cwd().readFileAlloc(init.io, payload_path, alloc, .limited(max_payload));

    const out_file = try std.Io.Dir.cwd().createFile(init.io, output_path, .{});
    defer out_file.close(init.io);

    try out_file.setLength(init.io, img_size);
    try out_file.writePositionalAll(init.io, payload_data, offset);
}
