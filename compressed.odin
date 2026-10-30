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

Q2_INS :: enum u16 {
	SLLI = 0x0,
	LWSP = 0x2,
	LDSP = 0x3,
	MISC = 0x4,
	SWSP = 0x6,
	SDSP = 0x7,
}

BITS_1 :: u16(0x1)
BITS_2 :: u16(0x3)
BITS_3 :: u16(0x7)
BITS_4 :: u16(0xf)
BITS_5 :: u16(0x1f)

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

assemble_type_i :: proc(imm, rs1, rd: u32, op: OPCODE, funct3: I_Funct3) -> u32 {
	return(
		((imm & MASK_12BIT) << 20) |
		((rs1 & MASK_5BIT) << 15) |
		((u32(funct3) & MASK_3BIT) << 12) |
		((rd & MASK_5BIT) << 7) |
		(u32(op) & MASK_7BIT) \
	)
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
		case .SW:
		case .SD:
			// imm  = ins[6:5]<<6 | ins[12:10]<<3
			imm := u32((ins >> 5) & BITS_2) << 6 | u32((ins >> 10) & BITS_3) << 3
			rs1 := u32(ins >> 7 & BITS_3) + 8
			rs2 := u32(ins >> 2 & BITS_3) + 8
			return assemble_type_s(imm, rs1, rs2, .SB, .SD)
		}
	case .Q1:
		switch Q1_INS(funct3) {
		case .ADDI:
			rd := (ins >> 7) & BITS_5
			imm := ((ins >> 12) & BITS_1) << 5 | ((ins >> 2) & BITS_5)
			imm_32 := u32(sign_extend(u32(imm), 6))
			return assemble_type_i(imm_32, u32(rd), u32(rd), .ADDI, .ADDI)

		case .JAL:
		case .LI:
		case .LUI:
		case .MISC_ALU:
		case .J:
		case .BEQZ:
		case .BNEZ:
		}
	case .Q2:
		switch Q2_INS(funct3) {
		case .SLLI:
		case .LWSP:
		case .LDSP:
		case .MISC:
		case .SWSP:
		case .SDSP:
		}
	}
	return 0
}
