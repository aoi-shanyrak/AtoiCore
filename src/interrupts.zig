const Context = extern struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    gs: u32,
    fs: u32,
    es: u32,
    ds: u32,

    vector: u32,
    error_code: u32,

    eip: u32,
    cs: u32,
    eflags: u32,
};

pub fn enableInterrupts() void {
    asm volatile ("sti");
}

pub fn disableInterrupts() void {
    asm volatile ("cli");
}
