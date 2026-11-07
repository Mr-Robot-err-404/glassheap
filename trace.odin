package main

import "core:fmt"
import "core:strings"

cpu_dump :: proc(b: ^strings.Builder, registers: [32]u64) {
	strings.write_string(b, "\n")

	for i in 0 ..< 8 {
		for j in 0 ..< 4 {
			idx := (i * 4) + j
			name := fmt.tprintf(" %-8s", fmt.tprintf("x%d/%s", idx, RegisterName[idx]))
			entry := fmt.tprintf("%s %16x", name, registers[idx])
			strings.write_string(b, entry)
		}
		strings.write_string(b, "\n")
	}
}

trace_symbol :: proc(b: ^strings.Builder, name: string) {
	strings.write_string(b, "------------------------------------------\n")
	strings.write_string(b, fmt.tprintf("IN: %s\n", name))
}

trace :: proc {
	trace_32_start,
	trace_16,
	trace_registers,
	trace_mnemonic,
	trace_comment,
}
trace_32_start :: proc(b: ^strings.Builder, pc: u64, ins: u32) {
	strings.write_string(b, fmt.tprintf("0x%08x:  %08x", pc, ins))
}
trace_mnemonic :: proc(b: ^strings.Builder, name: string) {
	strings.write_string(b, fmt.tprintf("          %-24s", name))
}
trace_registers :: proc(b: ^strings.Builder, names: [3]string, n: i64) {
	if len(names[0]) == 0 {return}
	s := names[0]
	for i in 1 ..< 3 {
		name := names[i]
		if len(name) == 0 {break}
		s = fmt.tprintf("%s,%s", s, name)
	}
	if n == 0 {
		strings.write_string(b, fmt.tprintf("%-23s", s))
		return
	}
	strings.write_string(b, fmt.tprintf("%-23s", fmt.tprintf("%s,%d", s, n)))
}
trace_comment :: proc(b: ^strings.Builder, result: u64) {
	if result == 0 {return}
	strings.write_string(b, fmt.tprintf(" # 0x%08x", result))
}
trace_16 :: proc(b: ^strings.Builder, pc: u64, ins: u16) {
	strings.write_string(b, fmt.tprintf("0x%08x:  %04x    ", pc, ins))
}
flush :: proc(b: ^strings.Builder) {
	fmt.println(strings.to_string(b^))
	strings.builder_reset(b)
}
