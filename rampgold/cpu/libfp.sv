// libfp.sv

`timescale 1ns / 1ps

`ifndef SYNP94
package libfp;
import libconf::*;
`endif

parameter int FP_ADD_LATENCY = 14;      // latency of the coregen fp adder
parameter int FP_MULT_LATENCY = 16;     // latency of the coregen fp multiplier
parameter int FP_CMP_LATENCY = 2;       // latency of the coregen fp comparator
parameter int FP_CONV_SP_DP_LATENCY = 2;// latency of the coregen sp->dp conversion module
parameter int FP_CONV_DP_SP_LATENCY = 3;// latency of the coregen dp->sp conversion module
parameter int FP_CONV_FLOAT_INT_LATENCY = 6; // latency of the floating point to integer conversion modules

typedef bit [4:0] fp_add_ctrl_type;

const bit [4:0] FP_CTRL_ADD = 5'b00000;
const bit [4:0] FP_CTRL_SUB = 5'b00001;

typedef bit [3:0] fp_op_type;

const bit [3:0] FP_NONE = 4'b0000;
const bit [3:0] FP_ADD  = 4'b0001;
const bit [3:0] FP_SUB  = 4'b0010;
const bit [3:0] FP_CMP  = 4'b0011;
const bit [3:0] FP_MUL  = 4'b0100;
const bit [3:0] FP_MOV  = 4'b0101;
const bit [3:0] FP_NEG  = 4'b0110;
const bit [3:0] FP_ABS  = 4'b0111;

const bit [3:0] FP_ITOS = 4'b1000;
const bit [3:0] FP_ITOD = 4'b1001;
const bit [3:0] FP_STOI = 4'b1010;
const bit [3:0] FP_DTOI = 4'b1011;
const bit [3:0] FP_STOD = 4'b1100;
const bit [3:0] FP_DTOS = 4'b1101;

const bit [2:0] FPEXC_NVBIT = 3'd4;
const bit [2:0] FPEXC_OFBIT = 3'd3;
const bit [2:0] FPEXC_UFBIT = 3'd2;
const bit [2:0] FPEXC_DZBIT = 3'd1;
const bit [2:0] FPEXC_NXBIT = 3'd0;

typedef struct {
        bit [NFPREGADDRMSB:0]        op1_addr;                //first cycle read address
        bit [NFPREGADDRMSB:0]        op2_addr;                //second cycle read address
}fpregfile_read_in_type;

typedef struct {
        bit [31:0]                op1_data;                //first cycle data;
        bit [31:0]                op2_data;
        bit [31:0]                op3_data;                //second cycle data;
        bit [31:0]                op4_data;
        bit [6:0]                op1_parity;                //first cycle parity;
        bit [6:0]                op2_parity;
        bit [6:0]                op3_parity;                //second cycle parity;
        bit [6:0]                op4_parity;
}fpregfile_read_out_type;

typedef struct {
        bit [NFPREGADDRMSB:0]    ph_addr;
        bit [31:0]               ph1_data;
        bit [31:0]               ph2_data;
        bit [6:0]                ph1_parity;
        bit [6:0]                ph2_parity;
        bit                      ph1_we;
        bit                      ph2_we;              
}fpregfile_commit_type;

/*
typedef struct packed {
  bit nv; // invalid operand
  bit of; // overflow
  bit uf; // underflow
  bit dz; // divide by zero
  bit nx; // not exact
 } fp_exception_type;
*/

typedef struct packed {
  bit	[1:0]	rd; 	// rounding direction
  bit	[4:0]	tem;	// trap enable mask
  bit 		ns;	// nonstandard fp
  bit	[2:0]	ftt;	// fp trap type
  bit 	[1:0]	fcc;	// fp condition codes
  bit 	[4:0]	aexc;	// accrued exception
  bit	[4:0]	cexc;	// current exception
} fsr_reg_type;

`ifdef SYNP94
const fsr_reg_type init_fsr = {2'b00, 5'b0000, 1'b0, 3'b000, 2'b00, 5'b00000, 5'b00000};
`else
const fsr_reg_type init_fsr = '{0, 0, 0, 0, 0, 0, 0};
`endif

typedef struct {
  bit [31:0] op1, op2, op3, op4;
  bit op1_parity, op2_parity, op3_parity, op4_parity;
  fp_op_type fp_op;
  bit sp_ops;           // input ops are single precision
  bit sp_result;        // result is single precision
} fpu_data_type;

typedef struct {
  bit [NTHREADIDMSB:0] tid;
  bit [63:0]		op1, op2;
  fp_op_type fp_op;
  bit sp_ops;
  bit sp_result; 
  bit replay;
} fpu_in_type;

typedef struct {
  bit [63:0]    result;
  bit           overflow;
  bit           underflow;
  bit           invalid_op;
} fpu_fpop_out_type;

typedef struct {
  bit [3:0]     cc;         // condition code
  bit           invalid_op;
} fpu_fcmp_out_type;

typedef struct {
  fpu_fpop_out_type   fpop_result;  // multiply/add/move/negate/convert result
  fpu_fcmp_out_type   fcmp_result;  // compare result
} fpu_out_type;

typedef struct {
  fpu_fpop_out_type    data;
  bit [NTHREADIDMSB:0]	 tid;				    //thread id
  bit                   valid;      //output valid
} fpu_fpop_fu_out_type; 

typedef struct {
  fpu_fcmp_out_type    data;
  bit [NTHREADIDMSB:0]	 tid;				    //thread id
  bit                   valid;      //output valid
} fpu_fcmp_fu_out_type; 

`ifndef SYNP94
endpackage
`endif