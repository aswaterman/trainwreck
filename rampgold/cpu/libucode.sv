//------------------------------------------------------------------------------   
// File:        libucode.v
// Author:      Zhangxi Tan
// Description: micro pc map and microcode data structure
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps


//indirection bits are encoded in microcode instructions (top bits of rd,rs1,rs2), 
//cwp bit
// 00 - in scratch
// 01 - rs1 in cwp/scratch
// 10 - rd in cwp/scratch

//terminate bit is separate

`ifndef SYNP94
package libucode;

import libconf::*;
`endif

parameter int NUPCMSB = 4;				//MSB for microcode pc, supports up to 32 instructions

//microcode addresses
`ifndef SYNP94
const bit [NUPCMSB:0] UPC_TRAP = 0;		//trap: and tbr, add tbr+temp, jump, rd <- pc, nop
const bit [NUPCMSB:0] UPC_ST = 4;		  //ST : st* rd, temp
const bit [NUPCMSB:0] UPC_STB = 5;		 //STB: stb* rd, temp
const bit [NUPCMSB:0] UPC_STH = 6;		 //STH: sth* rd, temp
const bit [NUPCMSB:0] UPC_STD = 7;		 //STD: st rd, temp; std, rd, temp, 4 (intepreted differently
//every address is physical after the first cycle
const bit [NUPCMSB:0] UPC_SWAP = 9;		 //SWAP: st rd, scratch, 0; mv rd, scratch1
const bit [NUPCMSB:0] UPC_LDST  = 11;	//add, scratch_1, g0, 1; stb scratch_1, scratch_0
const bit [NUPCMSB:0] UPC_FLUSH = 13; //flush scratch_0 
const bit [NUPCMSB:0] UPC_WRTBR = 14; //and tbr, tbr, 0xff0; add tbr, tbr, scratch_0
const bit [NUPCMSB:0] UPC_STF = 16; 
const bit [NUPCMSB:0] UPC_STDF = 17;
const bit [NUPCMSB:0] UPC_STFSR = 19;
`else
const bit [NUPCMSB:0] UPC_TRAP = 5'd0;		//trap: and tbr, add tbr+temp, jump, rd <- pc, nop
const bit [NUPCMSB:0] UPC_ST = 5'd4;		  //ST : st* rd, temp
const bit [NUPCMSB:0] UPC_STB = 5'd5;		 //STB: stb* rd, temp
const bit [NUPCMSB:0] UPC_STH = 5'd6;		 //STH: sth* rd, temp
const bit [NUPCMSB:0] UPC_STD = 5'd7;		 //STD: st rd, temp; std, rd, temp, 4 (intepreted differently
//every address is physical after the first cycle
const bit [NUPCMSB:0] UPC_SWAP = 5'd9;		 //SWAP: st rd, scratch, 0; mv rd, scratch1
const bit [NUPCMSB:0] UPC_LDST  = 5'd11;	//add, scratch_1, g0, 1; stb scratch_1, scratch_0
const bit [NUPCMSB:0] UPC_FLUSH = 5'd13; //flush scratch_0 
const bit [NUPCMSB:0] UPC_WRTBR = 5'd14; //and tbr, tbr, 0xff0; add tbr, tbr, scratch_0
const bit [NUPCMSB:0] UPC_STF = 5'd16; 
const bit [NUPCMSB:0] UPC_STDF = 5'd17;
const bit [NUPCMSB:0] UPC_STFSR = 5'd19;
`endif
//indirection bit pos.

const int UCIPOS_RD = 29;		//rd
const int UCIPOS_RS1 = 18;		//rs1
const int UCIPOS_RS2 = 4;		//rs2;

const bit [4:0]	UCI_MASK = 5'b10000;	//indirect mask, sample from ucode

typedef struct packed {
	bit		uend;		      //terminate bit
	bit 	cwp_rs1;	    //CWP relative index indicator for rs1 (i.e. use cwp, but still sample from microcode)
	bit		cwp_rd;		    //CWP relative index indicator for rd
	bit [31:0]	inst;		//microcode instruction 
}microcode_out_type;

`ifndef SYNP94
endpackage
`endif
