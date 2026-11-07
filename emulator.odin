package main

import "core:fmt"
import "core:os"
import "core:strings"


OPCODE :: enum u32 {
	LUI     = 0x37,
	AUIPC   = 0x17,
	ADDI    = 0x13,
	ADDIW   = 0x1b,
	ADD     = 0x33,
	ADDW    = 0x3b,
	SB      = 0x23,
	JAL     = 0x6f,
	JALR    = 0x67,
	LD      = 0x3,
	BLT     = 0x63,
	UNKNOWN = 0x00,
}

Cpu :: struct {
	registers: [32]u64,
	pc:        u64,
}

Decoded :: struct {
	mnemonic:  string,
	registers: [3]string,
	imm:       i64,
	address:   u64,
	jump:      bool,
	syscon:    bool,
	panic:     string,
}

Func :: struct {
	lo:   u64,
	hi:   u64,
	name: string,
}
Symbols :: struct {
	funcs: []Func,
	idx:   u64,
}

main :: proc() {
	path := "build/hi/glassheap.elf"
	if len(os.args) > 1 {
		path = os.args[1]
	}
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.panicf("failed to read elf %s: %w", path, err)
	}
	header: Header
	header.Entry = read(data, i32(ELF_HEADER.ENTRY), u64)
	header.Phoff = read(data, i32(ELF_HEADER.PHOFF), u64)
	header.Phnum = read(data, i32(ELF_HEADER.PHNUM), u16)
	header.Shoff = read(data, i32(ELF_HEADER.SHOFF), u64)
	header.Shnum = read(data, i32(ELF_HEADER.SHNUM), u16)
	header.Shentsize = read(data, i32(ELF_HEADER.SHENTSIZE), u16)

	ram := make([]byte, RAM_SIZE)
	defer delete(ram)
	load_ram(header, data, ram)

	cpu := Cpu {
		pc = header.Entry,
	}
	symbols := Symbols {
		funcs = load_sections(header, data),
	}
	b := strings.Builder{}
	strings.builder_init(&b)
	defer strings.builder_destroy(&b)

	for {
		idx := cpu.pc - RAM_OFFSET
		ins := read(ram, i32(idx), u32)
		seek: u64 = 4
		snapshot := cpu.registers

		if !is_32_bit(ins) {
			trace(&b, cpu.pc, u16(ins))
			ins = decompress_16_bit(u16(ins))
			seek = 2
		} else {
			trace(&b, cpu.pc, ins)
		}
		decoded := decode_32_bit(ins, &cpu, ram)

		if len(decoded.panic) > 0 {
			flush(&b)
			fmt.println(decoded.panic)
			panic("nope")
		}
		trace(&b, decoded.mnemonic)
		trace(&b, decoded.registers, decoded.imm)
		trace(&b, decoded.address)

		cpu_dump(&b, snapshot)
		flush(&b)

		if decoded.jump {
			fmt.println("------------------------------------------")
			continue
		}
		if decoded.syscon {
			fmt.println("received syscon")
			os.exit(0)
		}
		cpu.pc += seek
	}
}


