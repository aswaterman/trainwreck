//---------------------------------------------------------------------------   
// File:        clkrst_gen.v
// Author:      Zhangxi Tan
// Description: Generate clk and rst.	
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libconf::*;
import libiu::*;
import libtech::*;
import libstd::*;
`else
`include "libiu.sv"
`endif

module clkrst_gen #(parameter differential = 1,
`ifndef SYNP94
  parameter fpgatech_type fpgatech = xilinx_virtex5,
`else	
  parameter fpgatech = 1,
`endif	
  parameter IMPL_IBUFG = 1,
  parameter BOARDSEL = 1

) (input bit clkin_p, input bit clkin_n, input bit rstin, input bit dramrst, output iu_clk_type gclk, output dram_clk_type ram_clk, output bit rst, output bit clkin_b);
	bit			dcm_locked;		//DCM is locked

  bit   clkin;
  	
	bit			clk;			  //main clk
	bit			clk2x;			//clk2x
	
	
	bit			ce;
	//(* PRESERVE_DRIVER *) bit			ce;	
	//(* dont_retime *) bit			ce;	

//	bit				rst_t;			                                //internal rst
  (* syn_maxfan=16 *)	bit	[1:0]		rst_sync;										//after reset synchronizer
	//(* syn_maxfan=30 *) bit [NTHREAD+10:0]	rst_del;		//shift register to delay rst for NTHREAD + pipeline length cycles		

	(* syn_maxfan=16 *) bit [log2x(NTHREAD+31)-1:0]	rst_cnt;		           //shift register to delay rst for NTHREAD + pipeline length cycles		
  (* syn_maxfan=16 *) bit       reset;
  (* syn_maxfan=16 *) bit       reset_b;						//first level
  (* syn_maxfan=32 *) bit		reset_dly; 
  
  (* syn_maxfan=8 *) bit r_ce;				//used in the register implementation
  
  //clock input buffer
  generate 
	if (IMPL_IBUFG)
	  clk_inb #(.differential(differential), .fpgatech(fpgatech)) gen_clkinp(.clk_p(clkin_p), .clk_n(clkin_n), .clk(clkin));
	else
	  assign clkin = clkin_p;
  endgenerate
  
  assign clkin_b = clkin;
  				
	cpu_clkgen #(.fpgatech(fpgatech), .CLKMUL(CLKMUL), .CLKDIV(CLKDIV), .CLKIN_PERIOD(CLKIN_PERIOD)) gen_clk (
		.clkin,
		.rstin,
		.clk,
		.clk2x,
		.ce,
		.locked(dcm_locked));
		
 	dram_clkgen #(.fpgatech(fpgatech), .BOARDSEL(BOARDSEL), .CLKMUL(DRAM_CLKMUL), .CLKDIV200(DRAM_CLKDIV200), .CLKDIV(DRAM_CLKDIV), .CLKIN_PERIOD(DRAM_PERIOD)) gen_dram_clk (
 	.clkin,	
 	.rstin,
 	.dramrst,
 	.ram_clk
 	);

	
//	assign rst_t = rstin | ~dcm_locked;	


	always_ff @(posedge clk) begin
	  reset_dly <= reset_b;
	  reset_b <= reset;	
	end    
	 
/*  always_ff @(posedge clk or posedge rst_sync[1]) begin
	if (rst_sync[1]) begin
	   reset_dly <= '1;
	   reset_b <= '1;
	end
	else begin
      reset_dly <= reset_b;
	  reset_b <= reset;
	end
  end    
*/
	  
   //cpu reset synchronizer   	
   always_ff @(posedge clk or negedge dcm_locked) begin
   	if (!dcm_locked)
   		rst_sync <= '1;
   	else begin
   		rst_sync[1] <= rst_sync[0];
   		rst_sync[0] <= '0;
   	end 	
   end
   
	always_ff @(posedge clk or posedge rst_sync[1]) begin  
		if (rst_sync[1]) begin
			rst_cnt <= '0;
			reset   <= '1;
		end
		else if (rst_cnt < NTHREAD+30) begin
			rst_cnt <= rst_cnt + 1 ;
			reset   <=  '1;
		end
		else begin
			rst_cnt <= rst_cnt;
			reset   <= '0;
		end
	end

	//clock based CE
	//gated_clkbuf gated_ce(.clk_in(ce), .clk_out(gclk.ce), .clk_ce(~reset));
    
	//working CE
	always_ff @(posedge clk2x) begin
		r_ce <= (reset_dly) ? reset_b : ~r_ce;		 //this is to let IU initialize TLB/Cache during RST
	end 
    
   
	//output
	assign rst = reset_dly;        //counter
	assign gclk.clk = clk;
	assign gclk.clk2x = clk2x;
	assign gclk.ce = r_ce; 
	//high_fanout_buf gen_ce(.gin(ce), .gout(gclk.ce));

   //assign reset_b = reset;
  //high_fanout_buf gen_reset(.gin(reset), .gout(reset_b));
endmodule


