package main

RAM_SIZE :: 4 * 1024 * 1024 // 4MB
RAM_OFFSET :: 0x80000000

UART :: u64(0x10000000)
SYSCON :: u64(0x100000)

TYPE_U_RD_SHIFT :: 7
TYPE_U_IMM_SHIFT :: 12

TYPE_I_RD_SHIFT :: 7
TYPE_I_FUNCT3_SHIFT :: 12
TYPE_I_RS1_SHIFT :: 15
TYPE_I_IMM_SHIFT :: 20

TYPE_J_RD_SHIFT :: 7

TYPE_S_FUNCT3_SHIFT :: 12
TYPE_S_RS1_SHIFT :: 15
TYPE_S_RS2_SHIFT :: 20

MASK_1BIT :: u32(0x1)
MASK_2BIT :: u32(0x3)
MASK_3BIT :: u32(0x7)
MASK_5BIT :: u32(0x1F)
MASK_7BIT :: u32(0x7F)
MASK_8BIT :: u32(0xFF)
MASK_10BIT :: u32(0x3FF)
MASK_12BIT :: u32(0xFFF)
MASK_20BIT :: u32(0xFFFFF)

I_Funct3 :: enum u32 {
	ADDI  = 0x0,
	SLTI  = 0x2,
	SLTIU = 0x3,
	XORI  = 0x4,
	ORI   = 0x6,
	ANDI  = 0x7,
	SLLI  = 0x1,
	SRLI  = 0x5,
}

B_Funct3 :: enum u32 {
	BEQ  = 0x0,
	BNE  = 0x1,
	BLT  = 0x4,
	BGE  = 0x5,
	BLTU = 0x6,
	BGEU = 0x7,
}

Load_Funct3 :: enum u32 {
	LB  = 0x0,
	LH  = 0x1,
	LW  = 0x2,
	LD  = 0x3,
	LBU = 0x4,
	LHU = 0x5,
	LWU = 0x6,
}

S_Funct3 :: enum u32 {
	SB = 0x0,
	SH = 0x1,
	SW = 0x2,
	SD = 0x3,
}

R_Funct3 :: enum u32 {
	ADD  = 0x0,
	SLL  = 0x1,
	SLT  = 0x2,
	SLTU = 0x3,
	XOR  = 0x4,
	SRL  = 0x5,
	OR   = 0x6,
	AND  = 0x7,
}

R_Funct7 :: enum u32 {
	DEFAULT = 0x00,
	SUB     = 0x20,
	SRA     = 0x20,
}

RegisterName := [32]string {
	"zero",
	"ra",
	"sp",
	"gp",
	"tp",
	"t0",
	"t1",
	"t2",
	"s0",
	"s1",
	"a0",
	"a1",
	"a2",
	"a3",
	"a4",
	"a5",
	"a6",
	"a7",
	"s2",
	"s3",
	"s4",
	"s5",
	"s6",
	"s7",
	"s8",
	"s9",
	"s10",
	"s11",
	"t3",
	"t4",
	"t5",
	"t6",
}
