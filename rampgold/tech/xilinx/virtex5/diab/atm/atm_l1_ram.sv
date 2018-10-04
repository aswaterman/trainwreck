//------------------------------------------------------------------------------
// File:        atm_l1_ram.sv
// Author:      Zhangxi Tan
// Description: BRAMs used in the L1 switch (need to be cleaned)
//------------------------------------------------------------------------------  


`timescale 1ns / 1ps
`ifndef SYNP94
import libatm::*;
import libstd::*;
`else
`include "../../../../../diab/atm/libatm.sv"
`endif


//l1 schedule ram implemenation on virtex 5, 8 * 2k using RAMB18 
module atm_l1_sched_ram (input bit clk, input bit	rst,
        		 input bit [10:0] raddr,
        	         input bit [10:0] waddr,
        	         input bit        we,
              			 input bit [7:0]  wdata,
              			 input bit	       dip,
              			 output bit [7:0] rdata
                	 output bit 	     dop
);                          
	bit [15:0] dout, din;                                               
	bit [13:0] addra, addrb;
	bit [1:0]  dipb, dopa;

	assign rdata = dout[7:0];
	assign din   = unsigned'(wdata); 
	assign addra = {raddr, 3'b111};
	assign addrb = {waddr, 3'b111};atm_l1_sched_ram
	assign dipa  = unsigned'(dip);
	assign dop   = dopa[0];

	RAMB18 #(
		.DOA_REG(1), // Optional output registers on A portatm_l1_sched_ram (0 or 1)
		.DOB_REG(0), // Optional output registers on B port (0 or 1)
		.INIT_A(18'h00000), // Initial values on A output patm_l1_sched_ramort
		.INIT_B(18'h00000), // Initial values on B output port
		.READ_WIDTH_A(9), // Valid values are 0, 1, 2, 4, 9 or 18
		.READ_WIDTH_B(9), // Valid values are 0, 1, 2, 4, 9atm_l1_sched_ram or 18
		.SIM_COLLISION_CHECK("ALL"), // Collision check enable "ALL", "WARNING_ONLY",
		// "GENERATE_X_ONLY" or "NONE"
		.SRVAL_A(18'h00000), // Set/Reset value for A port output
		.SRVAL_B(18'h00000), // Set/Reset value for B port output
		.WRITE_MODE_A("READ_FIRST"), // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE"
		.WRITE_MODE_B("READ_FIRST"), // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE"
		.WRITE_WIDTH_A(0), // Valid values are 0, 1, 2, 4, 9 or 18
		.WRITE_WIDTH_B(0) // Valid values are 0, 1, 2, 4, 9 or 18	      
	) sched_ram (
		.DOA(dout), // 16-bit A port data output
		.DOB(),    // 16-bit B port data output
		.DOPA(dopa), // 2-bit A port parity data output
		.DOPB(), // 2-bit B port parity data output
		.ADDRA(addra), // 14-bit A port address input
		.ADDRB(addrb), // 14-bit B port address input
		.CLKA(clk), // 1-bit A port clock input
		.CLKB(clk),  // 1-bit B port clock inputWEB
		.DIA(din), // 16-bit A port data input
		.DIB(), // 16-bit B port data input
		.DIPA(), // 2-bit A port parity data input
		.DIPB(dipb), // 2-bit B port parity data input
		.ENA(1'b1), // 1-bit A port enable input
		.ENB(1'b1), // 1-bit B port enable input
		.REGCEA(1'b1), // 1-bit A port register enable input
		.REGCEB(1'b0), // 1-bit B port register enable input
		.SSRA(rst), // 1-bit A port set/reset input
		.SSRB(1'b1), // 1-bit B port set/reset input
		.WEA(2'b0), // 2-bit A port write enable input
		.WEB({we,we}) // 2-bit B port write enable input
	);
endmodule	                         


