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
	SB      = 0x23,
	JAL     = 0x6f,
	JALR    = 0x67,
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
TypeJ :: struct {
	rd:  u32,
	imm: u32,
}
TypeS :: struct {
	funct3: u32,
	rs1:    u32,
	rs2:    u32,
	imm:    u32,
}


Decoded :: struct {
	mnemonic:  string,
	registers: [3]string,
	imm:       i64,
	address:   u64,
	jump:      bool,
	syscon:    bool,
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

	n := 25
	for n > 0 {
		defer n -= 1

		idx := cpu.pc - RAM_OFFSET
		ins := read(ram, i32(idx), u32)

		switch {
		case !is_32_bit(ins):
			trace(&b, cpu.pc, u16(ins))
			ins = decompress_16_bit(u16(ins))
			decoded := decode_32_bit(ins, &cpu, ram)
			trace(&b, decoded.mnemonic)
			trace(&b, decoded.registers, decoded.imm)
			trace(&b, decoded.address)
			flush(&b)

			if decoded.jump {
				fmt.println("------------------------------------------")
				continue
			}
			if decoded.syscon {
				fmt.println("received syscon")
				os.exit(0)
			}
			cpu.pc += 2
		case:
			trace(&b, cpu.pc, ins)
			decoded := decode_32_bit(ins, &cpu, ram)
			trace(&b, decoded.mnemonic)
			trace(&b, decoded.registers, decoded.imm)
			trace(&b, decoded.address)
			flush(&b)

			if decoded.jump {
				fmt.println("------------------------------------------")
				continue
			}
			if decoded.syscon {
				fmt.println("received syscon")
				os.exit(0)
			}
			cpu.pc += 4
		}
	}
}


decode_32_bit :: proc(ins: u32, cpu: ^Cpu, ram: []byte) -> Decoded {
	opcode := OPCODE(ins & MASK_7BIT)

	switch opcode {
	case .LUI:
		parsed := parse_type_u(ins)
		address := u64(sign_extend(parsed.imm << 12, 32))
		cpu.registers[parsed.rd] = address
		return decoded("lui", RegisterName[parsed.rd], i64(parsed.imm), address)

	case .AUIPC:
		parsed := parse_type_u(ins)
		imm := sign_extend(parsed.imm << 12, 32)
		address := cpu.pc + u64(imm)
		cpu.registers[parsed.rd] = address
		return decoded("auipc", RegisterName[parsed.rd], i64(parsed.imm), address)

	case .ADDI:
		parsed := parse_type_i(ins)
		imm := sign_extend(parsed.imm, 12)
		cpu.registers[parsed.rd] = cpu.registers[parsed.rs1] + u64(imm)
		return decoded("addi", RegisterName[parsed.rd], RegisterName[parsed.rs1], imm)

	case .JAL:
		parsed := parse_type_j(ins)
		imm := sign_extend(parsed.imm, 20)
		cpu.registers[parsed.rd] = cpu.pc + 4
		cpu.pc += u64(imm)
		return decoded("jal", RegisterName[parsed.rd], imm, cpu.pc, true)

	case .JALR:
		parsed := parse_type_i(ins)
		imm := sign_extend(parsed.imm, 12)
		cpu.registers[parsed.rd] = cpu.pc + 4
		cpu.pc = ensure_even(cpu.registers[parsed.rs1] + u64(imm))
		return decoded(
			"jalr",
			RegisterName[parsed.rd],
			RegisterName[parsed.rs1],
			imm,
			cpu.pc,
			true,
		)

	case .SB:
		parsed := parse_type_s(ins)
		funct3 := S_Funct3(parsed.funct3)
		imm := sign_extend(parsed.imm, 12)
		address := cpu.registers[parsed.rs1] + u64(imm)

		switch funct3 {
		case .SB:
			value := u8(cpu.registers[parsed.rs2])
			dec := decoded("sb", RegisterName[parsed.rs2], RegisterName[parsed.rs1], imm)

			switch address {
			case UART:
				fmt.eprintf("%c", value)
			case SYSCON:
				dec.syscon = true
				return dec
			case:
				write_to_memory(ram, address, value)
			}
			return dec

		case .SD:
			dec := decoded("sd", RegisterName[parsed.rs2], RegisterName[parsed.rs1], imm)

			if address == SYSCON {
				dec.syscon = true
				return dec
			}
			write_u64_to_memory(ram, address, cpu.registers[parsed.rs2])
			return dec

		case .SH:
		case .SW:
			dec := decoded("sw", RegisterName[parsed.rs2], RegisterName[parsed.rs1], imm)

			if address == SYSCON {
				dec.syscon = true
				return dec
			}
			write_u32_to_memory(ram, address, u32(cpu.registers[parsed.rs2]))
			return dec
		}

	case .UNKNOWN:
		return Decoded{}
	}
	return Decoded{}
}

