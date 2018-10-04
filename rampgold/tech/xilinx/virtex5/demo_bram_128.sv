//---------------------------------------------------------------------------   
// File:        demo_bram_128.sv
// Author:      Zhangxi Tan
// Description: 128-bit wide bram memory for Parlab retreat demo
//---------------------------------------------------------------------------
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
module demo_bram_128 #(parameter int dataprot = 2,	//data are protected with ecc
			      parameter int ADDRMSB = 8)		//512 deep by default  
`else			      
module demo_bram_128 #(parameter dataprot = 2,	//data are protected with ecc
			      parameter ADDRMSB = 8		//512 deep by default  
		   )		
`endif		  
		(input iu_clk_type gclk, input bit rst,
		 input  bit [ADDRMSB:0] 	addr,
		 input  bit 		           we,		 //write enable
		 input  cache_data_type 	din,		//data in
		 output cache_data_type  dout,		//data out
		 
		 input 	[127:0]	BRAM_DINB,
		 output	[127:0]	BRAM_DOUTB,
		 input	[10:0]	BRAM_ADDRB,
		 input			BRAM_CLKB,
		 input			BRAM_SSRB,
		 input	[7:0]	BRAM_WEB
		 
    );
	bit [1:0]	sberr, dberr;	
	
	//wire
	cache_data_type w_dout;		       //data out
	
	bit [15:0] w_addr;
  bit [31:0] tmp_do[8], tmp_dob[8];           //wire
  
  always_comb begin
    dout.ecc_error.dberr = |dberr;
    dout.ecc_error.sberr = |sberr;

    dout.data.I       = w_dout.data.D;
    dout.data.D       = w_dout.data.D;
    dout.ecc_parity.I = w_dout.ecc_parity.D;
    dout.ecc_parity.D = w_dout.ecc_parity.D;
  end

	generate
		genvar 		i;		//loop variable
		
