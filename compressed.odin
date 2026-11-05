package main

Quadrant :: enum u16 {
	Q0 = 0x0,
	Q1 = 0x1,
	Q2 = 0x2,
}

Q0_INS :: enum u16 {
	ADDI4SPN = 0x0,
	LW       = 0x2,
	LD       = 0x3,
	SW       = 0x6,
	SD       = 0x7,
}

Q1_INS :: enum u16 {
	ADDI     = 0x0,
	JAL      = 0x1,
	LI       = 0x2,
	LUI      = 0x3,
	MISC_ALU = 0x4,
	J        = 0x5,
	BEQZ     = 0x6,
	BNEZ     = 0x7,
}

Q1_MISC_ALU :: enum {
	SRLI,
	SRAI,
	ANDI,
	SUB,
	XOR,
	OR,
	AND,
	SUBW,
	ADDW,
	RESERVED,
}

Q1_LUI :: enum {
	ADDI16SP,
	LUI,
}

Q2_INS :: enum u16 {
	SLLI = 0x0,
	LWSP = 0x2,
	LDSP = 0x3,
	MISC = 0x4,
	SWSP = 0x6,
	SDSP = 0x7,
}

Q2_MISC :: enum {
	JR,
	MV,
	EBREAK,
	JALR,
	ADD,
}

BITS_1 :: u16(0x1)
BITS_2 :: u16(0x3)
BITS_3 :: u16(0x7)
BITS_4 :: u16(0xf)
BITS_5 :: u16(0x1f)

assemble_type_r :: proc(rs2, rs1, rd: u32, op: OPCODE, funct3: R_Funct3, funct7: R_Funct7) -> u32 {
	return(
		(u32(funct7) & MASK_7BIT) << 25 |
		(rs2 & MASK_5BIT) << 20 |
		(rs1 & MASK_5BIT) << 15 |
		(u32(funct3) & MASK_3BIT) << 12 |
		(rd & MASK_5BIT) << 7 |
		u32(op) & MASK_7BIT \
	)
}

assemble_type_u :: proc(imm, rd: u32, op: OPCODE) -> u32 {
	return (imm & MASK_20BIT) << 12 | (rd & MASK_5BIT) << 7 | u32(op) & MASK_7BIT
}

assemble_type_s :: proc(imm, rs1, rs2: u32, op: OPCODE, funct3: S_Funct3) -> u32 {
	return(
		((imm >> 5) & MASK_7BIT) << 25 |
		(rs2 & MASK_5BIT) << 20 |
		(rs1 & MASK_5BIT) << 15 |
		(u32(funct3) & MASK_3BIT) << 12 |
		(imm & MASK_5BIT) << 7 |
		u32(op) & MASK_7BIT \
	)
}

assemble_type_i :: proc {
	assemble_type_i_default,
	assemble_type_i_load,
}

assemble_type_i_default :: proc(imm, rs1, rd: u32, op: OPCODE, funct3: I_Funct3) -> u32 {
	return(
		((imm & MASK_12BIT) << 20) |
		((rs1 & MASK_5BIT) << 15) |
		((u32(funct3) & MASK_3BIT) << 12) |
		((rd & MASK_5BIT) << 7) |
		(u32(op) & MASK_7BIT) \
	)
}

assemble_type_i_load :: proc(imm, rs1, rd: u32, op: OPCODE, funct3: L_Funct3) -> u32 {
	return(
		((imm & MASK_12BIT) << 20) |
		((rs1 & MASK_5BIT) << 15) |
		((u32(funct3) & MASK_3BIT) << 12) |
		((rd & MASK_5BIT) << 7) |
		(u32(op) & MASK_7BIT) \
	)
}

assemble_type_j :: proc(imm, rd: u32, op: OPCODE) -> u32 {
	return(
		((imm >> 20) & MASK_1BIT) << 31 |
		((imm >> 1) & MASK_10BIT) << 21 |
		((imm >> 11) & MASK_1BIT) << 20 |
		((imm >> 12) & MASK_8BIT) << 12 |
		(rd & MASK_5BIT) << 7 |
		u32(op) & MASK_7BIT \
	)
}

