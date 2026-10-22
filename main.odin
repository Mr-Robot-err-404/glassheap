package main

import "base:intrinsics"

UART :: uintptr(0x10000000)

put_char :: proc "c" (c: u8) {
	intrinsics.volatile_store(cast(^u8)UART, c)
}

@(export)
kmain :: proc "c" () {
	put_char('h')
	put_char('i')
	put_char('\n')
}
