//---------------------------------------------------------------------------   
// File:        fpregfile.v
// Author:      Zhangxi Tan (slightly modified by Rimas Avizienis)
// Description: regfile mapping for xilinx virtex 5	
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libconf::*;
import libiu::*;
import libfp::*;
`else
`include "../../../cpu/libiu.sv"
`endif

//       regr                           delr1                 delr2
//         _______        _______        _______        _______
// clk2x  |       |      |       |      |       |      |       |
//                --------       --------       --------       --------
// addr latch            op1           op2
// result                                op1            op2
// rfo                                           <---------op1(neg)--------->
//                                                       <-op2(no reg)

//double clocked main register file, 2x read, 1x write
module xcv5_fpregfile (input iu_clk_type gclk, input rst, input fpregfile_read_in_type rfi, output fpregfile_read_out_type rfo, input fpregfile_commit_type rfc);
	bit [15:0] raddr;			//time multiplexed read regfile address
	bit [15:0] waddr; 		//write regfile address
	bit [63:0] rdata; 		//time multiplexed read regfile data
	bit [63:0] wdata;			//write regfile data	
	
	bit [6:0]  rparity1, rparity2;
	bit [6:0]  wparity1, wparity2;
	bit [3:0]  we1, we2;

	bit [31:0] op1, op2, op3, op4;
	bit [6:0]  op1_parity, op2_parity, op3_parity, op4_parity;
	bit op1_addr_lsb, op2_addr_lsb;
	
	//always_comb begin
	always_comb begin
    //default values
    raddr = '1;
    waddr = '1;
    wdata = '0;

    waddr[14:5] = rfc.ph_addr[NFPREGADDRMSB:1];
    wdata = {rfc.ph2_data, rfc.ph1_data};
    wparity1 = rfc.ph1_parity;	//only highest 4 check bits are saved in BRAM
    wparity2 = rfc.ph2_parity;
    we1 = signed'(rfc.ph1_we);	
    we2 = signed'(rfc.ph2_we);

		//software parity and no protection
		//clock 2x logic
		if (gclk.ce == 0) 	//second cycle
			//read address	
			raddr[14:5] = rfi.op1_addr[NFPREGADDRMSB:1];						
		else //read address
			raddr[14:5] = rfi.op2_addr[NFPREGADDRMSB:1];				
	end	

  assign op3 = rdata[31:0];
  assign op4 = rdata[63:32];
  assign op3_parity = (BRAMPROT > 0)? rparity1 : '0;
  assign op4_parity = (BRAMPROT > 0)? rparity2 : '0;

	always_ff @(negedge gclk.clk) begin	//latch op1 at negedge of clk
		op1        <= rdata[31:0];
		op2        <= rdata[63:32];
		op1_parity <= (BRAMPROT >0 )? rparity1 : '0;
		op2_parity <= (BRAMPROT >0 )? rparity2 : '0;
	end
	
	always_ff @(posedge gclk.clk) begin
	   op1_addr_lsb <= rfi.op1_addr[0];
	   op2_addr_lsb <= rfi.op2_addr[0];
	end
	
	always_comb begin
	  if (op1_addr_lsb) begin
	     rfo.op1_data = op2;
	     rfo.op1_parity = op2_parity;
	  end
	  else begin
	     rfo.op1_data = op1;
	     rfo.op1_parity = op1_parity;
	  end
	  
	  rfo.op2_data = op2;
	  rfo.op2_parity = op2_parity;
	  
	  if (op2_addr_lsb) begin
	     rfo.op3_data = op4;
	     rfo.op3_parity = op4_parity;
	  end
	  else begin
	     rfo.op3_data = op3;
	     rfo.op3_parity = op3_parity;
	  end
	  
	  rfo.op4_data = op4;
	  rfo.op4_parity = op4_parity;
	end
  
  
		      		RAMB36 #(
					.DOA_REG(1), 
					.DOB_REG(0),
					.READ_WIDTH_A(36), .WRITE_WIDTH_A(36), 
					.READ_WIDTH_B(36), .WRITE_WIDTH_B(36)
//					.SIM_MODE("FAST")
				) fpregfile_0 (
				.DOA(rdata[31:0]), 
				.DOPA(rparity1[6:3]),
	      .ADDRA(raddr), 
				.ADDRB(waddr), 
				.CLKA(gclk.clk2x), 
				.CLKB(gclk.clk), 
				.DIB(wdata[31:0]), 				
				.DIPB(wparity1[6:3]), 
				.ENA(1'b1), 
				.ENB(1'b1), 
				.REGCEA(1'b1), 	//enable DOA register clock
				.REGCEB(1'b0),  //disable DOB register clock
				.SSRA(rst), 
				.SSRB(rst), 
				.WEA(4'b0), 
				.WEB(we1),
				//unconnected ports
				.CASCADEINLATA(),
				.CASCADEINREGA(),
				.CASCADEINLATB(),
				.CASCADEINREGB(),
				.CASCADEOUTLATA(),
				.CASCADEOUTREGA(),
				.CASCADEOUTLATB(),
				.CASCADEOUTREGB(),
				.DIA(),
				.DIPA(),
				.DOB(),
				.DOPB()
				);
				

		      		RAMB36 #(
					.DOA_REG(1), 
					.DOB_REG(0),
					.READ_WIDTH_A(36), .WRITE_WIDTH_A(36), 
					.READ_WIDTH_B(36), .WRITE_WIDTH_B(36)
//					.SIM_MODE("FAST")
				) fpregfile_1 (
				.DOA(rdata[63:32]), 
				.DOPA(rparity2[6:3]),
	      .ADDRA(raddr), 
				.ADDRB(waddr), 
				.CLKA(gclk.clk2x), 
				.CLKB(gclk.clk), 
				.DIB(wdata[63:32]), 				
				.DIPB(wparity2[6:3]), 
				.ENA(1'b1), 
				.ENB(1'b1), 
				.REGCEA(1'b1), 	//enable DOA register clock
				.REGCEB(1'b0),  //disable DOB register clock
				.SSRA(rst), 
				.SSRB(rst), 
				.WEA(4'b0), 
				.WEB(we2),
				//unconnected ports
				.CASCADEINLATA(),
				.CASCADEINREGA(),
				.CASCADEINLATB(),
				.CASCADEINREGB(),
				.CASCADEOUTLATA(),
				.CASCADEOUTREGA(),
				.CASCADEOUTLATB(),
				.CASCADEOUTREGB(),
				.DIA(),
				.DIPA(),
				.DOB(),
				.DOPB()
				);				
				
endmodule
