const std = @import("std");
const kpanic = @import("panic");
const drivers = @import("drivers");
const printer = @import("printer.zig");
const interrupts = @import("interrupts");

const allocator_undead = @import("arena.zig");

pub const panic = std.debug.FullPanic(kpanic.zigPanic);

export fn kernelEntry() callconv(.c) noreturn {
    const alloc = kernelSetup();
    _ = main(alloc);
    kpanic.halt();
}

fn kernelSetup() std.mem.Allocator {
    var kernel_arena: allocator_undead.Arena = undefined;
    kernel_arena.init();
    const alloc = kernel_arena.allocator();

    printer.initPrinter();
    kpanic.setWriter(printer.getWriter());

    interrupts.setup(alloc) catch unreachable;

    drivers.pit.init(100) catch unreachable;

    return alloc;
}

fn main(_: std.mem.Allocator) i32 {
    test_exception();
    return 0;
}

const test_pattern = struct {
    const eax = 0x00000001;
    const ebx = 0x00000002;
    const ecx = 0x00000003;
    const edx = 0x00000004;
};

fn test_exception() noreturn {
    const asm_code = comptime std.fmt.comptimePrint(
        \\.intel_syntax noprefix
        \\mov eax, 0x{x}
        \\mov ebx, 0x{x}
        \\mov ecx, 0x{x}
        \\mov edx, 0x{x}
        \\xor ecx, ecx      
        \\div ecx           
        \\.att_syntax prefix
    , .{ test_pattern.eax, test_pattern.ebx, test_pattern.ecx, test_pattern.edx });

    asm volatile (asm_code);
    unreachable;
}