//		case(dataprot)	//protect with ecc by default	(8K configuration)			
//		default: begin			
	   if (dataprot == 2 && ADDRMSB == 8) begin
		  //`ifdef MODEL_TECH    //used in simulation
		  `ifndef ZEROBRAM
	     // RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"), .INIT_FILE("bram_0"), .SIM_MODE("SAFE"))	
	        RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"), .INIT_FILE("bram_0"), .SIM_MODE("FAST"))	
		      bm_0 (
		      .DBITERR(dberr[0]),
		      .SBITERR(sberr[0]), 
		      .DO(w_dout.data.D[63:0]), 
		      .DOP(w_dout.ecc_parity.D[7:0]), 					  
			    .DI(din.data.D[63:0]),
		      .DIP(din.ecc_parity.D[7:0]),		//no use 
		      .RDADDR(addr), 
		      .RDCLK(gclk.clk2x), 
		      .RDEN(1'b1), 
		      .REGCE(1'b1), 
		      .SSR(1'b0), 
		      .WE({8{we}}), 
		      .WRADDR(addr), 
		      .WRCLK(gclk.clk2x), 
		      .WREN(!gclk.ce),				//write at the posedge
		      //unconnnected ports
		      .ECCPARITY()
		      );			

		    //RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"), .INIT_FILE("bram_1"), .SIM_MODE("SAFE"))	
		      RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"), .INIT_FILE("bram_1"), .SIM_MODE("FAST"))	
		      bm_1 (
		      .DBITERR(dberr[1]),
		      .SBITERR(sberr[1]), 
		      .DO(w_dout.data.D[127:64]), 
		      .DOP(w_dout.ecc_parity.D[15:8]), 					  
			    .DI(din.data.D[127:64]),
		      .DIP(din.ecc_parity.D[15:8]),		//no use 
		      .RDADDR(addr), 
		      .RDCLK(gclk.clk2x), 
		      .RDEN(1'b1), 
		      .REGCE(1'b1), 
		      .SSR(1'b0), 
		      .WE({8{we}}), 
		      .WRADDR(addr), 
		      .WRCLK(gclk.clk2x), 
		      .WREN(!gclk.ce),				//write at the posedge
		      //unconnnected ports
		      .ECCPARITY()
		      );			
          
		  `else
 
      		for (i=0;i<2;i++) begin                
				RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"))	
					bm (
					.DBITERR(dberr[i]),
					.SBITERR(sberr[i]), 
					.DO(w_dout.data.D[63+i*64:i*64]), 
					.DOP(w_dout.ecc_parity.D[i*8+7:i*8]), 					  
		  			.DI(din.data.D[63+i*64:i*64]),
					.DIP(din.ecc_parity.D[i*8+7:i*8]),		//no use 
					.RDADDR(addr), 
					.RDCLK(gclk.clk2x), 
					.RDEN(1'b1), 
					.REGCE(1'b1), 
					.SSR(1'b0), 
					.WE({8{we}}), 
					.WRADDR(addr), 
					.WRCLK(gclk.clk2x), 
					.WREN(!gclk.ce),				//write at the posedge
					//unconnnected ports
					.ECCPARITY()
					);			
			  end
	
			`endif
	
			end
			else if (ADDRMSB == 10) begin
          assign w_addr = {1'b1,addr, 4'b1111};
          
          assign BRAM_DOUTB[0   +: 16] = tmp_dob[0][15:0];
          assign BRAM_DOUTB[16  +: 16] = tmp_dob[1][15:0];
          assign BRAM_DOUTB[32  +: 16] = tmp_dob[2][15:0];
          assign BRAM_DOUTB[48  +: 16] = tmp_dob[3][15:0];
          assign BRAM_DOUTB[64  +: 16] = tmp_dob[4][15:0];
          assign BRAM_DOUTB[80  +: 16] = tmp_dob[5][15:0];
          assign BRAM_DOUTB[96  +: 16] = tmp_dob[6][15:0];
          assign BRAM_DOUTB[112 +: 16] = tmp_dob[7][15:0];
 
          assign w_dout.data.D[0   +: 16] = tmp_do[0][15:0];
          assign w_dout.data.D[16  +: 16] = tmp_do[1][15:0];
          assign w_dout.data.D[32  +: 16] = tmp_do[2][15:0];
          assign w_dout.data.D[48  +: 16] = tmp_do[3][15:0];
          assign w_dout.data.D[64  +: 16] = tmp_do[4][15:0];
          assign w_dout.data.D[80  +: 16] = tmp_do[5][15:0];
          assign w_dout.data.D[96  +: 16] = tmp_do[6][15:0];
          assign w_dout.data.D[112 +: 16] = tmp_do[7][15:0];
          

		  assign BRAM_DOUTB[0   +: 16] = tmp_dob[0][15:0];
          assign BRAM_DOUTB[16  +: 16] = tmp_dob[1][15:0];
          assign BRAM_DOUTB[32  +: 16] = tmp_dob[2][15:0];
          assign BRAM_DOUTB[48  +: 16] = tmp_dob[3][15:0];
          assign BRAM_DOUTB[64  +: 16] = tmp_dob[4][15:0];
          assign BRAM_DOUTB[80  +: 16] = tmp_dob[5][15:0];
          assign BRAM_DOUTB[96  +: 16] = tmp_dob[6][15:0];
          assign BRAM_DOUTB[112 +: 16] = tmp_dob[7][15:0];
        
        // `ifdef MODEL_TECH    //used in simulation
        `ifndef ZEROBRAM
           RAMB36 #(					
              .DOA_REG(1), 
			  .DOB_REG(1),
			//		    .INIT_FILE("bram_0"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_0 (
            .DOA(tmp_do[0]), 
            .DOB(tmp_dob[0]),
            .DIA({16'b0, din.data.D[0 +: 16]}),
            .DIB({16'b0, BRAM_DINB[0 +: 16]}),
            .ADDRA(w_addr), 
            .ADDRB({1'b1,BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[0]}}),
            //unconnected ports
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
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
			  .DOB_REG(1),
		//			    .INIT_FILE("bram_1"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_1 (
            .DOA(tmp_do[1]), 
            .DOB(tmp_dob[1]),
            .DIA({16'b0, din.data.D[16 +: 16]}),
            .DIB({16'b0, BRAM_DINB[16 +: 16]}),
            .ADDRA(w_addr), 
            .ADDRB({1'b1, BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[1]}}),
            //unconnected ports
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
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
			  .DOB_REG(1),
			//		    .INIT_FILE("bram_2"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_2 (
            .DOA(tmp_do[2]), 
            .DOB(tmp_dob[2]), 
            .DIA({16'b0, din.data.D[32 +: 16]}),
            .DIB({16'b0, BRAM_DINB[32 +: 16]}),
            .ADDRA(w_addr), 
            .ADDRB({1'b1, BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[2]}}),
            //unconnected ports
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
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
			  .DOB_REG(1),
			//		    .INIT_FILE("bram_3"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_3 (
            .DOA(tmp_do[3]), 
            .DOB(tmp_dob[3]),
            .DIA({16'b0, din.data.D[48 +: 16]}),
            .DIB({16'b0, BRAM_DINB[48 +: 16]}),            
            .ADDRA(w_addr), 
            .ADDRB({1'b1, BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[3]}}),
            //unconnected ports
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
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(1),
			//		    .INIT_FILE("bram_4"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_4 (
            .DOA(tmp_do[4]), 
            .DOB(tmp_dob[4]),
            .DIA({16'b0, din.data.D[64 +: 16]}),
            .DIB({16'b0, BRAM_DINB[64 +: 16]}),            
            .ADDRA(w_addr), 
            .ADDRB({1'b1, BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[4]}}),
            //unconnected ports
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
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(1),
			//		    .INIT_FILE("bram_5"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_5 (
            .DOA(tmp_do[5]), 
            .DOB(tmp_dob[5]),
            .DIA({16'b0, din.data.D[80 +: 16]}),
            .DIB({16'b0, BRAM_DINB[80 +: 16]}),
            .ADDRA(w_addr),
            .ADDRB({1'b1, BRAM_ADDRB, 4'b1111}), 
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[5]}}),
            //unconnected ports
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
	        .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(1),
		//			    .INIT_FILE("bram_6"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_6 (
            .DOA(tmp_do[6]), 
            .DOB(tmp_dob[6]), 
            .DIA({16'b0, din.data.D[96 +: 16]}),
            .DIB({16'b0, BRAM_DINB[96 +: 16]}),
            .ADDRA(w_addr), 
            .ADDRB({1'b1, BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[6]}}),
            //unconnected ports
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
            .DIPB()
            );			

           RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(1),
//					    .INIT_FILE("bram_7"),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_7 (
            .DOA(tmp_do[7]), 
            .DOB(tmp_dob[7]), 
            .DIA({16'b0, din.data.D[112 +: 16]}),
            .DIB({16'b0, BRAM_DINB[112 +: 16]}),
            .ADDRA(w_addr), 
            .ADDRB({1'b1, BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x), 
            .CLKB(BRAM_CLKB),
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b1),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[7]}}),
            //unconnected ports
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
            .DIPB()
            );			

      `include "../../../../software/output/bram_0.v"
      `include "../../../../software/output/bram_1.v"
      `include "../../../../software/output/bram_2.v"
      `include "../../../../software/output/bram_3.v"
      `include "../../../../software/output/bram_4.v"
      `include "../../../../software/output/bram_5.v"
      `include "../../../../software/output/bram_6.v"
      `include "../../../../software/output/bram_7.v"
         
        `else
           for (i=0;i<8;i++) begin
            RAMB36 #(					
              .DOA_REG(1), 
					    .DOB_REG(0),
					    .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
					    .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_0 (
            .DOA(tmp_do[i]), 
            .DIA({16'b0, din.data.D[i*16 +: 16]}),
            .ADDRA(w_addr), 
            .CLKA(gclk.clk2x), 
            .ENA(1'b1), 
            .ENB(1'b0), 
            .REGCEA(1'b1), 	//enable DOA register clock
            .REGCEB(1'b0),  //disable DOB register clock
            .SSRA(rst), 
            .SSRB(rst), 
            .WEA({4{we}}), 
            .WEB(4'b0),
            //unconnected ports
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
            .DIPB(),
            .DIB()
            );			
         end
    
        `endif
    
			end
//		endcase
	endgenerate
endmodule

/*
`timescale 1ns / 1ps

`ifndef SYNP94
import libiu::*;
import libcache::*;
`else
`include "../../../cpu/libiu.sv"
`include "../../../cpu/libmmu.sv"
`include "../../../cpu/libcache.sv"
`endif

`ifndef SYNP94
module demo_bram_128 #(parameter int dataprot = 2,	
			      parameter int ADDRMSB = 8)		
`else			      
module demo_bram_128 #(parameter dataprot = 2,	
			      parameter ADDRMSB = 8		
		   )		
`endif		  
		(input iu_clk_type gclk, input bit rst,
		 input  bit [ADDRMSB:0] 	addr,
		 input  bit 		        we,		
		 input  cache_data_type 	din,	
		 output cache_data_type  	dout,	
		 
		 input 	[127:0]	BRAM_DINB,
		 output	[127:0]	BRAM_DOUTB,
		 input	[10:0]	BRAM_ADDRB,
		 input			BRAM_CLKB,
		 input			BRAM_SSRB,
		 input	[7:0]	BRAM_WEB
	);

	bit [1:0]	sberr, dberr;	
	
	cache_data_type w_dout;		       
	
  bit [15:0] w_addr;
  bit [31:0] tmp_do[8], tmp_dob[8];    
  
  always_comb begin
    dout.ecc_error.dberr = |dberr;
    dout.ecc_error.sberr = |sberr;

    dout.data.I       = w_dout.data.D;
    dout.data.D       = w_dout.data.D;
    dout.ecc_parity.I = w_dout.ecc_parity.D;
    dout.ecc_parity.D = w_dout.ecc_parity.D;
  end

	generate
		genvar 		i;		
				
          assign w_addr = {1'b1,addr, 4'b1111};
          
          assign w_dout.data.D[0   +: 16] = tmp_do[0][15:0];
          assign w_dout.data.D[16  +: 16] = tmp_do[1][15:0];
          assign w_dout.data.D[32  +: 16] = tmp_do[2][15:0];
          assign w_dout.data.D[48  +: 16] = tmp_do[3][15:0];
          assign w_dout.data.D[64  +: 16] = tmp_do[4][15:0];
          assign w_dout.data.D[80  +: 16] = tmp_do[5][15:0];
          assign w_dout.data.D[96  +: 16] = tmp_do[6][15:0];
          assign w_dout.data.D[112 +: 16] = tmp_do[7][15:0];
          

          assign BRAM_DOUTB[0   +: 16] = tmp_dob[0][15:0];
          assign BRAM_DOUTB[16  +: 16] = tmp_dob[1][15:0];
          assign BRAM_DOUTB[32  +: 16] = tmp_dob[2][15:0];
          assign BRAM_DOUTB[48  +: 16] = tmp_dob[3][15:0];
          assign BRAM_DOUTB[64  +: 16] = tmp_dob[4][15:0];
          assign BRAM_DOUTB[80  +: 16] = tmp_dob[5][15:0];
          assign BRAM_DOUTB[96  +: 16] = tmp_dob[6][15:0];
          assign BRAM_DOUTB[112 +: 16] = tmp_dob[7][15:0];
        
           
           for (i=0;i<8;i++) begin
            RAMB36 #(					
              .DOA_REG(1), 
			  .DOB_REG(1),
			  .READ_WIDTH_A(18), .WRITE_WIDTH_A(18), 
			  .READ_WIDTH_B(18), .WRITE_WIDTH_B(18)
              )	
            bm_0 (
            .DOA(tmp_do[i]), 
            .DOB(tmp_dob[i]),
            .DIA({16'b0, din.data.D[i*16 +: 16]}),
            .DIB({16'b0, BRAM_DINB[i*16 +: 16]}),
            .ADDRA(w_addr), 
            .ADDRB({1'b1,BRAM_ADDRB, 4'b1111}),
            .CLKA(gclk.clk2x),
            .CLKB(BRAM_CLKB), 
            .ENA(1'b1), 
            .ENB(1'b1), 
            .REGCEA(1'b1), 	
            .REGCEB(1'b1),  
            .SSRA(rst), 
            .SSRB(BRAM_SSRB), 
            .WEA({4{we}}), 
            .WEB({4{BRAM_WEB[i]}}),
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
            .DIPB()
            );			
         end
    
   

	endgenerate
endmodule

*/