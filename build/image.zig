const std = @import("std");
const config = @import("config.zig");

pub fn addFloppyImage(b: *std.Build, payload: std.Build.LazyPath) std.Build.LazyPath {
    const mkimage_exe = b.addExecutable(.{
        .name = "mkimage",
        .root_module = b.createModule(.{
            .root_source_file = b.path(config.mkimage_src),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });
    const run = b.addRunArtifact(mkimage_exe);
    run.addFileArg(payload);
    const out_img = run.addOutputFileArg(config.img_name);
    run.addArg(b.fmt("{d}", .{config.image_size}));

    return out_img;
}
