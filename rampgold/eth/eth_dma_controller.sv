//-------------------------------------------------------------------------------------------------  
// File:        eth_dma_controller.sv
// Author:      Zhangxi Tan 
// Description: 1000 BASE-T Ethernet DMA frontend controller
//-------------------------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
import libdebug::*;
import libiu::*;
import libconf::*;
import libtm::*;
import libeth::*;
`else
`include "../cpu/libiu.sv"
`include "../tm/libtm.sv"
`include "libeth.sv"

`endif



//Ring interface
module eth_dma_controller #(parameter CLKMUL = 5, parameter CLKDIV = 4,  parameter CLKIN_PERIOD = 10.0, parameter BOARDSEL=1)
(    
    //clock
    input bit               reset,          //global reset input
    input bit               clkin,          //global clock input (used to generate the 125 MHz tx clock)
    input bit               clk200,         //200 MHz reference clock for IDELAYCTRL    
    input iu_clk_type       gclk, 
    output bit				eth_rst,

  output bit [63:0] rx_cmdq_bits,
  output bit        rx_cmdq_val,
  input bit         rx_cmdq_rdy,

  output bit [31:0] rx_dataq_bits,
  output bit        rx_dataq_val,
  input bit         rx_dataq_rdy,

  input bit [63:0] tx_cmdq_bits,
  input bit        tx_cmdq_val,
  output bit       tx_cmdq_rdy,

  input bit [31:0] tx_dataq_bits,
  input bit        tx_dataq_val,
  output bit       tx_dataq_rdy,

    //ring interface             
    output eth_rx_pipe_data_type   rx_pipe_out,

    input  eth_tx_ring_data_type   tx_ring_in,
    output eth_tx_ring_data_type   tx_ring_out,
    
    
    // GMII Interface (1000 Base-T PHY interface)
    output bit [7:0]    GMII_TXD,
    output bit          GMII_TX_EN,
    output bit          GMII_TX_ER,
    output bit          GMII_TX_CLK, //to PHY. Made in ODDR
    input  bit [7:0]    GMII_RXD,
    input  bit          GMII_RX_DV,
    input  bit			GMII_RX_ER,
    input  bit          GMII_RX_CLK, //from PHY. Goes through BUFG
    output bit          GMII_RESET_B
      
);
  bit ring_rst;
  
  eth_rx_pipe_data_type   rx_from_mac;
  eth_tx_ring_data_type   tx_to_mac, tx_ring_0;
  
  //rx block
  eth_dma_rx  rx_block(.*,
  					   .reset(ring_rst),
                       .clk(gclk.clk),
                       .tx_ring_in(tx_ring_0));

  //tx block
  eth_dma_tx  tx_block(.*,
  					   .reset(ring_rst),
                       .clk(gclk.clk),
                       .tx_ring_out(tx_ring_0));
  
  
  // instantiate MAC
  mac_gmii
  #(
    .CLKMUL(CLKMUL),
    .CLKDIV(CLKDIV),
    .CLKIN_PERIOD(CLKIN_PERIOD),
    .BOARDSEL(BOARDSEL)
  )
  gigaeth
  (
    .*,
  	.reset(gclk.io_reset | reset), 
    .ring_clk(gclk.clk)
  );

  assign eth_rst = ring_rst;

endmodule
