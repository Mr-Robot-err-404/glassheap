ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 4M
}

SECTIONS {
    . = 0x80000000;
    .text : { *(.text.boot) *(.text*) } > RAM
    .rodata : { *(.rodata*) } > RAM
    .data : { *(.data*) } > RAM
    .bss : { *(.bss*) } > RAM
    . = ALIGN(16);
    _stack_top = . + 0x10000;
}
