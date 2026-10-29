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
BITS_4 :: u16(0xf)

assemble_type_i :: proc(imm, rs1, funct3, rd, op: u32) -> u32 {
	return(
		((imm & MASK_12BIT) << 20) |
		((rs1 & MASK_5BIT) << 15) |
		((funct3 & MASK_3BIT) << 12) |
		((rd & MASK_5BIT) << 7) |
		(op & MASK_7BIT) \
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
		}
	case .Q1:
		switch Q1_INS(funct3) {
		case .ADDI:
			//rd/rs2 = ins[11:7]     (full 5-bit, not primed)
			//imm    = ins[12]<<5 | ins[6:2]
			//note  : sign-extended from 6 bits. rd != 0, imm != 0
			//maps  : addi rd, rd, imm
			//32bit : ADDI rd, rd, imm
			imm := ((ins >> 12) & BITS_1) | ((ins >> 2) & BITS_4)

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
