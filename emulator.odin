package main

import "core:fmt"
import "core:os"
import "core:strings"

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

OPCODE :: enum u32 {
	LUI     = 0x37,
	AUIPC   = 0x17,
	ADDI    = 0x13,
	UNKNOWN = 0x00,
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
	rd:  u32,
	imm: u32,
}
TypeI :: struct {
	rd:     u32,
	funct3: u32,
	rs1:    u32,
	imm:    u32,
}

Decoded :: struct {
	mnemonic: string,
	name:     string,
	imm:      i64,
	pc:       u64,
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
	b := strings.Builder{}
	strings.builder_init(&b)
	defer strings.builder_destroy(&b)

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
			trace(&b, cpu.pc, ins)
			decoded := decode_32_bit(ins, &cpu)
			trace(&b, decoded.mnemonic)
			trace(&b, decoded.name, decoded.imm)
			trace(&b, decoded.pc)
			flush(&b)

			cpu.pc += 4
		}
	}
}

decode_32_bit :: proc(ins: u32, cpu: ^Cpu) -> Decoded {
	opcode := OPCODE(ins & 0x7F)

	switch opcode {
	case .LUI:
		return Decoded{}

	case .AUIPC:
		decoded := parse_type_u(ins)
		address := cpu.pc + u64(sign_extend(decoded.imm << 12, 20))
		cpu.registers[decoded.rd] = address
		return Decoded {
			pc       = address,
			mnemonic = "auipc",
			name     = RegisterName[decoded.rd],
			imm      = i64(decoded.imm),
		}

	case .ADDI:
		decoded := parse_type_i(ins)
		imm := sign_extend(decoded.imm, 12)
		cpu.registers[decoded.rd] = cpu.registers[decoded.rs1] + u64(imm)
		return Decoded{mnemonic = "addi", name = RegisterName[decoded.rd], imm = imm}

	case .UNKNOWN:
		return Decoded{}
	}
	return Decoded{}
}

sign_extend :: proc(n: u32, bits: u32) -> i64 {
	shift := u32(64 - bits)
	return i64(u64(n) << shift) >> shift
}

parse_type_i :: proc(ins: u32) -> TypeI {
	return TypeI {
		rd     = (ins >> TYPE_I_RD_SHIFT) & MASK_5BIT,
		funct3 = (ins >> TYPE_I_FUNCT3_SHIFT) & MASK_3BIT,
		rs1    = (ins >> TYPE_I_RS1_SHIFT) & MASK_5BIT,
		imm    = (ins >> TYPE_I_IMM_SHIFT) & MASK_12BIT,
	}
}

parse_type_u :: proc(ins: u32) -> TypeU {
	return TypeU {
		rd  = (ins >> TYPE_U_RD_SHIFT) & MASK_5BIT,
		imm = (ins >> TYPE_U_IMM_SHIFT) & MASK_20BIT,
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

trace :: proc {
	trace_32_start,
	trace_16,
	trace_register,
	trace_mnemonic,
	trace_comment,
}
trace_32_start :: proc(b: ^strings.Builder, pc: u64, ins: u32) {
	strings.write_string(b, fmt.tprintf("0x%08x:  %08x", pc, ins))
}
trace_mnemonic :: proc(b: ^strings.Builder, name: string) {
	strings.write_string(b, fmt.tprintf("          %-24s", name))
}
trace_register :: proc(b: ^strings.Builder, name: string, n: i64) {
	if len(name) == 0 {return}
	strings.write_string(b, fmt.tprintf("%-23s", fmt.tprintf("%s,%d", name, n)))
}
trace_comment :: proc(b: ^strings.Builder, result: u64) {
	if result == 0 {return}
	strings.write_string(b, fmt.tprintf(" # 0x%08x", result))
}
trace_16 :: proc(b: ^strings.Builder, pc: u64, ins: u16) {
	strings.write_string(b, fmt.tprintf("0x%08x:  %04x", pc, ins))
}
flush :: proc(b: ^strings.Builder) {
	fmt.println(strings.to_string(b^))
	strings.builder_reset(b)
}
