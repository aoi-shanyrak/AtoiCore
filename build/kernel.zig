const std = @import("std");
const config = @import("config.zig");

pub fn createKernelModules(ctx: config.Context) *std.Build.Module {
    const drivers_mod = module(ctx, "src/drivers/drivers.zig", &.{});
    const panic_mod = module(ctx, "src/kernel/panic.zig", &.{});
    const x86_32_mod = module(ctx, "src/x86_32/x86_32.zig", &.{});

    const memory_mod = module(ctx, "src/memory/memory.zig", &.{
        .{ .name = "x86_32", .module = x86_32_mod },
        .{ .name = "panic", .module = panic_mod },
    });

    return module(ctx, "src/kernel/main.zig", &.{
        .{ .name = "x86_32", .module = x86_32_mod },
        .{ .name = "drivers", .module = drivers_mod },
        .{ .name = "memory", .module = memory_mod },
        .{ .name = "panic", .module = panic_mod },
    });
}

fn module(
    ctx: config.Context,
    root_source: []const u8,
    imports: []const std.Build.Module.Import,
) *std.Build.Module {
    return ctx.b.createModule(.{
        .root_source_file = ctx.b.path(root_source),
        .target = ctx.target,
        .optimize = ctx.optimize,
        .code_model = .kernel,
        .imports = imports,
    });
}

pub fn addKernelElf(b: *std.Build, kernel_mod: *std.Build.Module) *std.Build.Step.Compile {
    const os_elf = b.addExecutable(.{
        .name = config.kernel_elf_name,
        .root_module = kernel_mod,
    });
    os_elf.entry = .disabled;
    os_elf.setLinkerScript(b.path(config.linker_script));
    return os_elf;
}
