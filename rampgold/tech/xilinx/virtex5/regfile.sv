//---------------------------------------------------------------------------   
// File:        regfile.v
// Author:      Zhangxi Tan
// Description: regfile mapping for xilinx virtex 5	
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libconf::*;
import libiu::*;
`else
`include "../../../cpu/libiu.sv"
`endif

//       regr                           delr1                           delr2
//         ______________                ______________                 _____
// clk    |              |              |              |               |
//                        --------------                ---------------
//         _______        _______        _______        _______         _____
// clk2x  |       |      |       |      |       |      |       |       |
//                --------       --------       --------       --------
// addr latch            op1           op2
// result                                op1            op2
// rfo                                                  <---------op1(jeg)--------->
//                                                      <---------op2(no reg)

//double clocked main register file, by default protectin = software arity
(* syn_maxfan=16 *) module xcv5_regfile (input iu_clk_type gclk, input rst, input regfile_read_in_type rfi, output regfile_read_out_type rfo, input regfile_commit_type rfc);
	//bit 	   ce1;				//latch op1;
	(* syn_maxfan=4 *) bit [15:0] raddr;			//time multiplexed read regfile address
	(* syn_maxfan=4 *) bit [15:0] waddr; 		//time multiplexed write regfile address
	bit [31:0] rdata[0:1]; 		//time multiplexed read regfile data
	bit [31:0] wdata;			//time multiplexed write regfile data	
	
	bit [6:0]  rparity[0:1];	//time multiplexed read parity, parity[2:0] are packed in a separate ECC BRAM in case ECC is used to protect register file
	bit [6:0]  wparity;	//time multiplexed write parity 		
	(* syn_maxfan=4 *) bit [3:0]  we[0:1];				  //time multiplexed WE

	bit [31:0] op1, op2;
	bit [6:0]  op1_parity, op2_parity;

	//parities are used for software parity only
	bit [31:0] w_rdata[0:NWIN];	//wires for regfile DOA 
	bit [3:0]  w_rparity[0:NWIN];	//wires for regfile DOPA	supports 64 threads
	
  bit muxwire;
  bit muxselect, muxselectd;

  localparam nmux = (NWIN==7)?2:1;
	localparam nblock = NTHREAD / 16;	//no. of blocks
	localparam bw = 32/nblock;		//block width
	
	//always_comb begin
	always_comb begin
    //default values
    raddr = '1;
    waddr = '1;
    wdata = '0;
    we[0] = '0;
    we[1] = '0;

    // this hold only when the NREGADDRMSB bit is equal for op1_addr & op2_addr
    // rfi.op1_addr[NREGADDRMSB] == rfi.op2_addr[NREGADDRMSB]

    if (NWIN == 7)
      muxwire = rfi.op1_addr[NREGADDRMSB];
    else
      muxwire = '0;

		//software parity and no protection
		//clock 2x logic
		if (gclk.ce == 0) begin 	//second cycle
			unique case (NTHREAD)
			16: begin
				//read & wrtie addresses		
				raddr[14:5] = rfi.op1_addr[NTHREADIDMSB+6:0];
				waddr[14:5] = rfc.ph1_addr[NTHREADIDMSB+6:0];
			    end
			32: begin
				//read & wrtie addresses		
				raddr[14:4] = rfi.op1_addr[NTHREADIDMSB+6:0];
				waddr[14:4] = rfc.ph1_addr[NTHREADIDMSB+6:0];
			    end
			default: begin		//64 thread by default
				//read & wrtie addresses		
				raddr[14:3] = rfi.op1_addr[NTHREADIDMSB+6:0];
				waddr[14:3] = rfc.ph1_addr[NTHREADIDMSB+6:0];
				end
			endcase
			wdata = rfc.ph1_data;
			wparity = rfc.ph1_parity;	//only highest 4 check bits are saved in BRAM
			//we = {4{regf.ph1_we}};	
      if (NWIN == 7) begin
        we[rfc.ph1_addr[NREGADDRMSB]] = signed'(rfc.ph1_we);
      end
      else begin
			  we[0] = signed'(rfc.ph1_we);	
      end
		end				
		else begin
			unique case (NTHREAD)
			16: begin
				//read & wrtie addresses		
				raddr[14:5] = rfi.op2_addr[NTHREADIDMSB+6:0];
				waddr[14:5] = rfc.ph2_addr[NTHREADIDMSB+6:0];
			    end
			32: begin
				//read & wrtie addresses		
				raddr[14:4] = rfi.op2_addr[NTHREADIDMSB+6:0];
				waddr[14:4] = rfc.ph2_addr[NTHREADIDMSB+6:0];
			    end
			default: begin		//64 thread by default
				//read & wrtie addresses		
				raddr[14:3] = rfi.op2_addr[NTHREADIDMSB+6:0];
				waddr[14:3] = rfc.ph2_addr[NTHREADIDMSB+6:0];
				end
			endcase			
			wdata = rfc.ph2_data;
			wparity = rfc.ph2_parity;
			//we = {4{comr.regf.ph2_we}};
      if (NWIN == 7) begin
        we[rfc.ph2_addr[NREGADDRMSB]] = signed'(rfc.ph2_we);
      end
      else begin
			  we[0] = signed'(rfc.ph2_we);	
      end
		end
	end	

  assign op2 = rdata[muxselectd];
  assign op2_parity = (BRAMPROT > 0)? rparity[muxselectd] : '0;

	always_ff @(negedge gclk.clk) begin	//latch op1 at negedge of clk
    muxselect  <= muxwire;
    muxselectd <= muxselect;
		op1        <= rdata[muxselect];
		op1_parity <= (BRAMPROT > 0)? rparity[muxselect] : '0;		//highest bit is the parity bit for 
	end
			
	assign rfo.op1_data   = op1;
	assign rfo.op2_data   = op2;
	assign rfo.op1_parity = op1_parity;
	assign rfo.op2_parity = op2_parity;
  
	//Instantiate regfile BRAM based on protection type	
	generate
    genvar m;
		genvar i;	//generate loop variable
		
					
		//software parity and no protection, port A read/B write	
		//32-bit register file can only be protected by software ECC due to RW port limitation
		//no. blocks = nthread/16
    for (m=0; m<nmux; m++) begin
      for (i=0;i<nblock;i++) begin
          assign rdata[m][i*bw+(bw-1):i*8] = w_rdata[m*nblock+i][(bw-1):0];
          assign rparity[m][i+(7-nblock)] = (BRAMPROT) ? w_rparity[m*nblock+i][0] : '0;		  //not used if not in ECC mode	

          // 4K*(8+1 bit) x 4 blocks (for 64 threads)
                RAMB36 #(
            .DOA_REG(1), 
            .DOB_REG(0),
            .READ_WIDTH_A(9*bw/8), .WRITE_WIDTH_A(9*bw/8), 
            .READ_WIDTH_B(9*bw/8), .WRITE_WIDTH_B(9*bw/8)
  //					.SIM_MODE("FAST")
          ) regfile (
          .DOA(w_rdata[m*nblock+i]), 
          .DOPA(w_rparity[m*nblock+i]),
          .ADDRA(raddr), 
          .ADDRB(waddr), 
          .CLKA(gclk.clk2x), 
          .CLKB(gclk.clk2x), 
          .DIB(32'(wdata[i*bw+(bw-1):i*8])), 				
          .DIPB(4'(wparity[i+(7-nblock)])), 
          .ENA(1'b1), 
          .ENB(1'b1), 
          .REGCEA(1'b1), 	//enable DOA register clock
          .REGCEB(1'b0),  //disable DOB register clock
          .SSRA(rst), 
          .SSRB(rst), 
          .WEA(4'b0), 
          .WEB(we[m]),
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
      end
    end
	endgenerate
endmodule