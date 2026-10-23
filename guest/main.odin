package guest

import "base:intrinsics"

UART :: uintptr(0x10000000)
SYSCON :: uintptr(0x100000)

@(export)
kmain :: proc "c" () {
	put_char('h')
	put_char('i')
	put_char('\n')
	poweroff()
}

poweroff :: proc "c" () {
	intrinsics.volatile_store(cast(^u32)SYSCON, 0x5555)
}

put_char :: proc "c" (c: u8) {
	intrinsics.volatile_store(cast(^u8)UART, c)
}
