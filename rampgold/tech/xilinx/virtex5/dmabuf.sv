//---------------------------------------------------------------------------   
// File:        dmabuf.sv
// Author:      Zhangxi Tan
// Description: DMA rx/tx buffers for virtex 5
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps

`ifndef SYNP94
import libconf::*;
import libiu::*;
import libdebug::*;
import libstd::*;
`else
`include "../../../cpu/libiu.sv"
//`include "../../../cpu/libdebug.sv"
`endif


module xcv5_debug_dma_buf( input iu_clk_type gclk, 
        input  bit eth_rx_clk,
        input  bit eth_tx_clk,
        input  bit rst,
				input  debug_dma_read_buffer_in_type   eth_rb_in,
				input  debug_dma_write_buffer_in_type  eth_wb_in,
				output debug_dma_write_buffer_out_type eth_wb_out,
				input  debug_dma_read_buffer_in_type   dma_rb_in,
        output debug_dma_read_buffer_out_type  dma_rb_out,
        input  debug_dma_write_buffer_in_type  dma_wb_in,
				//error report
				output bit dberr,
				output bit sberr
				);
		bit [1:0] 	derr, serr;
		bit [63:0]	rx_do_0, rx_do_1, rx_din;
		bit 		     rx_do_sel;
		
		bit	[3:0]	eth_wb_parity;
		
		assign dberr = |derr;
		assign sberr = |serr;
		
		assign rx_din = {eth_rb_in.inst, eth_rb_in.data};
		assign dma_rb_out.inst = (rx_do_sel) ? rx_do_1[63:32] : rx_do_0[63:32];
		assign dma_rb_out.data = (rx_do_sel) ? rx_do_1[31:0]  : rx_do_0[31:0];
		
		RAMB36SDP #(.DO_REG(0), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"))	
		      dma_rx_buf_0 (
		      .DBITERR(derr[0]),
		      .SBITERR(serr[0]), 
		      .DO(rx_do_0), 
		      .DOP(), 					  	//don't care
			    .DI(rx_din),
		      .DIP(),						//don't care 
		      .RDADDR(dma_rb_in.addr[8:0]), 
		      .RDCLK(gclk.clk), 
		      .RDEN(1'b1), 
		      .REGCE(1'b1), 
		      .SSR(1'b0), 
		      .WE({8{eth_rb_in.we}}), 
		      .WRADDR(eth_rb_in.addr[8:0]), 
		      .WRCLK(eth_rx_clk), 
		      .WREN(~eth_rb_in.addr[9]),			      
		      .ECCPARITY()				    //don't care
		      );
			  
		RAMB36SDP #(.DO_REG(0), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"))	
		      dma_rx_buf_1 (
		      .DBITERR(derr[1]),
		      .SBITERR(serr[1]), 
		      .DO(rx_do_1), 
		      .DOP(), 					  	//don't care
			    .DI(rx_din),
		      .DIP(),						//don't care 
		      .RDADDR(dma_rb_in.addr[8:0]), 
		      .RDCLK(gclk.clk), 
		      .RDEN(1'b1), 
		      .REGCE(1'b1), 
		      .SSR(1'b0), 
		      .WE({8{eth_rb_in.we}}), 
		      .WRADDR(eth_rb_in.addr[8:0]), 
		      .WRCLK(eth_rx_clk), 
		      .WREN(eth_rb_in.addr[9]),						      
		      .ECCPARITY()
		      );
			  
		always_ff @(posedge gclk.clk)
			rx_do_sel <= dma_rb_in.addr[9];	
		
		
		assign eth_wb_out.parity = eth_wb_parity[0];
		RAMB36 #(
        .SIM_COLLISION_CHECK("GENERATE_X_ONLY"),
				.DOA_REG(0), 
				.DOB_REG(1),
				.READ_WIDTH_A(36), .WRITE_WIDTH_A(36), 
				.READ_WIDTH_B(36), .WRITE_WIDTH_B(36)
				) dma_tx_buf (
				.DIA(dma_wb_in.data), 
				.DIPA({3'b0, dma_wb_in.parity}),
				.ADDRA({1'b1, dma_wb_in.addr[9:0], 5'h1f}), 
				.ADDRB({1'b1, eth_wb_in.addr[9:0], 5'h1f}), 
				.DOB(eth_wb_out.data),
				.DOPB(eth_wb_parity),
				.CLKA(gclk.clk), 
				.CLKB(eth_tx_clk), 				
				.ENA(1'b1), 
				.ENB(1'b1), 
				.REGCEA(1'b0), 	//disable DOA register clock
				.REGCEB(1'b1),  //enable DOB register clock				
				.SSRB(rst), 
				.WEA({4{dma_wb_in.we}}), 
				.WEB(4'b0),
				//unconnected ports
				.CASCADEINLATA(),
				.CASCADEINREGA(),
				.CASCADEINLATB(),
				.CASCADEINREGB(),
				.CASCADEOUTLATA(),
				.CASCADEOUTREGA(),
				.CASCADEOUTLATB(),
				.CASCADEOUTREGB(),
				.SSRA(), 
				.DOA(),
				.DOPA(),
				.DIB(), 				
				.DIPB() 
				);
	
endmodule