ci_rd :: proc(ins: u16) -> u32 {
	return u32((ins >> 7) & BITS_5)
}
ci_imm6 :: proc(ins: u16) -> u32 {
	return u32((ins >> 12) & BITS_1) << 5 | u32((ins >> 2) & BITS_5)
}
rd_prime :: proc(ins: u16) -> u32 {
	return u32(ins >> 7 & BITS_3) + 8
}
rd2_prime :: proc(ins: u16) -> u32 {
	return u32((ins >> 2) & BITS_3) + 8
}

decompress_16_bit :: proc(ins: u16) -> u32 {
	op := Quadrant(ins & 0x3)
	funct3 := ins >> 13

	switch op {
	case .Q0:
		switch Q0_INS(funct3) {
		case .ADDI4SPN:
		case .LW:
		case .LD:
			// CL :: ins[6:5]<<6 | ins[12:10]<<3
			imm := u32((ins >> 5) & BITS_2) << 6 | u32((ins >> 10) & BITS_3) << 3
			rs1 := rd_prime(ins)
			rd := rd2_prime(ins)
			return assemble_type_i(u32(imm), rs1, rd, .LD, .LD)

		case .SW:
			// CS :: imm = ins[5]<<6 | ins[12:10]<<3 | ins[6]<<2, zx
			imm :=
				u32((ins >> 5) & BITS_1) << 6 |
				u32((ins >> 10) & BITS_3) << 3 |
				u32((ins >> 6) & BITS_1) << 2
			rs1 := rd_prime(ins)
			rs2 := rd2_prime(ins)
			return assemble_type_s(imm, rs1, rs2, .SB, .SW)

		case .SD:
			// CS :: imm = ins[6:5]<<6 | ins[12:10]<<3
			imm := u32((ins >> 5) & BITS_2) << 6 | u32((ins >> 10) & BITS_3) << 3
			rs1 := rd_prime(ins)
			rs2 := rd2_prime(ins)
			return assemble_type_s(imm, rs1, rs2, .SB, .SD)
		}
	case .Q1:
		switch Q1_INS(funct3) {
		case .ADDI:
			// CI :: imm = ins[12]<<5 | ins[6:2]
			rd := ci_rd(ins)
			imm := ci_imm6(ins)
			imm_32 := u32(sign_extend(u32(imm), 6))
			return assemble_type_i(imm_32, u32(rd), u32(rd), .ADDI, .ADDI)

		case .JAL:
		case .LI:
			// CI :: ins[12] << 5 | ins[6:2]
			imm := ci_imm6(ins)
			return assemble_type_i(u32(sign_extend(imm, 6)), 0, ci_rd(ins), .ADDI, I_Funct3.ADDI)

		case .LUI:
			rd := ci_rd(ins)

			switch lui(rd) {
			case .LUI:
				// CI :: ins[12] | ins[6:2]
				imm := ci_imm6(ins)
				return assemble_type_u(u32(sign_extend(imm, 6)), rd, .LUI)

			case .ADDI16SP:
				// CI    ins[12]<<9 | ins[4:3]<<7 | ins[5]<<6 | ins[2] << 5 | ins[6] << 4
				imm :=
					u32((ins >> 12) & BITS_1) << 9 |
					u32((ins >> 3) & BITS_2) << 7 |
					u32((ins >> 5) & BITS_1) << 6 |
					u32((ins >> 2) & BITS_1) << 5 |
					u32((ins >> 6) & BITS_1) << 4
				return assemble_type_i(u32(sign_extend(imm, 10)), rd, 0x2, .ADDI, .ADDI)
			}

		case .MISC_ALU:
			switch misc_alu(ins) {
			case .SRLI:
				// CB    ins[12]<<5 | ins[6:2]
				rd := rd_prime(ins)
				imm := ci_imm6(ins)
				return assemble_type_i(imm, rd, rd, .ADDI, .SRLI)

			case .SRAI:
				// CB    ins[12]<<5 | ins[6:2]
				rd := rd_prime(ins)
				imm := ci_imm6(ins) | (0x10 << 6)
				return assemble_type_i(imm, rd, rd, .ADDI, .SRLI)

			case .ANDI:
			case .SUB:
			case .XOR:
			case .OR:
			case .AND:
			case .SUBW:
				// CA :: rd'/rs1',rs2'
				rs1 := rd_prime(ins)
				rs2 := rd2_prime(ins)
				return assemble_type_r(rs2, rs1, rs1, .ADDW, .ADD, .SUB)

			case .ADDW:
				// CA :: rd'/rs1',rs2'
				rs1 := rd_prime(ins)
				rs2 := rd2_prime(ins)
				return assemble_type_r(rs2, rs1, rs1, .ADDW, .ADD, .DEFAULT)

			case .RESERVED:
			}

		case .J:
			// CJ :: ins[12]<<11 | ins[8]<<10 | ins[10:9]<<8 |
			//		 ins[6]<<7 | ins[7]<<6 | ins[2]<<5 |
			//		 ins[11]<<4 | ins[5:3]<<1
			// NOTE: such fun
			imm :=
				u32((ins >> 12) & BITS_1) << 11 |
				u32((ins >> 8) & BITS_1) << 10 |
				u32((ins >> 9) & BITS_2) << 8 |
				u32((ins >> 6) & BITS_1) << 7 |
				u32((ins >> 7) & BITS_1) << 6 |
				u32((ins >> 2) & BITS_1) << 5 |
				u32((ins >> 11) & BITS_1) << 4 |
				u32((ins >> 3) & BITS_3) << 1
			return assemble_type_j(u32(sign_extend(imm, 12)), 0, .JAL)

		case .BEQZ:
		case .BNEZ:
		}
	case .Q2:
		switch Q2_INS(funct3) {
		case .SLLI:
		case .LWSP:
		case .LDSP:
			// CI    ins[4:2]<<6 | ins[12]<<5 | ins[6:5]<<3        zx
			imm :=
				u32((ins >> 2) & BITS_3) << 6 |
				u32((ins >> 12) & BITS_1) << 5 |
				u32((ins >> 5) & BITS_2) << 3
			return assemble_type_i(imm, 0x2, ci_rd(ins), .LD, .LD)

		case .MISC:
			// CR
			rs1 := u32((ins >> 7) & BITS_5)
			rs2 := u32((ins >> 2) & BITS_5)
			bit12 := ins >> 12 & BITS_1

			switch misc(rs1, rs2, bit12) {
			case .JR:
				return assemble_type_i(0, rs1, 0, .JALR, .ADDI)
			case .MV:
			case .EBREAK:
			case .JALR:
				return assemble_type_i(0, rs1, 1, .JALR, .ADDI)
			case .ADD:
				return assemble_type_r(rs2, rs1, rs1, .ADD, .ADD, .DEFAULT)
			}
		case .SWSP:
		case .SDSP:
			// CSS :: imm = ins[9:7]<<6 | ins[12:10]<<3
			imm := u32((ins >> 7) & BITS_3) << 6 | u32((ins >> 10) & BITS_3) << 3
			rs2 := u32((ins >> 2) & BITS_5)
			return assemble_type_s(imm, 0x2, rs2, .SB, .SD)
		}
	}
	return 0
}

