//---------------------------------------------------------------------------   
// File:        libtech.v
// Author:      Zhangxi Tan
// Description: Technology header files 		
//---------------------------------------------------------------------------

`ifndef SYNP94
package libtech;
`endif

typedef enum bit {xilinx_virtex5, altera_stratix3} fpgatech_type;

//`ifdef XILINX
//	`ifdef VIRTEX5
	
	//xilinx v5 dsp control signals
	typedef struct {
		logic [6:0]	opmode;	
		logic [3:0]	alumode;	
	}dsp_ctrl_type;		

	//DSP control codes

	const dsp_ctrl_type		DSP_ADDC = '{7'b0110011, 4'b0000};	//A:B + C + CIN;
	const dsp_ctrl_type		DSP_OP2  = '{7'b0000011, 4'b0000};	//A:B + 0 + CIN;
	const dsp_ctrl_type		DSP_SUBC = '{7'b0110011, 4'b0011};	//C-(A:B + CIN);
	const dsp_ctrl_type		DSP_AND  = '{7'b0110011, 4'b1100};	//A:B and C
	const dsp_ctrl_type		DSP_ANDN = '{7'b0111011, 4'b1111};	//(not A:B) and C
	const dsp_ctrl_type		DSP_OR   = '{7'b0111011, 4'b1100};	//A:B or C
	const dsp_ctrl_type		DSP_ORN  = '{7'b0110011, 4'b1111};	//(not A:B) or C
	const dsp_ctrl_type		DSP_XNOR = '{7'b0110011, 4'b0101};	//A:B xnor C
	const dsp_ctrl_type		DSP_XOR  = '{7'b0110011, 4'b0111};	//A:B xor C
	const dsp_ctrl_type		DSP_OP1  = '{7'b0001100, 4'b0000};	// 0 + C + CIN
	
	const dsp_ctrl_type  DSP_MUL1 = '{7'b0000101, 4'b0000}; //M + 0
	const dsp_ctrl_type  DSP_MUL2 = '{7'b1100101, 4'b0000}; //M + (P >> 17)
	const dsp_ctrl_type  DSP_MUL3 = '{7'b0100101, 4'b0000}; //M + P
	const dsp_ctrl_type  DSP_MUL4 = '{7'b1100101, 4'b0000}; //M + (P >> 17)
//	`endif
//`endif

`ifndef SYNP94
typedef union packed{
`else
typedef struct packed {
`endif
  struct packed{
    bit clk0;     //mig system clock
    bit clk90;
    bit clkdiv0;    
    bit clk200;   //mig IDELAY 200MHz clock
    
    bit rst0;     //resets
    bit rst90;
    bit rstdiv0;
    bit rst200;
  }mig;       //xilinx MIG style clock

  struct packed{
    bit mclk;
    bit mclk90;
    bit clk;
    bit ph0;
    bit rst;
    bit rstTC5;
    bit [1:0] padding;
  }bee3;
}dram_clk_type;

`ifndef SYNP94
endpackage
`endif
