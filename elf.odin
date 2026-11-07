package main

import "core:bytes"

ELF_HEADER :: enum i32 {
	ENTRY     = 24,
	PHOFF     = 32,
	PHNUM     = 56,
	SHOFF     = 0x28,
	SHENTSIZE = 0x3a,
	SHNUM     = 0x3c,
	PHENTSIZE = 0x36,
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
SHT_SYMTAB :: 2
SHT_STRTAB :: 3

SYM :: enum i32 {
	NAME  = 0,
	INFO  = 4,
	VALUE = 8,
	SIZE  = 16,
}
STT_FUNC :: 2


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

Func :: struct {
	lo:   u64,
	hi:   u64,
	name: string,
}

load_sections :: proc(header: Header, data: []byte) -> []Func {
	funcs := make([dynamic]Func)

	symtab_off, symtab_size, entsize: u64
	strtab_index: u32
	end := header.Shoff + (u64(header.Shentsize) * u64(header.Shnum))

	for i := header.Shoff; i < end; i += u64(header.Shentsize) {
		buf := data[i:i + u64(header.Shentsize)]
		if read(buf, i32(SECTION_HEADER.TYPE), u32) != SHT_SYMTAB {continue}

		symtab_off = read(buf, i32(SECTION_HEADER.OFFSET), u64)
		symtab_size = read(buf, i32(SECTION_HEADER.SIZE), u64)
		entsize = read(buf, i32(SECTION_HEADER.ENTSIZE), u64)
		strtab_index = read(buf, i32(SECTION_HEADER.LINK), u32)
		break
	}
	idx := header.Shoff + (u64(header.Shentsize) * u64(strtab_index))
	buf := data[idx:idx + u64(header.Shentsize)]
	strtab_off := read(buf, i32(SECTION_HEADER.OFFSET), u64)

	end = symtab_off + symtab_size
	for i := symtab_off; i < end; i += entsize {
		buf := data[i:i + entsize]

		info := read(buf, i32(SYM.INFO), u8)
		if info & 0xf != STT_FUNC {continue}

		name_offset := read(buf, i32(SYM.NAME), u32)
		address := read(buf, i32(SYM.VALUE), u64)
		size := read(buf, i32(SYM.SIZE), u64)

		idx := strtab_off + u64(name_offset)
		str := data[idx:]
		seek := bytes.index_byte(str, 0)
		if seek == -1 {continue}

		append(&funcs, Func {
			lo   = address,
			hi   = address + size,
			name = string(str[:seek]),
		})
	}
	return funcs[:]
}

load_ram :: proc(header: Header, data: []byte, ram: []byte) {
	phent_size := read(data, i32(ELF_HEADER.PHENTSIZE), u16)
	end := header.Phoff + (u64(phent_size) * u64(header.Phnum))

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
