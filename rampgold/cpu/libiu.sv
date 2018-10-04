//------------------------------------------------------------------------------   
// File:        libiu.sv
// Author:      Zhangxi Tan
// Description: Header file for integer pipeline
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps


`ifndef SYNP94
package libiu;
import libstd::*;
import libucode::*;
import libopcodes::*;
import libconf::*;
import libtech::*;
import libdebug::*;
import libfp::*;
`else
`include "../stdlib/libstd.sv"
`include "../libconf.sv"
`include "libdebug.sv"
`include "opcodes.sv"
`include "libucode.sv"
`include "libfp.sv"
`include "../tech/libtech.sv"
`endif

//clocks
typedef struct {
  bit	clk;			  //base clock
	bit	clk2x;			//2x clock		
	bit	ce;			   //small delay of clk, generated using a clk2x clocked dff	
	bit io_reset;	   //powerup reset (from dcm locked) to reset I/Os
}iu_clk_type;

//Architecture register definition
typedef struct packed {
	bit N;			// Neg		icc[3]	
	bit Z;			// Zero		icc[2]
	bit V;			// Overflow	icc[1]	
	bit C;			// Carry	icc[0]	
} alu_flag_type;

`ifdef SYNP94
const alu_flag_type init_alu_flags = {1'b0, 1'b0, 1'b0, 1'b0};
`else
const alu_flag_type init_alu_flags = '{0, 0, 0, 0};
`endif

typedef struct packed {
	alu_flag_type 	 icc;	//alu flags
	bit             ef;  //enable floating point
	bit [3:0] 	     pil;	//processor interrupt level
	bit	  	         s;	  //supervisor mode
	bit	  	         ps;	 //previous supervisor mode
	bit	  	         et;	 //enable trap
	bit [NWINMSB:0]	cwp;	//current window pointer	
} psr_reg_type;		//Processor State Register

`ifdef SYNP94
const bit [NWINMSB:0] zerocwp = 0;
const psr_reg_type init_psr = {{1'b0, 1'b0, 1'b0, 1'b0}, FPEN, 4'd0, 1'b1, 1'b0, 1'b0, zerocwp};
`else
const psr_reg_type init_psr = '{init_alu_flags, FPEN, 0, 1, 0, 0, 0};
`endif

typedef struct packed{
  logic	[31:0]		    y;
  logic			          parity;
} y_reg_type;					    //Y register

