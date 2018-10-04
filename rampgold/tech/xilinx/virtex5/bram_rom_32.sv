//----------------------------------------------------------------------------------------------------   
// File:        bram_rom_32.sv
// Author:      Zhangxi Tan
// Description: 32-bit wide BRAM rom for xilinx virtex 5, no ECC/parity protection.
//----------------------------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libiu::*;
import libcache::*;
`else
`include "../../../cpu/libiu.sv"
`include "../../../cpu/libmmu.sv"
`include "../../../cpu/libcache.sv"
`endif

//128-bit wide blockram memory
`ifndef SYNP94
module xcv5_bram_rom_32 #(parameter int ADDRMSB = 12)	//512 deep by default  
`else			      
module xcv5_bram_rom_32 #(parameter ADDRMSB = 12		//512 deep by default  
		   )		
`endif		  
		(input iu_clk_type gclk, input bit rst,
		 input  bit [ADDRMSB:0] 	addr,
		 output bit [31:0]		dout		//data out
    );
	
	bit [15:0]		rom_addr; 
	bit [31:0] 		tmp_do[8];           //wire

	generate
	 genvar 		i;		//loop variable
		
	 if (ADDRMSB == 10) begin

	  assign rom_addr = {1'b1, addr, 2'b11};
		
	  for (i=0;i<8;i++) begin
		  assign dout[i*4   +: 4] = tmp_do[i][3:0];
	  end

           RAMB36 #(					
              .DOA_REG(1), 
	      .DOB_REG(0),
	//		    .INIT_FILE("bram_0"),
		.READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
		.READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_0 (
            .DOA(tmp_do[0]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
		//			    .INIT_FILE("bram_1"),
					    .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
					    .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_1 (
            .DOA(tmp_do[1]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
			//		    .INIT_FILE("bram_2"),
					    .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
					    .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_2 (
            .DOA(tmp_do[2]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
			//		    .INIT_FILE("bram_3"),
					    .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
					    .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_3 (
            .DOA(tmp_do[3]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
			//		    .INIT_FILE("bram_4"),
					    .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
					    .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_4 (
            .DOA(tmp_do[4]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
			//		    .INIT_FILE("bram_5"),
					    .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
					    .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_5 (
            .DOA(tmp_do[5]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
		//			    .INIT_FILE("bram_6"),
					    .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
					    .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_6 (
            .DOA(tmp_do[6]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
//					    .INIT_FILE("bram_7"),
					    .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
					    .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            bm_7 (
            .DOA(tmp_do[7]), 
            .ADDRA(rom_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .WEA(4'b0), 
            .WEB(4'b0),
            //unconnected ports
            .SSRB(), 
            .DIA(),
            .CLKB(), 
            .ADDRB(),
            .DOB(),
            .DOPA(),
            .DOPB(),
            .CASCADEINLATA(),
            .CASCADEINREGA(),
            .CASCADEINLATB(),
            .CASCADEINREGB(),
            .CASCADEOUTLATA(),
            .CASCADEOUTREGA(),
            .CASCADEOUTLATB(),
            .CASCADEOUTREGB(),
            .DIPA(),
            .DIB(),
            .DIPB()
            );			

      `include "../../../../software/output/rom_0.v"
      `include "../../../../software/output/rom_1.v"
      `include "../../../../software/output/rom_2.v"
      `include "../../../../software/output/rom_3.v"
      `include "../../../../software/output/rom_4.v"
      `include "../../../../software/output/rom_5.v"
      `include "../../../../software/output/rom_6.v"
      `include "../../../../software/output/rom_7.v"
  end           
	endgenerate
endmodule
