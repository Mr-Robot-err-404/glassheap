package main

import "core:fmt"
import "core:os"

RAM_SIZE :: 4 * 1024 * 1024 // 4MB
RAM_OFFSET :: 0x80000000

ELF_HEADER :: enum i32 {
	ENTRY = 24,
	PHOFF = 32,
	PHNUM = 56,
}

PROGRAM_HEADER :: enum i32 {
	TYPE   = 0,
	OFFSET = 8,
	VADDR  = 16,
	FILESZ = 32,
}

Segment_Type :: enum u32 {
	PT_NULL    = 0,
	PT_LOAD    = 1,
	PT_DYNAMIC = 2,
	PT_INTERP  = 3,
}

Header :: struct {
	Entry: u64,
	Phoff: u64,
	Phnum: u16,
}

PLoad :: struct {
	Offset: u64,
	Vaddr:  u64,
	Filesz: u64,
}

Cpu :: struct {
	registers: [32]u64,
	pc:        u64,
}

TypeU :: struct {
	rd:     u32,
	imm:    u32,
	opcode: u32,
}

auipc :: proc() {
}

parse_type_u :: proc(ins: u32) -> TypeU {
	return TypeU{}
}

main :: proc() {
	data, err := os.read_entire_file("build/glassheap.elf", context.allocator)
	if err != nil {
		fmt.panicf("failed to read elf: %w", err)
	}
	header: Header
	header.Entry = read(data, i32(ELF_HEADER.ENTRY), u64)
	header.Phoff = read(data, i32(ELF_HEADER.PHOFF), u64)
	header.Phnum = read(data, i32(ELF_HEADER.PHNUM), u16)

	ram := make([]byte, RAM_SIZE)
	defer delete(ram)

	load_ram(header, data, ram)

	cpu := Cpu {
		pc = header.Entry,
	}

	n := 10
	for n > 0 {
		defer n -= 1

		idx := cpu.pc - RAM_OFFSET
		ins := read(ram, i32(idx), u32)

		switch {
		case !is_32_bit(ins):
			fmt.printf("%08x: %04x\n", cpu.pc, u16(ins))
			cpu.pc += 2
		case:
			fmt.printf("%08x: %08x\n", cpu.pc, ins)
			cpu.pc += 4
		}
	}
}

is_32_bit :: proc(ins: u32) -> bool {
	return ins & 0x3 == 0x3
}

load_ram :: proc(header: Header, data: []byte, ram: []byte) {
	end := header.Phoff + (56 * u64(header.Phnum))
	for i := header.Phoff; i < end; i += 56 {
		buf := data[i:i + 56]

		type := read(buf, i32(PROGRAM_HEADER.TYPE), u32)
		if type != 1 {continue}

		load := PLoad {
			Offset = read(buf, i32(PROGRAM_HEADER.OFFSET), u64),
			Vaddr  = read(buf, i32(PROGRAM_HEADER.VADDR), u64),
			Filesz = read(buf, i32(PROGRAM_HEADER.FILESZ), u64),
		}
		idx := load.Vaddr - RAM_OFFSET
		copy(ram[idx:idx + load.Filesz], data[load.Offset:load.Offset + load.Filesz])
	}
}

read :: proc(source: []byte, offset: i32, $T: typeid) -> T {
	end := offset + size_of(T)
	buf := source[offset:end]
	return (cast(^T)raw_data(buf))^
}
