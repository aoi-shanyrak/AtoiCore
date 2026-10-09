pub fn enableInterrupts() void {
    asm volatile ("sti");
}

pub fn disableInterrupts() void {
    asm volatile ("cli");
}
