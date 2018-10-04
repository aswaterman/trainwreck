//---------------------------------------------------------------------------   
// File:        simdma_rom.sv
// Author:      Zhangxi Tan
// Description: 32-bit 32KB ROM for simdma. ROM output registers are disabled
//				for the sake of simplicity.
//---------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libiu::*;
`else
`include "../../../cpu/libiu.sv"
`endif

module xcv5_simdma_init_rom(input iu_clk_type gclk, input bit rst,
					   input  bit [15:0]	raddr,
					   output bit [31:0]	dout);

	bit [31:0] 		tmp_do[8];           //wire

	always_comb begin

		for (int i=0;i<8;i++) 
			dout[i*4   +: 4] = tmp_do[i][3:0];
	end

	RAMB36 #(					
            .DOA_REG(0), 							
       			  .DOB_REG(0),
			//.INIT_FILE("init_rom_0"),
       			  .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
       			  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_0 (
            .DOA(tmp_do[0]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0), 
             //unconnected ports
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
           .DOA_REG(0), 							
			     .DOB_REG(0),
			//.INIT_FILE("init_rom_1"),
      			  .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
      			  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_1 (
            .DOA(tmp_do[1]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0), 
            //unconnected ports
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
           .DOA_REG(0), 							
      			  .DOB_REG(0),
			//.INIT_FILE("init_rom_2"),
      			  .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
      			  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_2 (
            .DOA(tmp_do[2]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0), 
            //unconnected ports
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
              .DOA_REG(0), 							
          		  .DOB_REG(0),
			//.INIT_FILE("init_rom_3"),
          		  .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
          		  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_3 (
            .DOA(tmp_do[3]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0),           
            //unconnected ports
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
              .DOA_REG(0), 							
          		  .DOB_REG(0),
  			//.INIT_FILE("init_rom_4"),
		          .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
          		  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_4 (
            .DOA(tmp_do[4]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0),            
            //unconnected ports
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
            .DOA_REG(0), 							
        		  .DOB_REG(0),
			//.INIT_FILE("init_rom_5"),
        		  .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
        		  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_5 (
            .DOA(tmp_do[5]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0),             
            //unconnected ports
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
              .DOA_REG(0), 							
          		  .DOB_REG(0),
			//.INIT_FILE("init_rom_6"),
          		  .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
          		  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_6 (
            .DOA(tmp_do[6]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0),            
            //unconnected ports
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
            .DOA_REG(0), 							
        		  .DOB_REG(0),
			//.INIT_FILE("init_rom_7"),
        		  .READ_WIDTH_A(4), .WRITE_WIDTH_A(4), 
        		  .READ_WIDTH_B(4), .WRITE_WIDTH_B(4)
              )	
            rom_7 (
            .DOA(tmp_do[7]), 
            .ADDRA(raddr), 
            .CLKA(gclk.clk), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b0), 	//disable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock            
            .WEA(4'b0), 
            .WEB(4'b0),
            .SSRA(1'b0), 
            .SSRB(1'b0),             
            //unconnected ports
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
		
      `include "../../../../software/output/init_rom.v"

           
        
endmodule     