decode_32_bit :: proc(ins: u32, cpu: ^Cpu, ram: []byte) -> Decoded {
	opcode := OPCODE(ins & MASK_7BIT)

	switch opcode {
	case .LUI:
		parsed := parse_type_u(ins)
		address := u64(sign_extend(parsed.imm << 12, 32))
		set_register(cpu, parsed.rd, address)
		return decoded("lui", RegisterName[parsed.rd], i64(parsed.imm), address)

	case .AUIPC:
		parsed := parse_type_u(ins)
		imm := sign_extend(parsed.imm << 12, 32)
		address := cpu.pc + u64(imm)
		set_register(cpu, parsed.rd, address)
		return decoded("auipc", RegisterName[parsed.rd], i64(parsed.imm), address)

	case .ADDI:
		parsed := parse_type_i(ins)
		switch I_Funct3(parsed.funct3) {
		case .SLTI:
		case .SLLI:
		case .SLTIU:
		case .XORI:
		case .ORI:

		case .ADDI:
			imm := sign_extend(parsed.imm, 12)
			set_register(cpu, parsed.rd, cpu.registers[parsed.rs1] + u64(imm))
			return decoded("addi", RegisterName[parsed.rd], RegisterName[parsed.rs1], imm)

		case .ANDI:
			imm := sign_extend(parsed.imm, 12)
			set_register(cpu, parsed.rd, cpu.registers[parsed.rs1] & u64(imm))
			return decoded("andi", RegisterName[parsed.rd], RegisterName[parsed.rs1], imm)

		case .SRLI:
			// x[rd] = x[rs1] >>s shamt
			// funct3 0x5 :: imm[11:6]=funct6 (0x10=SRAI arithmetic, 0x00=SRLI logical), imm[5:0]=shamt
			shamt := parsed.imm & MASK_6BIT
			funct6 := (parsed.imm >> 6) & MASK_6BIT
			switch funct6 {
			case 0x10:
				set_register(cpu, parsed.rd, u64(i64(cpu.registers[parsed.rs1]) >> shamt))
				return decoded(
					"srai",
					RegisterName[parsed.rd],
					RegisterName[parsed.rs1],
					i64(shamt),
				)
			case:
				set_register(cpu, parsed.rd, cpu.registers[parsed.rs1] >> shamt)
				return decoded(
					"srli",
					RegisterName[parsed.rd],
					RegisterName[parsed.rs1],
					i64(shamt),
				)
			}
		}

	case .ADDIW:
		parsed := parse_type_i(ins)
		imm := sign_extend(parsed.imm, 12)
		value := sign_extend(u32(cpu.registers[parsed.rs1] + u64(imm)), 32)
		set_register(cpu, parsed.rd, u64(value))
		return decoded("addiw", RegisterName[parsed.rd], RegisterName[parsed.rs1], imm)

	case .ADD:
		parsed := parse_type_r(ins)
		set_register(cpu, parsed.rd, cpu.registers[parsed.rs1] + cpu.registers[parsed.rs2])
		return decoded(
			"add",
			RegisterName[parsed.rd],
			RegisterName[parsed.rs1],
			RegisterName[parsed.rs2],
			0,
		)

	case .ADDW:
		parsed := parse_type_r(ins)
		switch addw(parsed.funct3, parsed.funct7) {
		case .ADDW:
			value := u32(cpu.registers[parsed.rs1] + cpu.registers[parsed.rs2])
			set_register(cpu, parsed.rd, u64(sign_extend(value, 32)))
			return decoded(
				"addw",
				RegisterName[parsed.rd],
				RegisterName[parsed.rs1],
				RegisterName[parsed.rs2],
			)
		case .SUBW:
			value := u32(cpu.registers[parsed.rs1] - cpu.registers[parsed.rs2])
			set_register(cpu, parsed.rd, u64(sign_extend(value, 32)))
			return decoded(
				"subw",
				RegisterName[parsed.rd],
				RegisterName[parsed.rs1],
				RegisterName[parsed.rs2],
			)

		case .SLLW:
		case .SRLW:
		case .SRAW:
		case .MULW:
		case .DIVW:
		case .DIVUW:
		case .REMW:
		case .REMUW:
		case .RESERVED:
		}

	case .JAL:
		parsed := parse_type_j(ins)
		imm := sign_extend(parsed.imm, 21)
		set_register(cpu, parsed.rd, cpu.pc + 4)
		cpu.pc += u64(imm)
		return decoded("jal", RegisterName[parsed.rd], imm, cpu.pc, true)

	case .JALR:
		parsed := parse_type_i(ins)
		imm := sign_extend(parsed.imm, 12)
		set_register(cpu, parsed.rd, cpu.pc + 4)
		cpu.pc = ensure_even(cpu.registers[parsed.rs1] + u64(imm))

		return decoded(
			"jalr",
			RegisterName[parsed.rd],
			RegisterName[parsed.rs1],
			imm,
			cpu.pc,
			true,
		)

	case .LD:
		parsed := parse_type_i(ins)
		imm := sign_extend(parsed.imm, 12)
		address := cpu.registers[parsed.rs1] + u64(imm)
		idx := i32(address - RAM_OFFSET)
		set_register(cpu, parsed.rd, read(ram, idx, u64))
		return decoded("ld", RegisterName[parsed.rd], RegisterName[parsed.rs1], imm)

	case .BLT:
		parsed := parse_type_b(ins)
		imm := sign_extend(parsed.imm, 13)

		if i64(cpu.registers[parsed.rs1]) < i64(cpu.registers[parsed.rs2]) {
			cpu.pc += u64(imm)
			return decoded(
				"blt",
				RegisterName[parsed.rs1],
				RegisterName[parsed.rs2],
				imm,
				cpu.pc,
				true,
			)
		}
		return decoded("blt", RegisterName[parsed.rs1], RegisterName[parsed.rs2], imm)


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
			write_to_memory(ram, address, cpu.registers[parsed.rs2])
			return dec

		case .SH:
		case .SW:
			dec := decoded("sw", RegisterName[parsed.rs2], RegisterName[parsed.rs1], imm)

			if address == SYSCON {
				dec.syscon = true
				return dec
			}
			write_to_memory(ram, address, u32(cpu.registers[parsed.rs2]))
			return dec
		}

	case .UNKNOWN:
		return Decoded{panic = fmt.aprintf("instruction not implemented: %08x", ins)}
	}
	return Decoded{panic = fmt.aprintf("instruction not implemented: %08x", ins)}
}