lui :: proc(rd: u32) -> Q1_LUI {
	if rd == 2 {return .ADDI16SP}
	return .LUI
}

// branch on ins[11:10]:
// 00 → C.SRLI
// 01 → C.SRAI
// 10 → C.ANDI
// 11 → register-register ops, needs further splitting

// Further splitting :: ins[12] and ins[6:5]:
// - ins[12]=0: 00→C.SUB, 01→C.XOR, 10→C.OR, 11→C.AND
// - ins[12]=1: 00→C.SUBW, 01→C.ADDW, 10/11 reserved

misc_alu :: proc(ins: u16) -> Q1_MISC_ALU {
	// NOTE: *sighs*
	op := (ins >> 10) & BITS_2
	switch op {
	case 0x0:
		return .SRLI
	case 0x1:
		return .SRAI
	case 0x2:
		return .ANDI
	case 0x3:
		split := (ins >> 12) & BITS_1
		sub := (ins >> 5) & BITS_2
		switch split {
		case 0x0:
			switch sub {
			case 0x0:
				return .SUB
			case 0x1:
				return .XOR
			case 0x2:
				return .OR
			case 0x3:
				return .AND
			}
		case 0x1:
			switch sub {
			case 0x0:
				return .SUBW
			case 0x1:
				return .ADDW
			}
		}
	}
	return .RESERVED
}

misc :: proc(rs1, rs2: u32, bit12: u16) -> Q2_MISC {
	if bit12 == 0 {
		if rs2 == 0 {return .JR}
		return .MV
	}
	if rs2 == 0 {
		if rs1 == 0 {return .EBREAK}
		return .JALR
	}
	return .ADD
}
