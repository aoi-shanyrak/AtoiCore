%ifndef SECTOR_COUNT
    %define SECTOR_COUNT 4
%endif
%define SECTOR_SIZE      512
%define SECTOR_PER_TRACK 18
%define HEAD_COUNT       2
%define KERNEL_OFFSET    0x7E00
%define CODE_OFFSET      0x7C00

%define CODE 0x08 
%define DATA 0x10


[section .boot]


; BOOTLOADER [load kernel]

[BITS 16]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, CODE_OFFSET

    mov cl, 2
    mov ch, 0
    mov dh, 0

    mov bx, KERNEL_OFFSET
    mov si, SECTOR_COUNT

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
read_done:


; VBR [go to C]

    lgdt [gdt_descriptor]
    cld
    mov  eax, CR0
    or   eax, 1
    mov  CR0, eax
    jmp CODE:next
[BITS 32]
next:
    mov ax, DATA
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

[EXTERN kernel_entry]
    call CODE:kernel_entry


gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

;                                 P DPL S Type   G D/B L AVL limit
; byte | 0  | 1  | 2  | 3  | 4  |      5       | 6                | 7  
; NULL | 00 | 00 | 00 | 00 | 00 | 0 00  0 0000 | 0  0  0  0  0000 | 00
; CODE | FF | FF | 00 | 00 | 00 | 1 00  1 1010 | 1  1  0  0  1111 | 00
; DATA | FF | FF | 00 | 00 | 00 | 1 00  1 0010 | 1  1  0  0  1111 | 00
gdt_start:
    dq 0x0000000000000000
    db 0xFF, 0xFF, 0x00, 0x00, 0x00, 0b10011010, 0b11001111, 0x00
    db 0xFF, 0xFF, 0x00, 0x00, 0x00, 0b10010010, 0b11001111, 0x00
gdt_end:


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


[GLOBAL endless_loop]
endless_loop:
    jmp $


disk_error:
    mov  si, disk_error_msg
    call     print_string
    jmp      endless_loop

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
hello_msg: 
    db 'Hello, World!', 0x0A, 0x0D, 0


times 510-($-$$) db 0
dw 0xAA55

