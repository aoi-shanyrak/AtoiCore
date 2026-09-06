[BITS 16]
[ORG 0x7C00]


%ifndef SECTOR_COUNT
    %define SECTOR_COUNT 4
%endif
%define SECTOR_SIZE      512
%define SECTOR_PER_TRACK 18
%define HEAD_COUNT       2
%define KERNEL_OFFSET    0x7E00
%define CODE_OFFSET      0x7C00


start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, CODE_OFFSET
    sti

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
    jmp hello

end:
    jmp $


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



 ; side fuctions and constants

hello:
    mov  si, hello_msg
    call     print_string
    jmp      $


disk_error:
    mov  si, disk_error_msg
    call     print_string
    jmp      end

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

