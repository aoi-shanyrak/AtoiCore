const std = @import("std");
const arena = @import("alloc.zig");
const printer = @import("printer.zig");
const panic_mod = @import("panic.zig");
const interrupts = @import("interrupts.zig");

pub const panic = std.debug.FullPanic(panicImpl);

fn panicImpl(msg: []const u8, first_trace_addr: ?usize) noreturn {
    panic_mod.zigPanic(msg, first_trace_addr);
}

extern fn endless_loop() noreturn;

export fn kernelEntry() callconv(.c) noreturn {
    var kernel_arena: arena.Arena = undefined;
    kernel_arena.init();
    const alloc = kernel_arena.allocator();

    printer.initPrinter();
    const writer = printer.getWriter();

    interrupts.setup(alloc) catch unreachable;
    writer.writeAll("idt loaded") catch {};

    test_exception();
    //test_int();
    //test_hardware();

    endless_loop();
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

fn test_int() noreturn {
    const asm_code = comptime std.fmt.comptimePrint(
        \\.intel_syntax noprefix
        \\mov eax, 0x{x}
        \\mov ebx, 0x{x}
        \\mov ecx, 0x{x}
        \\mov edx, 0x{x}
        \\int 167      
        \\.att_syntax prefix
    , .{ test_pattern.eax, test_pattern.ebx, test_pattern.ecx, test_pattern.edx });

    asm volatile (asm_code);
    unreachable;
}

fn test_hardware() noreturn {
    const asm_code = comptime std.fmt.comptimePrint(
        \\.intel_syntax noprefix
        \\mov eax, 0x{x}
        \\mov ebx, 0x{x}
        \\mov ecx, 0x{x}
        \\mov edx, 0x{x}
        \\sti
        \\1: hlt
        \\jmp 1b
        \\.att_syntax prefix
    , .{ test_pattern.eax, test_pattern.ebx, test_pattern.ecx, test_pattern.edx });

    asm volatile (asm_code);
    unreachable;
}
