[BITS 32]

section .text


[GLOBAL memcpy]
memcpy:
    push edi
    push si

    mov edi, [esp + 12]  
    mov esi, [esp + 16]  
    mov ecx, [esp + 20]  
    rep movsb                
    mov eax, edi         
    
    pop esi
    pop edi
    ret


[GLOBAL memmove]
memmove:
    push edi
    push esi

    mov edi, dword [esp + 12]
    mov esi, dword [esp + 16]
    mov ecx, dword [esp + 20]
    mov eax, edi

    cmp edi, esi
    ja .reverse
    je .done

    rep movsb
    jmp .done

.reverse:
    lea edi, [edi + ecx - 1]
    lea esi, [esi + ecx - 1]

    std
    rep movsb
    cld
.done:
    pop esi
    pop edi
    ret


[GLOBAL memset]
memset:
    push edi
    
    mov edi, [esp + 8]   
    mov al,  [esp + 12]  
    mov ecx, [esp + 16]  
    rep stosb                
    mov eax, edi         

    pop edi
    ret


[GLOBAL memzero]
memzero:
    push dword 0
    push dword [esp + 8]
    push dword [esp + 12]
    call memset
    add  esp, 12
    ret


[GLOBAL memcmp]
memcmp:
    push edi
    push esi

    mov esi, [esp + 12]     
    mov edi, [esp + 16]     
    mov ecx, [esp + 20]     

    test ecx, ecx
    jz .equal

.loop:
    movzx eax, byte [esi]   
    movzx edx, byte [edi]   
    cmp eax, edx
    jne .diff
    inc esi
    inc edi
    dec ecx
    jnz .loop

.equal:
    xor eax, eax
    jmp .done

.diff:
    sub eax, edx       
.done:
    pop esi
    pop edi
    ret

