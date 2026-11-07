package main

import "core:bufio"
import "core:fmt"

ELF_HEADER :: enum i32 {
	ENTRY     = 24,
	PHOFF     = 32,
	PHNUM     = 56,
	SHOFF     = 0x28,
	SHENTSIZE = 0x3a,
	SHNUM     = 0x3c,
}

PROGRAM_HEADER :: enum i32 {
	TYPE   = 0,
	OFFSET = 8,
	VADDR  = 16,
	FILESZ = 32,
}

SECTION_HEADER :: enum i32 {
	TYPE    = 4,
	OFFSET  = 24,
	SIZE    = 32,
	LINK    = 40,
	ENTSIZE = 56,
}

Header :: struct {
	Entry:     u64,
	Phoff:     u64,
	Phnum:     u16,
	Shoff:     u64,
	Shentsize: u16,
	Shnum:     u16,
}

PLoad :: struct {
	Offset: u64,
	Vaddr:  u64,
	Filesz: u64,
}

load_sections :: proc(header: Header, data: []byte) {
	symtab_off, symtab_size, entsize: u64
	strtab_idx: u32

	end := header.Shoff + (u64(header.Shentsize) * u64(header.Shnum))
	for i := header.Shoff; i < end; i += u64(header.Shentsize) {
		buf := data[i:i + u64(header.Shentsize)]
		if read(buf, i32(SECTION_HEADER.TYPE), u32) != SHT_SYMTAB {continue}

		symtab_off = read(buf, i32(SECTION_HEADER.OFFSET), u64)
		symtab_size = read(buf, i32(SECTION_HEADER.SIZE), u64)
		entsize = read(buf, i32(SECTION_HEADER.ENTSIZE), u64)
		strtab_idx = read(buf, i32(SECTION_HEADER.LINK), u32)

		fmt.printfln(
			"off=%d size=%d index=%d entsize=%d",
			symtab_off,
			symtab_size,
			strtab_idx,
			entsize,
		)
		break
	}
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