write_to_memory :: proc(ram: []byte, address: u64, value: u8) {
	idx := address - RAM_OFFSET
	ram[idx] = value
}

write_u32_to_memory :: proc(ram: []byte, address: u64, value: u32) {
	idx := address - RAM_OFFSET
	for i: u64 = 0; i < 4; i += 1 {
		n := i * 8
		ram[idx + i] = u8(value >> n)
	}
}

write_u64_to_memory :: proc(ram: []byte, address: u64, value: u64) {
	idx := address - RAM_OFFSET
	for i: u64 = 0; i < 8; i += 1 {
		n := i * 8
		ram[idx + i] = u8(value >> n)
	}
}

sign_extend :: proc(n: u32, bits: u32) -> i64 {
	shift := u32(64 - bits)
	return i64(u64(n) << shift) >> shift
}

parse_type_s :: proc(ins: u32) -> TypeS {
	imm_5 := (ins >> 25) & MASK_7BIT
	imm := (ins >> 7) & MASK_5BIT
	return TypeS {
		funct3 = (ins >> TYPE_S_FUNCT3_SHIFT) & MASK_3BIT,
		rs1    = (ins >> TYPE_S_RS1_SHIFT) & MASK_5BIT,
		rs2    = (ins >> TYPE_S_RS2_SHIFT) & MASK_5BIT,
		imm    = (imm_5 << 5) | imm,
	}
}

parse_type_j :: proc(ins: u32) -> TypeJ {
	imm_20 := (ins >> 31) & MASK_1BIT
	imm_10_1 := (ins >> 21) & MASK_10BIT
	imm_11 := (ins >> 20) & MASK_1BIT
	imm_19_12 := (ins >> 12) & MASK_8BIT

	return TypeJ {
		rd  = (ins >> TYPE_J_RD_SHIFT) & MASK_5BIT,
		imm = (imm_20 << 20) | (imm_10_1 << 1) | (imm_11 << 11) | (imm_19_12 << 12),
	}
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

ensure_even :: proc(bits: u64) -> u64 {
	return bits & ~u64(1)
}

read :: proc(source: []byte, offset: i32, $T: typeid) -> T {
	end := offset + size_of(T)
	buf := source[offset:end]
	return (cast(^T)raw_data(buf))^
}

decoded :: proc {
	decoded_1,
	decoded_2,
}
decoded_1 :: proc(
	mnemonic: string,
	r0: string,
	imm: i64,
	address: u64 = 0,
	jump: bool = false,
) -> Decoded {
	return Decoded {
		mnemonic  = mnemonic,
		registers = {r0, "", ""},
		imm       = imm,
		address   = address,
		jump      = jump,
	}
}
decoded_2 :: proc(
	mnemonic: string,
	r0: string,
	r1: string,
	imm: i64,
	address: u64 = 0,
	jump: bool = false,
) -> Decoded {
	return Decoded {
		mnemonic  = mnemonic,
		registers = {r0, r1, ""},
		imm       = imm,
		address   = address,
		jump      = jump,
	}
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
	for i in 1 ..< 2 {
		name := names[i]
		if len(name) == 0 {break}
		s = fmt.tprintf("%s,%s", s, name)
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
