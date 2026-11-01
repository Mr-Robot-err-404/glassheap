package guest

import "base:intrinsics"

UART :: uintptr(0x10000000)
SYSCON :: uintptr(0x100000)

@(export)
kmain :: proc "c" () {
	n: int = 5
	for i := 1; i <= n; i += 1 {
		put_char('0' + u8(i))
	}
	put_char('\n')

	sum := add_up(n)
	put_number(sum)
	put_char('\n')

	poweroff()
}

add_up :: proc "c" (n: int) -> int {
	total := 0
	for i := 1; i <= n; i += 1 {
		total += i
	}
	return total
}

// NOTE: this is cool
put_number :: proc "c" (n: int) {
	if n >= 10 {
		put_number(n / 10)
	}
	put_char('0' + u8(n % 10))
}

poweroff :: proc "c" () {
	intrinsics.volatile_store(cast(^u32)SYSCON, 0x5555)
}

put_char :: proc "c" (c: u8) {
	intrinsics.volatile_store(cast(^u8)UART, c)
}
