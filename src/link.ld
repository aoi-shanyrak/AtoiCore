ENTRY(start)

SECTIONS
{
    . = 0x7C00;

    .boot : { *(.boot) }

    . = 0x7E00;

    .text   : { *(.text) *(.text.*) }
    .rodata : { *(.rodata) *(.rodata.*) }
    .data   : { *(.data)   *(.data.*)   }
    .bss    : { *(.bss)    *(COMMON)    }

    . = ALIGN(16);
    __kernel_end = .;                

    /DISCARD/ : {
    *(.eh_frame)
    *(.eh_frame_hdr)
    *(.eh_frame.*)
    *(.comment)
    *(.note.*)
    *(.note.GNU-stack)
    *(.rel.eh_frame)
    *(.rela.eh_frame)
    *(.rel.eh_frame_hdr)
    *(.rela.eh_frame_hdr)
    }
}