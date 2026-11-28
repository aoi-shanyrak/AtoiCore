const std = @import("std");
const @"asm" = @import("asm.zig");
const config = @import("config.zig");

pub fn buildKernel(ctx: config.Context) *std.Build.Step.Compile {
    const kernel_mod = createKernelModules(ctx);
    const os_elf = ctx.b.addExecutable(.{
        .name = config.kernel_elf_name,
        .root_module = kernel_mod,
    });
    os_elf.entry = .disabled;
    os_elf.setLinkerScript(ctx.b.path(config.linker_script));
    @"asm".addAssemblyObjects(ctx.b, os_elf);
    return os_elf;
}

fn createKernelModules(ctx: config.Context) *std.Build.Module {
    const io_mod = module(ctx, "src/interrupts/io.zig", &.{});
    const panic_mod = module(ctx, "src/kernel/panic.zig", &.{});

    const int_mod = module(ctx, "src/interrupts/interrupts.zig", &.{
        .{ .name = "panic", .module = panic_mod },
        .{ .name = "io", .module = io_mod },
    });

    const drivers_mod = module(ctx, "src/drivers/drivers.zig", &.{
        .{ .name = "io", .module = io_mod },
        .{ .name = "interrupts", .module = int_mod },
    });

    const print_mod = module(ctx, "src/kernel/printer.zig", &.{
        .{ .name = "drivers", .module = drivers_mod },
    });

    const exp_mod = module(ctx, "src/kernel/experiments.zig", &.{
        .{ .name = "printer", .module = print_mod },
        .{ .name = "drivers", .module = drivers_mod },
        .{ .name = "interrupts", .module = int_mod },
    });

    return module(ctx, "src/kernel/main.zig", &.{
        .{ .name = "panic", .module = panic_mod },
        .{ .name = "printer", .module = print_mod },
        .{ .name = "drivers", .module = drivers_mod },
        .{ .name = "interrupts", .module = int_mod },
        .{ .name = "experiments", .module = exp_mod },
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
        .strip = ctx.strip,
        .imports = imports,
    });
}
