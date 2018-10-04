//------------------------------------------------------------------------------
// File:        itlbram.sv
// Author:      Zhangxi Tan
// Description: itlb ram implemenation on virtex 5
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

module xcv5_itlbram #(parameter ECC = "TRUE", parameter ECCSCRUB = "FALSE") (input iu_clk_type 		gclk, input bit			rst,
                                                                        input mmu_itlbram_addr_type raddr,
                                                                        input mmu_itlbram_addr_type waddr,
                                                                        input bit                   we,                                                           
                                                                        input mmu_itlbram_data_type wdata,
                                                                        output mmu_itlbram_data_type rdata,
                                                                        output bit sberr,
                                                                        output bit dberr);                                                                        
      bit [8:0]   ra, wa;
      bit [63:0]  din, dout;
      
      bit         w_sberr, w_dberr;
                     
      always_comb begin
        //default values
        din = '0; 
        
        ra = {raddr.tid, raddr.index};
        wa = {waddr.tid, waddr.index};
        
        din = wdata;
        rdata = dout[0 +: $bits(mmu_itlbram_data_type)];        
      end                                                                       
     
     always_ff @(posedge gclk.clk) begin 
       sberr <= w_sberr;
       dberr <= w_dberr;
     end 

     RAMB36SDP #(.DO_REG(0), .EN_ECC_READ(ECC), .EN_ECC_WRITE(ECC),.EN_ECC_SCRUB(ECCSCRUB))
					tlb_ram	(					 
					.DO(dout), 
		  			.DI(din),					
					.RDADDR(ra), 
					.RDCLK(gclk.clk), 
					.RDEN(1'b1), 
					.REGCE(1'b0), 
					.SSR(1'b0), 
					.WE(8'hFF), 
					.WRADDR(wa), 
					.WRCLK(gclk.clk), 
					.WREN(we),
					.DBITERR(w_dberr),
					.SBITERR(w_sberr),
					//unconnected ports
					.DOP(),
					.DIP(),
					.ECCPARITY()
					);  
endmodule

module xcv5_itlbram_fast #(parameter ECC = "TRUE", parameter ECCSCRUB = "FALSE") (input iu_clk_type 		gclk, input bit			rst,
                                                                        input mmu_itlbram_addr_type fromiu_addr,
                                                                        input mmu_itlbram_addr_type frommem_addr,
                                                                        input bit                   fromiu_we,
                                                                        input mmu_itlbram_data_type fromiu_data,
                                                                        input mmu_itlbram_data_type frommem_data,
                                                                        input bit                   frommem_we,
                                                                        output mmu_itlbram_data_type  toiu_data,
                                                                        output bit sberr,
                                                                        output bit dberr);                                                                        
      bit [8:0]   raddr, waddr;
      bit [63:0]  din, dout;
      bit         we;
                     
      always_comb begin
        //default values
        raddr = '0;
        waddr = '0;
        din = '0; 
        
        raddr = {fromiu_addr.tid, fromiu_addr.index};
        waddr = (gclk.ce) ? {fromiu_addr.tid, fromiu_addr.index} : {frommem_addr.tid, frommem_addr.index};
        we    = (gclk.ce) ? fromiu_we : frommem_we;
        
        din = (gclk.ce) ? fromiu_data : frommem_data;
        toiu_data = dout[0 +: $bits(mmu_itlbram_data_type)];        
      end                                                                       
      

     RAMB36SDP #(.DO_REG(0), .EN_ECC_READ(ECC), .EN_ECC_WRITE(ECC),.EN_ECC_SCRUB(ECCSCRUB))
					tlb_ram	(					 
					.DO(dout), 
		  			.DI(din),					
					.RDADDR(raddr), 
					.RDCLK(gclk.clk), 
					.RDEN(1'b1), 
					.REGCE(1'b0), 
					.SSR(1'b0), 
					.WE(8'hFF), 
					.WRADDR(waddr), 
					.WRCLK(gclk.clk2x), 
					.WREN(we),
					.DBITERR(dberr),
					.SBITERR(sberr),
					//unconnected ports
					.DOP(),
					.DIP(),
					.ECCPARITY()
					);  
endmodule