`ifndef SYNP94
const y_reg_type  init_y = '{0, 0};
`else
const y_reg_type  init_y = {32'd0, 1'b0};
`endif


//----------------------------------------------------------------
typedef enum bit [2:0] {DEFAULTcc, ADDcc, SUBcc, TADDcc, TSUBcc, TADDccTV, TSUBccTV}	alu_gen_flag_type;		// alu flags
typedef enum bit [2:0] {c_UMUL, c_SMUL, c_UDIV, c_SDIV, c_SRL, c_SLL, c_SRA, c_NOP} mul_ctrl_type;		//mul/shf/div control
/////////////////////////////////////////////////////////////////////////////////////
// DSP control
typedef struct {
	bit [31:0]		op1, op2;
	bit			      carryin;		        //unused in MUL/SHF/DIV

	struct {
		dsp_ctrl_type		   dsp_ctrl;	//used by adder/logic alu only. dsp controls for mul are fixed	
		alu_gen_flag_type	genflag;	 //used by adder/logic alu only
	}al;					//for add logic

	struct {
		mul_ctrl_type		mode;		      //mul/shf/div mode
		bit					op2zero;		  //for divide zero trap
		bit			         parity;
	}msd;					//mul/shf/div
} alu_dsp_in_type;

typedef struct {		
	//DSP data output, usually in the 1st cycle
	bit [31:0]	   result;		     // alu result
  y_reg_type    y;            // new Y register value
	bit           wry;          // update Y register       
	bit		         parity_error;	// parity error, used by mul/shf/div, where LUTRAMs are used. This will be sent to the centralized SEU monitor 
	//DSP flag output, usually in the 2nd cycle
	alu_flag_type	flag;		       // alu flag
	bit		         tag_overflow;	// tag_overflow
	bit		         divz;		       // div zero
	bit		         valid;		      // result is valid (not nop)
} alu_dsp_out_type;


parameter int FLUSHIDXMSB = 2;   // support 8 cachelines

typedef struct {
	bit [NTHREADIDMSB:0] tid;	       //thread id
	bit		                tid_parity; //parity of thread_id
	bit [31:0]	          inst;		     //instructions
	bit		                run;	      	//run bit
	bit		                valid;	      	//TM timing token valid bit
	bit 	                replay;	    //replay bit
	//bit		                annul_trap;	//annul bit (annulled by bicc, but increment PC); trap bit in ucmode
	bit		                annul;	     //annul bit (annulled by bicc, but increment PC)
	bit		                ucmode;		   //micro code mode;
	bit                  dma_mode;   //indicates in DMA mode
	bit                  icmiss;     //icache miss bit

	//architecture registers 
	psr_reg_type	        psr;		      //psr
	fsr_reg_type         fsr;        //fsr
	bit [NWIN-1:0]	      wim;		      //wim	
	y_reg_type           y;          //Y
	bit [29:0]	          pc, npc;	   //pc, npc

	//machine state
	//bit		execution_mode;	//execution mode
	//bit		error_mode;	//error mode
	bit [FLUSHIDXMSB:0]  flushidx;   //flush index
	bit [NUPCMSB:0]      upc;		      //microcode pc
	bit 		               rdmask;		   //indirection bit for rd
	bit		                uend;		     //terminate bit for microcode mode
	//asi
	bit                  ldst_a;     //ASI load/store/		
  asi_type             asi;   
  
  //dma state
  debug_dma_iu_state_type dma_state;
} thread_state_type;


/////////////////////////////////////////////////////////////////////////////////////
//pipeline registers
typedef struct  {		
		thread_state_type		ts;		      // thread state
		//microcode result
		bit [31:0]			      microinst;	// microcode instruction
		bit				           rs1mask;	  // indirection bit for rs1	(scratch mask)
		bit				           rs2mask;	  // indirection bit for rs2	(scratch mask)
		bit				           cwp_rs1;	  // CWP relative index indicator for rs1
		bit				           cwp_rd;		  // CWP relative index indicator for rsd
} decode_reg_type;		//pipeline register type for decode stage

typedef struct {
  bit [9:8]   l;          //level
  bit [7:5]   at;       //access type, can be inferred from psr
	bit					  exception;		//TLB exceptions		
  bit [4:2]   ft;         //fault type
  bit         tlbmiss;    //itlb miss
  
  struct {
    bit   nf;
    bit   e;
  }ctrl_reg;
  
  bit [log2x(MMUCTXNUM):0]  ctx_reg;         //current context number
}immu_data_type;


typedef struct  {		
		thread_state_type	ts;		// thread state
		//IF result
		bit			iaex;		// instruction access exception (MMU exception)		
		immu_data_type       immu_data;     // immu access data;
		//decoding result
		bit			branch_true;	// resolved branch in decoding stage
		bit			wovrf;		// register window overflow
		bit			wundf;		// register window underflow
		bit			annul_next;	// annul next instruction (by BICC)
		bit [NREGADDRMSB:0]	rs1, rs2;	// register file address
		bit [NFPREGADDRMSB:0] fprs1, fprs2; //floating point regfile addresses
} reg_reg_type;			//pipeline register type for register file stage


typedef struct {	
	thread_state_type	ts;		                     // thread state
	//passed controls from decode stage
	bit			            annul_next;	              // annul next instruction (by BICC)		
	bit			            branch_true;	             // branch (for TICC)
	immu_data_type    immu_data;
	//decode result	from reg stage
	alu_dsp_in_type	  aludata;	                 // alu dsp data, dsp control + data
	fpu_data_type     fpudata;                  // fp alu control & data
	bit 			           op1_parity, op2_parity;		 // parity bit for op1, op2, used for software parity
	bit               ign_op1_seu, ign_op2_seu; // ignore op1/op2 SEU, because the register read out values are not used (e.g. use IMM) 
	bit			            wicc;		                   // update icc field	
	bit               wy;                       // update Y register
	bit [31:0]		      store_data;	              // data for ST
	bit			            adder_valid;	             // adder invalid (nop)
	bit			            mul_valid;	               // mul/div/shf invalid (nop)
	//detected trap
	trap_type		       tt;
	bit			            trap;		                   // trap is detected after register access stage
	bit			            ticc_trap;
} ex_reg_type;			// execution stage pipeline reg	bit			

//load/store indicator type	 
typedef enum bit [1:0] {c_LD = 2'b10, c_ST = 2'b01, c_FLUSH = 2'b11, NOMEM = 2'b00}	LDST_CTRL_TYPE;

typedef struct {
	thread_state_type	ts;		       //thread state
	bit			            invalid;	   //fops
        immu_data_type		immu_data;
	//passed from decode stage
	bit			            annul_next;	//annul next instruction (by BICC)		
	bit			            branch_true;//branch (for TICC)
	//passed from ex/alu stage
	bit [31:0]		      ex_res;		   //result from ALU
	bit [31:0]				    adder_res;
	//ldst control
	//LDST_CTRL_TYPE 		ldst;		//load store bit
	//bit			signext;	//signed extend load
	bit [31:0]		      store_data;	//data for ST, address is from ALU	
	//bit [3:0]		byte_mask;	//ldst byte mask
	//detected trap
	trap_type		       tt;
	bit	 		           trap;		     //trap is detected after execution stage
	bit			            ticc_trap;	 //ticc trap;
	//bit			psr_trap;	//psr illegal cwp trap
	bit			            tag_trap;	  //tag trap
	//bit			align_trap;	//address align trap
	bit			            divz_trap;	 //divide zero trap
	
	//floating point stuff
	bit                ieee754_trap;
	bit [63:0]         fp_ex_res;	
} mem_reg_type;				//memory stage register

//detected trap by final_exception
typedef struct {
	bit			     precise_trap;	//precise trap is detected after execution stage
	bit			     irq_trap;	    //interrupt is detected after excution stage	
	bit			     nodaex;		     //higher priority traps than daex
	bit [7:0]		tbr_tt;		     //tt field for TBR
}pre_trap_type;

typedef struct {
	thread_state_type	ts;		       //thread state		
	bit			            invalid;	   //fops
	//passed from decode stage
	bit			            annul_next;	//annul next instruction (by BICC)		
	bit			            branch_true;//branch (for TICC)
	//passed from ex/alu stage
	bit [31:0]		      ex_res;		   //result from ALU
	bit [63:0]        fp_ex_res;  //result from FPU
  bit [31:0]        io_res;     //result from I/O
  bit               io_op;      //indicates selecting from io_res
  
	//mem stage result;
	bit [63:0]		      mem_res;	   //64-bit load result from memory
	bit			            signext;	   //signed extend
	bit	[3:0]		       byte_mask;	 //byte_mask

	pre_trap_type		   trap_res;	  //trap result	
//	bit			tag_trap	//tag trap
//	bit			align_trap;	//address align trap
//	bit			divz_trap;	//divide zero trap
//	bit			daex_trap;	//data access exception (MMU exception)	
}xc_reg_type;				//exception stage register

typedef struct {
	bit [NREGADDRMSB:0]	op1_addr;		//first cycle read address
	bit [NREGADDRMSB:0]	op2_addr;		//second cycle read address	
}regfile_read_in_type;

typedef struct {
	bit [31:0]		op1_data;		//first cycle data;
	bit [31:0]		op2_data;		//second cycle data;
	bit [6:0]		op1_parity;		//first cycle parity;	partial bits
	bit [6:0]		op2_parity;		//second cycle parity;
}regfile_read_out_type;

typedef struct {
	bit [NREGADDRMSB:0]	ph1_addr;		//first cycle write address
	bit [NREGADDRMSB:0]	ph2_addr;		//second cycle write address
	bit [31:0]		ph1_data;		//first cycle data;
	bit [31:0]		ph2_data;		//second cycle data;
	bit [6:0]		ph1_parity;		//first cycle parity;	partial bits
	bit [6:0]		ph2_parity;		//second cycle parity;	
	bit 			ph1_we;			//first cycle WE	
	bit 			ph2_we;			//second cycle WE
}regfile_commit_type;

typedef struct {
	//architecture register
	bit [29:0]		     pc, npc;	        //pc, npc		
	bit			           pc_we, npc_we;	  //we for pc, npc
	
	psr_reg_type		   psr;		           //psr
	fsr_reg_type     fsr;             //fsr
  y_reg_type       y;               //y
	bit [NWIN-1:0]	  wim;		           //wim
	bit			           archr_we;	       //write enable for PSR (icc, pil, ef), WIM, Y, fsr
	bit              psr_we;
	//thread state
	bit			               run;		           //run bit, part of WE
	bit			               valid;		           //timing token valid bit from TM
  bit                  icmiss;          //icache miss bit
	bit 			              replay;		        //replay bit
	bit			               annul;	          //annul bit (annulled by bicc, but increment PC)
	bit			               ucmode;		        //micro code mode
	bit                  dma_mode;        //dma mode
	bit [NUPCMSB:0]      upc;		           //microcode pc
	bit [FLUSHIDXMSB:0]  flushidx;        //flush index	
	bit                  ts_we;           //write enable for everything else
}spr_commit_type;

typedef struct {
	regfile_commit_type	regf;			      //commit regfile
	fpregfile_commit_type  fpregf;    //commit fp regfile
	spr_commit_type		   spr;			       //commit special registers, e.g. psr, pc/npc
}commit_reg_type;

/////////////////////////////////////////////////////////////////////////////////////
//Error detection/correction statistics
typedef struct {
//	bit 	regfile_sbit;		//single-bit error is detected in Regfile
//	bit 	regfile_dbit;		//double-bit error is detected in Regfile
	bit	spr_sbit;		//single-bit error is detected in Regfile
	bit	spr_dbit;		//double-bit error is detected in Regfile
	bit	cache_sbit;		//single-bit error is detected in cache line	
	bit	cache_dbit;		//double-bit error is detected in cache line
	bit	tlb_sbit;		//single-bit error is detected in tlb
	bit	tlb_dbit;		//double-bit error is detected in tlb
} error_stat_type;

// reg address for rs1, rs2 and rd. rd will use new CWP for save and restore

function automatic bit [NREGADDRMSB:0] regaddr(bit [NTHREADIDMSB:0] threadid, bit [NWINMSB:0] cwp, bit [4:0] rs);
	bit [NREGADDRMSB:0] ra;
	bit [NWINMSB:0]	    pcwp;
	
	ra = '0;
	ra[NREGADDRMSB : NREGADDRMSB - NTHREADIDMSB] = threadid;	
	pcwp = (cwp == CWPMIN)? CWPMAX : cwp - 1; //previous cwp

	if (rs[4:3] == 2'b00) 	//Global register, move to a seperate bank later (e.g. FPU)
		ra[2:0] = rs[2:0];
	else begin
		// ra[NREGADDRMSB - NTHREADIDMSB - 1] = 1'b1;	//register window
		if (rs[4] == 1)	//r16 - r31
			ra[NREGADDRMSB - NTHREADIDMSB - 1:0] = { cwp + 1, rs[3:0]};
		else   	//r8-r15
			ra[NREGADDRMSB - NTHREADIDMSB - 1:0] = { pcwp + 1, 1'b1, rs[2:0]};  
		
	end
	
	return ra;
endfunction

`ifndef SYNP94
endpackage
`endif