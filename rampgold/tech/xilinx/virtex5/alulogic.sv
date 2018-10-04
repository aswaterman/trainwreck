//---------------------------------------------------------------------------   
// File:        alulogic.v
// Author:      Zhangxi Tan
// Description: alu adder/logic mappings for xilinx virtex 5	
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libiu::*;
import libopcodes::*;
import libconf::*;
`else
`include "../../../cpu/libiu.sv"
`endif

//Xilinx V5 ALU
//Only the result field is valid in the 1st cycle. The rest (flags) are valid in the following cycle

module xcv5_alu_adder_logic 				//SETHI will be handled by a ALU pass
(input  iu_clk_type gclk, input bit rst, 
 input  bit              valid,					 //is input valid 
 input  alu_dsp_in_type  alu_data,			//dsp input 
 output alu_dsp_out_type alu_res,
 output bit [31:0]       raw_alu_res);			//dsp output
  

bit [47:0] op1, op2;			   //sign extened op1
bit [47:0] res;					      //dsp data output

typedef struct {
	bit 		             op1_31, op2_31;		 //the highest bit of op1 and op2, for
	bit	[1:0]		        op1_tag, op2_tag;	//tag bits
	//alu_gen_flag_type	 genflag;
	bit [$bits(alu_gen_flag_type)-1:0] genflag;
} add_logic_input_reg_type;

//(* syn_keep=1 *) add_logic_reg_type	delr;		//pipeline register inside ALU, must match the DSP pipeline
(*syn_preserve=1*)add_logic_input_reg_type	delr;		//extra input register

alu_dsp_out_type  v_alu_res;    //combinatorial 

//DSP is double clocked
bit			C, V, tempV, Z;
bit			tag_overflow;

//assign op1 = {{16{alu_data.op1[31]}},alu_data.op1};
//assign op2 = {{16{alu_data.op2[31]}},alu_data.op2};
assign op1 = signed'(alu_data.op1);
assign op2 = signed'(alu_data.op2);

 //generate dsp flag in the 2nd cycle
 always_comb begin
 //initial values
	v_alu_res.divz         = '0;			 //unused
	v_alu_res.parity_error = '0;    //unused
	v_alu_res.y            = init_y;
	v_alu_res.wry          = '0;
	
	tag_overflow     = '0;			   
	v_alu_res.valid  = valid;      //simply pass through the valid signal
	v_alu_res.result = res;
	

	tempV = |{delr.op1_tag, delr.op2_tag};

	unique case (delr.genflag)
		ADDcc, TADDcc, TADDccTV:	begin			//multstep is encoded as ADDcc
			V = (delr.op1_31 & delr.op2_31 & (!res[31])) | 
			    ((!delr.op1_31) & (!delr.op2_31) & res[31]);

			if (NOTAG == 0 && ((delr.genflag == TADDcc) || (delr.genflag == TADDccTV)))
				V = V | tempV;
			
			tag_overflow = (delr.genflag == TADDccTV) ? V : '0;	

			C = (delr.op1_31 & delr.op2_31) | ((!res[31]) & (delr.op1_31 | delr.op2_31));
			end
		SUBcc, TSUBcc, TSUBccTV:	begin
			V = (delr.op1_31 & (!delr.op2_31) & (!res[31])) | 
					 ((!delr.op1_31) & delr.op2_31 & res[31]);

			if (NOTAG == 0 && ((delr.genflag == TSUBcc) || (delr.genflag == TSUBccTV)))
				V = V | tempV;
	
			tag_overflow = (delr.genflag == TSUBccTV) ? V : '0;	
			
			C = ((!delr.op1_31) & delr.op2_31) | (res[31] & ((!delr.op1_31) | delr.op2_31));
			end
		default : begin
			C = '0;		//don't care
			V = '0;
			end
	endcase
	
	v_alu_res.flag.C = C; 
	v_alu_res.flag.V = V;
	v_alu_res.flag.Z = Z;
	v_alu_res.flag.N = res[31];
	v_alu_res.tag_overflow = tag_overflow;
 end

//extra input registers (others are covered by internal DSP registers)
 always_ff @(posedge gclk.clk)  begin
	delr.genflag <= alu_data.al.genflag;
	delr.op1_31  <= alu_data.op1[31];
	delr.op2_31  <= alu_data.op2[31];

	if (NOTAG == 1) begin
		delr.op1_tag <= '0; delr.op2_tag <= '0;	//These registers should be optimized by synthesis tool
	end
	else begin
		delr.op1_tag <= alu_data.op1[1:0];
		delr.op2_tag <= alu_data.op2[1:0];
	end	
 end

/*
 //dsp output register
 always @(posedge gclk.clk) begin
  alu_res = v_alu_res;
  if (rst) alu_res.valid = '0;
 end
*/ 

function automatic alu_dsp_out_type get_alu_res();
  alu_dsp_out_type  alu_res_ret;
  alu_res_ret = v_alu_res;
  
  if (rst) alu_res_ret.valid = '0;
    
  return alu_res_ret;   
endfunction

//dsp output register
assign raw_alu_res = res[31:0];
always_ff @(posedge gclk.clk) begin
 alu_res <= get_alu_res();
end

 DSP48E #(
	.ALUMODEREG(1),
	.AREG(1),
	.BREG(1),
	.CARRYINREG(1),
	.CARRYINSELREG(1),
	.CREG(1),
	.MASK(48'hFFFF00000000),
	.MREG(0),
	.OPMODEREG(1),
	.PATTERN(48'h000000000000),
	.PREG(1),
	.SEL_MASK("MASK"),
	.SEL_PATTERN("PATTERN"),
	.USE_MULT("NONE"),
	.USE_PATTERN_DETECT("PATDET"),
	.USE_SIMD("ONE48")
	)
   adder_logic(
	.A(op2[47:18]), 
	.B(op2[17:0]),
	.C(op1),
	.ALUMODE(alu_data.al.dsp_ctrl.alumode),
	.CARRYIN(alu_data.carryin),
	.CARRYINSEL(3'b0),
	.CEA1(1'b0),
	.CEA2(1'b1),		
	.CEALUMODE(1'b1),
	.CEB1(1'b0),
	.CEB2(1'b1),	
	.CEC(1'b1),
	.CECARRYIN(1'b1),
	.CECTRL(1'b1),
//	.CEM(1'b1),
  .CEM(1'b0),         //save power when MREG is not used
	.CEMULTCARRYIN(1'b1),	
	.CEP(1'b1),
	.CLK(gclk.clk2x),			//2x clock
	.OPMODE(alu_data.al.dsp_ctrl.opmode),
	.RSTA(rst),
	.RSTALLCARRYIN(rst),
	.RSTALUMODE(rst),
	.RSTB(rst),
	.RSTC(rst),
	.RSTCTRL(rst),
	.RSTP(rst),
	.RSTM(1'b0),
	.P(res),
	.PATTERNDETECT(Z),
	//unconnected ports
	.ACIN(),
	.BCIN(),
	.CARRYCASCIN(),
	.MULTSIGNIN(),
	.PCIN(),
	.ACOUT(),
	.BCOUT(),
	.CARRYCASCOUT(),
	.CARRYOUT(),
	.MULTSIGNOUT(),
	.OVERFLOW(),
	.PATTERNBDETECT(),
	.PCOUT(),
	.UNDERFLOW()	
	);	
endmodule