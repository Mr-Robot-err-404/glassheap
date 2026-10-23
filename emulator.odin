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


main :: proc() {
	data, err := os.read_entire_file("build/glassheap.elf", context.allocator)
	if err != nil {
		fmt.panicf("failed to read elf: %w", err)
	}
	header: Header
	header.Entry = read_u64(data, ENTRY.offset, ENTRY.size)
	header.Phoff = read_u64(data, PHOFF.offset, PHOFF.size)
	header.Phnum = read_u16(data, PHNUM.offset, PHNUM.size)

	fmt.printf("0x%x\n", header.Entry)
	fmt.printf("%d\n", header.Phoff)
	fmt.printf("%d\n", header.Phnum)
}

read_u16 :: proc(source: []byte, offset: i32, size: i32) -> u16 {
	buf := make([]byte, size)
	defer delete(buf)

	for i in 0 ..< size {
		buf[i] = source[i + offset]
	}
	return (cast(^u16)raw_data(buf))^
}

read_u64 :: proc(source: []byte, offset: i32, size: i32) -> u64 {
	buf := make([]byte, size)
	defer delete(buf)

	for i in 0 ..< size {
		buf[i] = source[i + offset]
	}
	return (cast(^u64)raw_data(buf))^
}
