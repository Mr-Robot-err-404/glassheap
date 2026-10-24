package main

import "core:fmt"
import "core:os"

ELF_Header_Field :: struct {
	offset: i32,
	size:   i32,
}

ENTRY :: ELF_Header_Field{24, 8}
PHOFF :: ELF_Header_Field{32, 8}
PHNUM :: ELF_Header_Field{56, 2}

PROGRAM_TYPE :: ELF_Header_Field{0, 4}
PROGRAM_OFFSET :: ELF_Header_Field{8, 8}
PROGRAM_VADDR :: ELF_Header_Field{16, 8}
PROGRAM_FILESZ :: ELF_Header_Field{32, 8}

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
	header.Entry = read_u64(data, ENTRY.offset, ENTRY.size)
	header.Phoff = read_u64(data, PHOFF.offset, PHOFF.size)
	header.Phnum = read_u16(data, PHNUM.offset, PHNUM.size)

	end := header.Phoff + (56 * u64(header.Phnum))
	for idx := header.Phoff; idx < end; idx += 56 {
		buf := data[idx:idx + 56]
		type := read_u32(buf, PROGRAM_TYPE.offset, PROGRAM_TYPE.size)
		if type != 1 {continue}

		load := PLoad {
			Offset = read_u64(buf, PROGRAM_OFFSET.offset, PROGRAM_OFFSET.size),
			Vaddr  = read_u64(buf, PROGRAM_VADDR.offset, PROGRAM_VADDR.size),
			Filesz = read_u64(buf, PROGRAM_FILESZ.offset, PROGRAM_FILESZ.size),
		}
		fmt.printf(
			"offset -> 0x%x || address -> 0x%x || bytes -> 0x%x\n",
			load.Offset,
			load.Vaddr,
			load.Filesz,
		)
	}
}

read_u16 :: proc(source: []byte, offset: i32, size: i32) -> u16 {
	buf := make([]byte, size)
	defer delete(buf)

	for i in 0 ..< size {
		buf[i] = source[i + offset]
	}
	return (cast(^u16)raw_data(buf))^
}

read_u32 :: proc(source: []byte, offset: i32, size: i32) -> u32 {
	buf := make([]byte, size)
	defer delete(buf)

	for i in 0 ..< size {
		buf[i] = source[i + offset]
	}
	return (cast(^u32)raw_data(buf))^
}

read_u64 :: proc(source: []byte, offset: i32, size: i32) -> u64 {
	buf := make([]byte, size)
	defer delete(buf)

	for i in 0 ..< size {
		buf[i] = source[i + offset]
	}
	return (cast(^u64)raw_data(buf))^
}
