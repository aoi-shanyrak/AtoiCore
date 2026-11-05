%include "defs.inc"

bits 32

section .text

extern universal_handler

global collect_ctx
global collect_ctx_noerr


collect_ctx_noerr:
    push dword [esp]
    mov  dword [esp + 4], 0

collect_ctx:
    push ds
    push es
    push fs
    push gs
    pusha

    mov ax, KERNEL_DATA_SEGMENT
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov  eax, esp
    and  esp, 0xFFFFFFF0
    sub  esp, 12
    push eax
    call universal_handler
    pop  esp

    popa
    pop gs
    pop fs
    pop es
    pop ds

    add esp, 8
    iret

