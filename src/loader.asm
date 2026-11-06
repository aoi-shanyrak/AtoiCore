%include "defs.inc"

bits 16

section .boot

extern __kernel_end

global endless_loop


start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, CODE_OFFSET

    mov eax, __kernel_end    
    sub eax, KERNEL_OFFSET
    add eax, SECTOR_SIZE - 1
    shr eax, 9               
    mov si, ax

    mov cl, 2
    mov ch, 0
    mov dh, 0
    mov bx, KERNEL_OFFSET

read_loop:
    cmp si, 0
    je read_done

    mov ax, 0x0201
    int 0x13
    jc disk_error

    dec si
    add bx, SECTOR_SIZE
    jnc no_segment_update
        push ax
        mov ax, es
        add ax, 0x1000
        mov es, ax
        pop ax
    no_segment_update:

    call next_sector
    jmp read_loop

next_sector:
    inc cl
    cmp cl, SECTOR_PER_TRACK + 1
    jne .done
    mov cl, 1

    inc dh
    cmp dh, HEAD_COUNT
    jne .done
    mov dh, 0

    inc ch
.done:
    ret


read_done:
    lgdt [gdt_descriptor]
    cld
    mov  eax, CR0
    or   eax, 1
    mov  CR0, eax
    jmp KERNEL_CODE_SEGMENT:next
bits 32
next:
    mov ax, KERNEL_DATA_SEGMENT
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

extern kernelEntry
    call kernelEntry


bits 16

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

align 8
gdt_start:
    .null: dq 0
    code:
        .limitL:            dw 0xFFFF
        .baseL:             dw 0
        .baseM:             db 0
        .P_DPL_S_type:      db 0b10011010
        .G_DB_L_AVL_limitH: db 0b11001111
        .baseH:             db 0
    data:
        .limitL:            dw 0xFFFF
        .baseL:             dw 0
        .baseM:             db 0
        .P_DPL_S_type:      db 0b10010010
        .G_DB_L_AVL_limitH: db 0b11001111
        .baseH:             db 0
gdt_end:


disk_error:
    mov  si, disk_error_msg
    call     print_string


endless_loop:
    jmp $


print_string:
    lodsb
    test  al, al
    jz    .done
    mov   ah, 0x0E
    int   0x10
    jmp   print_string
.done:
    ret


disk_error_msg:
    db 'Disk read error!', 0x0A, 0x0D, 0


times 510-($-$$) db 0
dw 0xAA55