set_register :: proc(cpu: ^Cpu, rd: u32, value: u64) {
	if rd == 0 {return}
	cpu.registers[rd] = value
}

write_to_memory :: proc {
	write_u8_to_memory,
	write_u32_to_memory,
	write_u64_to_memory,
}

write_u8_to_memory :: proc(ram: []byte, address: u64, value: u8) {
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

parse_type_b :: proc(ins: u32) -> TypeB {
	imm_12 := (ins >> 31) & MASK_1BIT
	imm_5 := (ins >> 25) & MASK_6BIT
	imm_1 := (ins >> 8) & MASK_4BIT
	imm_11 := (ins >> 7) & MASK_1BIT
	return TypeB {
		funct3 = (ins >> 12) & MASK_3BIT,
		rs1    = (ins >> 15) & MASK_5BIT,
		rs2    = (ins >> 20) & MASK_5BIT,
		imm    = imm_12 << 12 | imm_5 << 5 | imm_1 << 1 | imm_11 << 11,
	}
}

parse_type_r :: proc(ins: u32) -> TypeR {
	return TypeR {
		funct7 = (ins >> 25) & MASK_7BIT,
		rs2    = (ins >> 20) & MASK_5BIT,
		rs1    = (ins >> 15) & MASK_5BIT,
		funct3 = (ins >> 12) & MASK_3BIT,
		rd     = (ins >> 7) & MASK_5BIT,
	}
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

addw :: proc(funct3, funct7: u32) -> W_INS {
	switch funct7 {
	case 0x00:
		switch funct3 {
		case 0x0:
			return .ADDW
		case 0x1:
			return .SLLW
		case 0x5:
			return .SRLW
		}
	case 0x20:
		switch funct3 {
		case 0x0:
			return .SUBW
		case 0x5:
			return .SRAW
		}
	case 0x01:
		switch funct3 {
		case 0x0:
			return .MULW
		case 0x4:
			return .DIVW
		case 0x5:
			return .DIVUW
		case 0x6:
			return .REMW
		case 0x7:
			return .REMUW
		}
	}
	return .RESERVED
}

is_32_bit :: proc(ins: u32) -> bool {
	return ins & 0x3 == 0x3
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
	decoded_3,
}
decoded_1 :: proc(
	mnemonic: string,
	r0: string,
	imm: i64 = 0,
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
	imm: i64 = 0,
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

decoded_3 :: proc(
	mnemonic: string,
	r0: string,
	r1: string,
	r2: string,
	imm: i64 = 0,
	address: u64 = 0,
	jump: bool = false,
) -> Decoded {
	return Decoded {
		mnemonic  = mnemonic,
		registers = {r0, r1, r2},
		imm       = imm,
		address   = address,
		jump      = jump,
	}
}
