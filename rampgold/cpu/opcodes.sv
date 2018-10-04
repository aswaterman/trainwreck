//---------------------------------------------------------------------------   
// File:        opcodes.v
// Author:      Zhangxi Tan
// Description: Instruction definitions according to the SPARC V8 manual. 
//		Translated from Leon3 of GRLIB.
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps

`ifndef SYNP94
package libopcodes;
`endif
// op decoding (inst(31 downto 30))

typedef bit [1:0] op_type;

const op_type FMT2 = 2'b00;
const op_type CALL = 2'b01;
const op_type FMT3 = 2'b10;
const op_type LDST = 2'b11;

// op2 decoding (inst(24 downto 22))

typedef bit [2:0] op2_type;

const op2_type UNIMP = 3'b000;
const op2_type BICC = 3'b010;
const op2_type SETHI = 3'b100;
const op2_type FBFCC = 3'b110;
const op2_type CBCCC = 3'b111;

// op3 decoding (inst(24 downto 19))

typedef bit [5:0] op3_type;

const op3_type	IADD = 6'b000000;
const op3_type	IAND = 6'b000001;
const op3_type	IOR  = 6'b000010;
const op3_type	IXOR = 6'b000011;
const op3_type	ISUB = 6'b000100;
const op3_type	ANDN = 6'b000101;
const op3_type	ORN  = 6'b000110;
const op3_type	IXNOR = 6'b000111;
const op3_type	ADDX = 6'b001000;
const op3_type	UMUL = 6'b001010;
const op3_type	SMUL = 6'b001011;
const op3_type	SUBX = 6'b001100;
const op3_type	UDIV = 6'b001110;
const op3_type	SDIV = 6'b001111;
const op3_type	ADDCC = 6'b010000;
const op3_type	ANDCC = 6'b010001;
const op3_type	ORCC = 6'b010010;
const op3_type	XORCC = 6'b010011;
const op3_type	SUBCC = 6'b010100;
const op3_type	ANDNCC = 6'b010101;
const op3_type	ORNCC = 6'b010110;
const op3_type	XNORCC = 6'b010111;
const op3_type	ADDXCC = 6'b011000;
const op3_type	UMULCC = 6'b011010;
const op3_type	SMULCC = 6'b011011;
const op3_type	SUBXCC = 6'b011100;
const op3_type	UDIVCC = 6'b011110;
const op3_type	SDIVCC = 6'b011111;
const op3_type	TADDCC = 6'b100000;
const op3_type	TSUBCC = 6'b100001;
const op3_type	TADDCCTV = 6'b100010;
const op3_type	TSUBCCTV = 6'b100011;
const op3_type	MULSCC = 6'b100100;
const op3_type	ISLL = 6'b100101;
const op3_type	ISRL = 6'b100110;
const op3_type	ISRA = 6'b100111;
const op3_type	RDY = 6'b101000;
const op3_type	RDPSR = 6'b101001;
const op3_type	RDWIM = 6'b101010;
const op3_type	RDTBR = 6'b101011;
const op3_type	WRY = 6'b110000;
const op3_type	WRPSR = 6'b110001;
const op3_type	WRWIM = 6'b110010;
const op3_type	WRTBR = 6'b110011;
const op3_type	FPOP1 = 6'b110100;
const op3_type	FPOP2 = 6'b110101;
const op3_type	CPOP1 = 6'b110110;
const op3_type	CPOP2 = 6'b110111;
const op3_type	JMPL = 6'b111000;
const op3_type	TICC = 6'b111010;
const op3_type	FLUSH = 6'b111011;
const op3_type	RETT = 6'b111001;
const op3_type	SAVE = 6'b111100;
const op3_type	RESTORE = 6'b111101;

//Sparc V8e instructions (not supported)
const op3_type	UMAC = 6'b111110;
const op3_type	SMAC = 6'b111111;

