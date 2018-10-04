//------------------------------------------------------------------------------
// File:        dtlbram.sv
// Author:      Zhangxi Tan
// Description: dtlb ram implemenation on virtex 5, one read/write
//------------------------------------------------------------------------------  


`timescale 1ns / 1ps

`ifndef SYNP94
import libconf::*;
import libiu::*;
import libstd::*;
import libmmu::*;
`else
`include "../../../cpu/libiu.sv"
`include "../../../cpu/libmmu.sv"
`endif


module xcv5_dtlbram #(parameter ECC = "TRUE", parameter ECCSCRUB = "FALSE", parameter DOREG = 1) (input iu_clk_type 		gclk, input bit			rst,
                                                                        input mmu_dtlbram_addr_type raddr,
                                                                        input mmu_dtlbram_addr_type waddr,
                                                                        input bit                   we,                                                           
                                                                        input mmu_dtlbram_data_type wdata,
                                                                        output mmu_dtlbram_data_type     rdata,
                                                                        output bit sberr,
                                                                        output bit dberr);                                                                        
      bit [8:0]   ra, wa;
      bit [63:0]  din, dout;
                     
      always_comb begin
        //default values
        din = '0; 
        
        ra = {raddr.tid, raddr.index};
        wa = {waddr.tid, waddr.index};
        
        din = wdata;
        rdata = dout[0 +: $bits(mmu_dtlbram_data_type)];        
      end                                                                       
      

     RAMB36SDP #(.DO_REG(DOREG), .EN_ECC_READ(ECC), .EN_ECC_WRITE(ECC),.EN_ECC_SCRUB(ECCSCRUB))
					tlb_ram	(					 
					.DO(dout), 
		  			.DI(din),					
					.RDADDR(ra), 
					.RDCLK(gclk.clk), 
					.RDEN(1'b1), 
					.REGCE(1'b1), 
					.SSR(1'b0), 
					.WE(8'hFF), 
					.WRADDR(wa), 
					.WRCLK(gclk.clk), 
					.WREN(we),
					.DBITERR(dberr),
					.SBITERR(sberr),
					//unconnected ports
					.DOP(),
					.DIP(),
					.ECCPARITY()
					);  
endmodule