package main

RAM_SIZE :: 4 * 1024 * 1024 // 4MB
RAM_OFFSET :: 0x80000000

TYPE_U_RD_SHIFT :: 7
TYPE_U_IMM_SHIFT :: 12

TYPE_I_RD_SHIFT :: 7
TYPE_I_FUNCT3_SHIFT :: 12
TYPE_I_RS1_SHIFT :: 15
TYPE_I_IMM_SHIFT :: 20

TYPE_J_RD_SHIFT :: 7

MASK_1BIT :: u32(0x1)
MASK_3BIT :: u32(0x7)
MASK_5BIT :: u32(0x1F)
MASK_8BIT :: u32(0xFF)
MASK_10BIT :: u32(0x3FF)
MASK_12BIT :: u32(0xFFF)
MASK_20BIT :: u32(0xFFFFF)

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