const op3_type	LD   = 6'b000000;
const op3_type	LDUB = 6'b000001;
const op3_type	LDUH = 6'b000010;
const op3_type	LDD  = 6'b000011;
const op3_type	LDSB = 6'b001001;
const op3_type	LDSH = 6'b001010;
const op3_type	LDSTUB = 6'b001101;
const op3_type	SWAP = 6'b001111;
const op3_type	LDA  = 6'b010000;
const op3_type	LDUBA = 6'b010001;
const op3_type	LDUHA = 6'b010010;
const op3_type	LDDA  = 6'b010011;
const op3_type	LDSBA = 6'b011001;
const op3_type	LDSHA = 6'b011010;
const op3_type	LDSTUBA = 6'b011101;
const op3_type	SWAPA   = 6'b011111;
const op3_type	LDF   = 6'b100000;
const op3_type	LDFSR = 6'b100001;
const op3_type	LDDF  = 6'b100011;
const op3_type	LDC   = 6'b110000;
const op3_type	LDCSR = 6'b110001;
const op3_type	LDDC = 6'b110011;
const op3_type	ST   = 6'b000100;
const op3_type	STB  = 6'b000101;
const op3_type	STH  = 6'b000110;
const op3_type	STD = 6'b000111;
const op3_type	STA  = 6'b010100;
const op3_type	STBA = 6'b010101;
const op3_type	STHA = 6'b010110;
const op3_type	STDA = 6'b010111;
const op3_type	STF  = 6'b100100;
const op3_type	STFSR = 6'b100101;
const op3_type	STDFQ = 6'b100110;
const op3_type	STDF = 6'b100111;
const op3_type	STC  = 6'b110100;
const op3_type	STCSR = 6'b110101;
const op3_type	STDCQ = 6'b110110;
const op3_type	STDC = 6'b110111;

// bicc decoding (inst(28 downto 25))

const bit [3:0]	BA  = 4'b1000;
const bit [3:0]	BN  = 4'b0000;
const bit [3:0]	BNE = 4'b1001;
const bit [3:0]	BE  = 4'b0001;
const bit [3:0]	BG  = 4'b1010;
const bit [3:0]	BLE = 4'b0010;
const bit [3:0]	BGE = 4'b1011;
const bit [3:0]	BL  = 4'b0011;
const bit [3:0]	BGU = 4'b1100;
const bit [3:0]	BLEU= 4'b0100;
const bit [3:0]	BCC = 4'b1101;
const bit [3:0]	BCS = 4'b0101;
const bit [3:0]	BPOS= 4'b1110;
const bit [3:0]	BNEG= 4'b0110;
const bit [3:0]	BVC = 4'b1111;
const bit [3:0]	BVS = 4'b0111;

// fpop1 decoding

typedef bit [8:0] fpop_type;

const fpop_type	FITOS = 9'b011000100;
const fpop_type	FITOD = 9'b011001000;
const fpop_type FITOQ = 9'b011001100;
const fpop_type	FSTOI = 9'b011010001;
const fpop_type	FDTOI = 9'b011010010;
const fpop_type FQTOI = 9'b011010011;
const fpop_type	FSTOD = 9'b011001001;
const fpop_type FSTOQ = 9'b011001101;
const fpop_type	FDTOS = 9'b011000110;
const fpop_type FDTOQ = 9'b011001110;
const fpop_type FQTOS = 9'b011000111;
const fpop_type FQTOD = 9'b011001011;
const fpop_type	FMOVS = 9'b000000001;
const fpop_type	FNEGS = 9'b000000101;
const fpop_type	FABSS = 9'b000001001;
const fpop_type	FSQRTS = 9'b000101001;
const fpop_type	FSQRTD = 9'b000101010;
const fpop_type FSQRTQ = 9'b000101011;
const fpop_type	FADDS = 9'b001000001;
const fpop_type	FADDD = 9'b001000010;
const fpop_type FADDQ = 9'b001000011;
const fpop_type	FSUBS = 9'b001000101;
const fpop_type	FSUBD = 9'b001000110;
const fpop_type FSUBQ = 9'b001000111;
const fpop_type	FMULS = 9'b001001001;
const fpop_type	FMULD = 9'b001001010;
const fpop_type FMULQ = 9'b001001011;
const fpop_type	FSMULD = 9'b001101001;
const fpop_type FDMULQ = 9'b001101110;
const fpop_type	FDIVS = 9'b001001101;
const fpop_type	FDIVD = 9'b001001110;
const fpop_type FDIVQ = 9'b001001111;

