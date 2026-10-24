package main

import "core:fmt"
import "core:os"

RAM_SIZE :: 4 * 1024 * 1024 // 4MB
RAM_OFFSET :: 0x80000000

Header_Field :: struct {
	offset: i32,
	size:   i32,
}

ENTRY :: Header_Field{24, 8}
PHOFF :: Header_Field{32, 8}
PHNUM :: Header_Field{56, 2}

PROGRAM_TYPE :: Header_Field{0, 4}
PROGRAM_OFFSET :: Header_Field{8, 8}
PROGRAM_VADDR :: Header_Field{16, 8}
PROGRAM_FILESZ :: Header_Field{32, 8}

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


main :: proc() {
	data, err := os.read_entire_file("build/glassheap.elf", context.allocator)
	if err != nil {
		fmt.panicf("failed to read elf: %w", err)
	}
	header: Header
	header.Entry = read(data, ENTRY.offset, ENTRY.size, u64)
	header.Phoff = read(data, PHOFF.offset, PHOFF.size, u64)
	header.Phnum = read(data, PHNUM.offset, PHNUM.size, u16)

	ram := make([]byte, RAM_SIZE)
	defer delete(ram)

	end := header.Phoff + (56 * u64(header.Phnum))
	for i := header.Phoff; i < end; i += 56 {
		buf := data[i:i + 56]

		type := read(buf, PROGRAM_TYPE.offset, PROGRAM_TYPE.size, u32)
		if type != 1 {continue}

		load := PLoad {
			Offset = read(buf, PROGRAM_OFFSET.offset, PROGRAM_OFFSET.size, u64),
			Vaddr  = read(buf, PROGRAM_VADDR.offset, PROGRAM_VADDR.size, u64),
			Filesz = read(buf, PROGRAM_FILESZ.offset, PROGRAM_FILESZ.size, u64),
		}
		fmt.printf(
			"offset -> 0x%x || address -> 0x%x || bytes -> 0x%x\n",
			load.Offset,
			load.Vaddr,
			load.Filesz,
		)
		idx := load.Vaddr - RAM_OFFSET
		copy(ram[idx:idx + load.Filesz], data[load.Offset:load.Offset + load.Filesz])
	}
}

read :: proc(source: []byte, offset: i32, size: i32, $T: typeid) -> T {
	buf := source[offset:offset + size]
	return (cast(^T)raw_data(buf))^
}