module reset_synchronizer (input bit rstin, input bit clk, output rst_s);  
  (* syn_maxfan=1  *) bit r_dly_0, r_dly_1  /*synthesis syn_maxfan=1 syn_preserve=1*/;		//register
  (* syn_maxfan=64 *) bit r_dly_2  /*synthesis syn_maxfan=64 syn_preserve=1*/;              //drives up to 32 registers.
    
  always_ff @(posedge clk or posedge rstin) begin
      if (rstin)  begin
        r_dly_0 <= '1;
        r_dly_1 <= '1;
        r_dly_2 <= '1;
      end
      else begin
        r_dly_0 <= '0;
        r_dly_1 <= r_dly_0;
        r_dly_2 <= r_dly_1;
      end
  end
  
  assign rst_s = r_dly_2;
endmodule


//new clkrst_gen with separate CPU reset
module clkrst_gen_2 #(
  parameter differential = 1,
  parameter nocebuf = 0,
`ifndef SYNP94
  parameter fpgatech_type fpgatech = xilinx_virtex5,
`else	
  parameter fpgatech = 1,
`endif	
  parameter IMPL_IBUFG = 1,
  parameter BOARDSEL = 1

) (input bit clkin_p, input bit clkin_n, input bit rstin, input bit clk200, input bit cpurst, input bit dramrst, output iu_clk_type gclk, output dram_clk_type ram_clk, output bit rst, output bit clkin_b);
  bit			dcm_locked;		//DCM is locked

  bit   clkin;
    
  bit			clk;			  //main clk
  bit			clk2x;			//clk2x
  
  
  bit			ce, ce_b;
  
  bit   dcm_locked_rst;         //reset from dcm if not locked
  
  bit   cpu_rstin;      

  
   bit [log2x(NTHREAD+20)-1:0]	rst_cnt;		           //shift register to delay rst for NTHREAD + pipeline length cycles		
   bit       reset;

  (* syn_maxfan=100000 *) bit       reset_b;						

  bit		     reset_local; 
  
  (* syn_maxfan=16, syn_srlstyle="registers" *)   bit       r_ce;				//used in the register implementation
  (* syn_maxfan=16 *)	  bit 	     r_ce_l;
  
  (* syn_maxfan=16, syn_srlstyle="registers" *)   bit [1:0] r_ce_p;  //pipeline r_ce
  
  //clock input buffer
  generate 
  if (IMPL_IBUFG)
    clk_inb #(.differential(differential), .fpgatech(fpgatech)) gen_clkinp(.clk_p(clkin_p), .clk_n(clkin_n), .clk(clkin));
  else
    assign clkin = clkin_p;
  endgenerate
  
  assign clkin_b = clkin;
          
  cpu_clkgen #(.fpgatech(fpgatech), .CLKMUL(CLKMUL), .CLKDIV(CLKDIV), .CLKIN_PERIOD(CLKIN_PERIOD)) gen_clk (
    .clkin,
    .rstin,
    .clk,
    .clk2x,
    .ce,
    .locked(dcm_locked));
    
   dram_clkgen #(.fpgatech(fpgatech), .BOARDSEL(BOARDSEL), .CLKMUL(DRAM_CLKMUL), .CLKDIV200(DRAM_CLKDIV200), .CLKDIV(DRAM_CLKDIV), .CLKIN_PERIOD(DRAM_PERIOD)) gen_dram_clk (
   .clkin,
   .clk200,
   .rstin,
   .dramrst,
   .ram_clk
   );
  
      
  //cpu reset synchronizer   	   
  reset_synchronizer cpu_rst_sync(.rstin(~dcm_locked), .clk, .rst_s(dcm_locked_rst));
   
  //cpu reset global input 
  high_fanout_buf reset_buf(.gin(reset), .gout(reset_b));
   
  assign cpu_rstin  = dcm_locked_rst | cpurst;
   
   //delay the reset for NTHREAD+20 cycles
  always_ff @(posedge clk or posedge cpu_rstin) begin  
    if (cpu_rstin) begin
      rst_cnt <= '0;
      reset   <= '1;
    end
    else if (rst_cnt < NTHREAD+20) begin
      rst_cnt <= rst_cnt + 1 ;
      reset   <=  '1;
    end
    else begin
      rst_cnt <= rst_cnt;
      reset   <= '0;
    end
  end

  reset_synchronizer reset_sync(.rstin(reset_b), .clk, .rst_s(reset_local));

  //Generate CE
  generate  
	if (nocebuf) begin
	 always_ff @(negedge clk2x) r_ce_l <= clk;
//	 always_ff @(posedge clk2x) r_ce_p[0] <= r_ce_l;	 
//	 always_ff @(posedge clk2x) r_ce_p[1] <= r_ce_p[0];
//	 always_ff @(posedge clk2x) r_ce <= r_ce_p[1];
	 always_ff @(posedge clk2x) r_ce <= r_ce_l;

	 assign ce_b = 0; 		//no use	 
	end
	else begin
	 assign r_ce_l = 0;		//no use
	 high_fanout_buf ce_buf(.gin(ce), .gout(ce_b));
	  always_ff @(posedge clk2x) begin
	    r_ce <= ce_b;		 //this is to let IU initialize TLB/Cache during RST
	  end 
	end
  endgenerate
    

  //output
  assign rst = reset_local;        //counter
  assign gclk.clk = clk;
  assign gclk.clk2x = clk2x;
  assign gclk.ce = r_ce; 
  assign gclk.io_reset = ~dcm_locked;
endmodule