// fpop2 decoding

const fpop_type	FCMPS = 9'b001010001;
const fpop_type	FCMPD = 9'b001010010;
const fpop_type FCMPQ = 9'b001010011;
const fpop_type	FCMPES = 9'b001010101;
const fpop_type	FCMPED = 9'b001010110;
const fpop_type FCMPEQ = 9'b001010111;

// trap type decoding

typedef bit [5:0] trap_type;

const trap_type	TT_IAEX = 6'b000001;
const trap_type	TT_IINST= 6'b000010;
const trap_type	TT_PRIV = 6'b000011;
const trap_type	TT_FPDIS= 6'b000100;
const trap_type	TT_WINOF= 6'b000101;
const trap_type	TT_WINUF= 6'b000110;
const trap_type	TT_UNALA= 6'b000111;
const trap_type	TT_DAEX = 6'b001001;
const trap_type	TT_TAG  = 6'b001010;
const trap_type	TT_DIVZ = 6'b101010;
const trap_type	TT_TICC = 6'b111111;


const trap_type	TT_FPEXC= 6'b001000;

//const trap_type	TT_WATCH= 6'b001011;
//const trap_type	TT_DSU  = 6'b010000;
//const trap_type	TT_PWD  = 6'b010001;

//const trap_type	TT_RFERR= 6'b100000;
//const trap_type	TT_IAERR= 6'b100001;
const trap_type	TT_CPDIS= 6'b100100;
//const trap_type	TT_CPEXC= 6'b101000;
//const trap_type	TT_DSEX = 6'b101011;

// Floating point trap types
typedef bit [2:0] ftt_type;

const ftt_type FTT_NONE     = 3'b000;
const ftt_type FTT_IEEE754  = 3'b001;
const ftt_type FTT_UNFIN    = 3'b010;
const ftt_type FTT_UNIMP    = 3'b011;
const ftt_type FTT_SEQER    = 3'b100;
const ftt_type FTT_HWERR    = 3'b101;
const ftt_type FTT_INVREG   = 3'b110;

// Alternate address space identifiers (only the lowest 5 bits are used)

typedef bit [4:0] asi_type;

const asi_type	ASI_UINST = 5'b01000; // 0x08
const asi_type	ASI_SINST = 5'b01001; // 0x09
const asi_type	ASI_UDATA = 5'b01010; // 0x0A
const asi_type	ASI_SDATA = 5'b01011; // 0x0B

const asi_type	ASI_TIO = 5'b00010; // 0x02    //TIO bus


const asi_type	ASI_MMUFLUSHPROBE = 5'b00011;  // 0x3 i/dtlb flush/(probe)
const asi_type	ASI_MMUREGS = 5'b00100;  // 0x4 mmu regs access
const asi_type	ASI_MMU_BP = 5'b11110;  // 0x1E mmu Bypass 



//register file allocation (perthread)
//Address	architecture registers
//0-7		g0-g7	(global register)
//8		TBA field of TBR
//9		TT filed of TBR
//10-16		reserved
//17-31		architecture dependent ASR
//32-63		2 sparc register windows

const bit [4:0]	REGADDR_TBR       = 5'd8;		//TBA register
const bit [4:0]	REGADDR_SCRATCH_0 = 5'd9;		//scratch reg 0	
const bit [4:0]	REGADDR_SCRATCH_1 = 5'd10;		//scratch reg 1

const bit [4:0] REGADDR_ASR15     = 5'd15;  //thread ID register
`ifndef SYNP94
endpackage
`endif

