//-------------------------------------------------------------------------------------------------  
// File:        top_1P_bee3_neweth.sv
// Author:      Zhangxi Tan 
// Description: Top level design for one pipeline and BEE3 dram controller with the new ethernet
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

import libconf::*;
import libopcodes::*;
import libiu::*;
import libxalu::*;
import libmmu::*;
import libcache::*;
import libmemif::*;
import libdebug::*;
import libtech::*;
import libeth::*;
import liblcd::*;
import libstd::*;

`include "riscvConst.vh"

module fpga_top
(
  input bit clkin_p,
  input bit clkin_n,
  input bit clk200_p,
  input bit clk200_n,
  input bit rstin,
  input bit cpurst, //output bit done_led, output bit error_led,

  // rs232 signals
  input  bit RxD,
  output bit TxD,

  // SODIMM signals
  inout  [63:0] ddr2_dq,
  output [13:0] ddr2_a,
  output [2:0]  ddr2_ba,
  output        ddr2_ras_n,
  output        ddr2_cas_n,
  output        ddr2_we_n,
  output [1:0]  ddr2_cs_n,
  output [1:0]  ddr2_odt,
  output [1:0]  ddr2_cke,
  output [7:0]  ddr2_dm,
  inout  [7:0]  ddr2_dqs,
  inout  [7:0]  ddr2_dqs_n,
  output [1:0]  ddr2_ck,
  output [1:0]  ddr2_ck_n,

  // Error LEDs
  output bit error1_led,
  output bit error2_led,

  // LCD
  output bit lcd_db4,
  output bit lcd_db5,
  output bit lcd_db6,
  output bit lcd_db7,
  output bit lcd_rw,
  output bit lcd_rs,
  output bit lcd_e,

  // Ethernet signals
  output bit [7:0] PHY_TXD,
  output bit PHY_TXEN,
  output bit PHY_TXER,
  output bit PHY_GTXCLK,
  input bit [7:0] PHY_RXD,
  input bit PHY_RXDV,
  input bit PHY_RXER,
  input bit PHY_RXCLK,
  output bit PHY_RESET
);

  iu_clk_type gclk;            //global clock and clock enable
  bit          rst;             //reset
  
  bit		   eth_rst;
  
//  io_bus_out_type io_in;

  //dma buffer slave interface
  debug_dma_read_buffer_in_type   dma_rb_in;
  debug_dma_read_buffer_out_type  dma_rb_out;
  debug_dma_write_buffer_in_type  dma_wb_in;

  //dma command interface 
  debug_dma_cmdif_in_type         dma_cmd_in;     //cmd input 
  //bit                             dma_cmd_ack;    //cmd has been accepted
  //dma status from IU
  bit                             dma_done;
  
  //ethernet
  bit eth_tm_reset, cpu_reset;
  bit clk_p;  
  
  //dram clk related signals
  dram_clk_type                   ram_clk;
  bit                             dramrst;
  bit							  clk200, clk200x;
  bit							  dramfifo_error;

  //memory controller interface
  mem_controller_interface        mcif(gclk, rst);

  assign eth_tm_reset = '0;
  assign cpu_reset = eth_tm_reset | cpurst | ~rstin;
  
  //------------------generate clock and reset---------------------- 
  clk_inb #(.differential(0)) gen_clkin (.clk_p(clkin_p), .clk_n(clkin_n),.clk(clk_p));
  clk_inb #(.differential(1)) gen_clk200 (.clk_p(clk200_p), .clk_n(clk200_n), .clk(clk200x));
  
  gated_clkbuf gen_clk200_buf(.clk_in(clk200x), .clk_out(clk200), .clk_ce(1'b1));
  
  clkrst_gen_2 #(.differential(0), .IMPL_IBUFG(0), .BOARDSEL(0), .nocebuf(1)) gen_gclk_rst(.*, .clk200, .rstin(~rstin), .dramrst(~dramrst), .clkin_p(clk_p), .cpurst(cpu_reset), .clkin_b());

  bit error_mode;
  bit console_val, console_rdy;
  bit [7:0] console_bits;

  wire        htif_start;
  wire        htif_fromhost_wen;
  wire [31:0] htif_fromhost;
  wire [31:0] htif_tohost;
  wire        htif_req_val;
  wire        htif_req_rdy;
  wire [3:0]  htif_req_op;
  wire [31:0] htif_req_addr;
  wire [63:0] htif_req_data;
  wire [7:0]  htif_req_wmask;
  wire [11:0] htif_req_tag;
  wire        htif_resp_val;
  wire [63:0] htif_resp_data;
  wire [11:0] htif_resp_tag;

  wire        htif_error;

  wire                      mem_req_val;
  wire                      mem_req_rdy;
  wire                      mem_req_rw;
  wire [`MEM_ADDR_BITS-1:0] mem_req_addr;
  wire [`MEM_DATA_BITS-1:0] mem_req_data;
  wire [`MEM_TAG_BITS-1:0]  mem_req_tag;

  wire                      mem_resp_val;
  wire [`MEM_DATA_BITS-1:0] mem_resp_data;
  wire [`MEM_TAG_BITS-1:0]  mem_resp_tag;

  logic rs232_tx_val, rs232_tx_rdy;
  logic [7:0] rs232_tx_bits;

  logic rs232_rx_val, rs232_rx_error;
  logic [7:0] rs232_rx_bits;

  logic lcd_rdy, lcd_val;
  logic [7:0] lcd_bits;
  
  riscvCore core
  (
    .clk(gclk.clk),
    .reset(cpu_reset),

    .error_mode(error_mode),
    .log_control(),

    .console_out_val(console_val),
    .console_out_rdy(console_rdy),
    .console_out_bits(console_bits),

    .htif_start(htif_start),
    .htif_fromhost_wen(htif_fromhost_wen),
    .htif_fromhost(htif_fromhost),
    .htif_tohost(htif_tohost),
    .htif_req_val(htif_req_val),
    .htif_req_rdy(htif_req_rdy),
    .htif_req_op(htif_req_op),
    .htif_req_addr(htif_req_addr),
    .htif_req_data(htif_req_data),
    .htif_req_wmask(htif_req_wmask),
    .htif_req_tag(htif_req_tag),
    .htif_resp_val(htif_resp_val),
    .htif_resp_data(htif_resp_data),
    .htif_resp_tag(htif_resp_tag),

    .mem_req_val(mem_req_val),
    .mem_req_rdy(mem_req_rdy),
    .mem_req_rw(mem_req_rw),
    .mem_req_addr(mem_req_addr),
    .mem_req_data(mem_req_data),
    .mem_req_tag(mem_req_tag),

    .mem_resp_val(mem_resp_val),
    .mem_resp_data(mem_resp_data),
    .mem_resp_tag(mem_resp_tag)
  );

  dramctrl_bee3_ml505
  #(
`ifdef MODEL_TECH
    .REFRESHINHIBIT(1'b0),
`else
    .REFRESHINHIBIT(1'b0),
`endif
    .no_ecc_data_path("TRUE")
  )
  gen_bee3mem
  (
    .ram_clk,
    .user_if(mcif),

    .DQ(ddr2_dq),         // the 64 DQ pins
    .DQS(ddr2_dqs),       // the 8  DQS pins
    .DQS_L(ddr2_dqs_n),
    .DIMMCK(ddr2_ck),     // differential clock to the DIMM
    .DIMMCKL(ddr2_ck_n),
    .A(ddr2_a),           // addresses to DIMMs
    .BA(ddr2_ba),         // bank address to DIMMs
    .RAS(ddr2_ras_n),
    .CAS(ddr2_cas_n),
    .WE(ddr2_we_n),
    .ODT(ddr2_odt),
    .ClkEn(ddr2_cke),     // common clock enable for both DIMMs. SSTL1_8
    .RS(ddr2_cs_n),
    .DM(ddr2_dm),
 
    .TxD(),
    .RxD(RxD),
    .SingleError(dramfifo_error),
    .DoubleError()
  );

  riscvCoreDRAMAdapter core_dram
  (
    .clk(gclk.clk),
    .reset(cpu_reset),

    .mem_req_val(mem_req_val),
    .mem_req_rdy(mem_req_rdy),
    .mem_req_rw(mem_req_rw),
    .mem_req_addr(mem_req_addr),
    .mem_req_data(mem_req_data),
    .mem_req_tag(mem_req_tag),

    .mem_resp_val(mem_resp_val),
    .mem_resp_data(mem_resp_data),
    .mem_resp_tag(mem_resp_tag),

    .user_if(mcif)
  );

  bit [63:0] rxq_bits;
  bit [7:0] rxq_aux_bits;
  bit rxq_val;
  bit rxq_rdy;

  bit [63:0] txq_bits;
  bit [7:0] txq_aux_bits;
  bit txq_val;
  bit txq_rdy;

  mac_gmii gen_eth_dma_master
  (
    // clock
  	.reset(gclk.io_reset | ~rstin), 
    .clkin(clk_p),          //global clock input (used to generate the 125 MHz tx clock)
    .clk200,                //200 MHz reference clock for IDELAYCTRL    
    .ring_clk(gclk.clk),
    .ring_rst(),

    .rxq_bits(rxq_bits),
    .rxq_aux_bits(rxq_aux_bits),
    .rxq_val(rxq_val),
    .rxq_rdy(rxq_rdy),

    .txq_bits(txq_bits),
    .txq_aux_bits(txq_aux_bits),
    .txq_val(txq_val),
    .txq_rdy(txq_rdy),

    // GMII Interface (1000 Base-T PHY interface)
    .GMII_TXD(PHY_TXD),
    .GMII_TX_EN(PHY_TXEN),
    .GMII_TX_ER(PHY_TXER),
    .GMII_TX_CLK(PHY_GTXCLK), //to PHY. Made in ODDR
    .GMII_RXD(PHY_RXD),
    .GMII_RX_DV(PHY_RXDV),
    .GMII_RX_ER(PHY_RXER),
    .GMII_RX_CLK(PHY_RXCLK), //from PHY. Goes through BUFG
    .GMII_RESET_B(PHY_RESET)              
  );

  logic htif_in_val, htif_out_rdy, htif_out_val;
  logic [63:0] htif_in_bits, htif_out_bits;

  riscvHTIFEthernetAdapter htif_eth
  (
    .clk(gclk.clk),
    .reset(cpu_reset),

    .rxq_bits(rxq_bits),
    .rxq_aux_bits(rxq_aux_bits),
    .rxq_val(rxq_val),
    .rxq_rdy(rxq_rdy),

    .txq_bits(txq_bits),
    .txq_aux_bits(txq_aux_bits),
    .txq_val(txq_val),
    .txq_rdy(txq_rdy),

    .htif_in_val(htif_in_val),
    .htif_in_bits(htif_in_bits),

    .htif_out_rdy(htif_out_rdy),
    .htif_out_val(htif_out_val),
    .htif_out_bits(htif_out_bits)
  );

  riscvHTIF htif
  (
    .clk(gclk.clk),
    .rst(cpu_reset),

    .in_val(htif_in_val),
    .in_bits(htif_in_bits),

    .out_rdy(htif_out_rdy),
    .out_val(htif_out_val),
    .out_bits(htif_out_bits),

    .htif_start(htif_start),
    .htif_fromhost_wen(htif_fromhost_wen),
    .htif_fromhost(htif_fromhost),
    .htif_tohost(htif_tohost),
    .htif_req_val(htif_req_val),
    .htif_req_rdy(htif_req_rdy),
    .htif_req_op(htif_req_op),
    .htif_req_addr(htif_req_addr),
    .htif_req_data(htif_req_data),
    .htif_req_wmask(htif_req_wmask),
    .htif_req_tag(htif_req_tag),
    .htif_resp_val(htif_resp_val),
    .htif_resp_data(htif_resp_data),
    .htif_resp_tag(htif_resp_tag),

    .error(htif_error)
  );

  assign console_rdy = lcd_rdy;
  assign lcd_val = console_val;
  assign lcd_bits = console_bits;

  rs232_tx_ctrl #(.NOISY(0)) rs232_out
  (
    .clk(gclk.clk),
    .rst(cpu_reset),

    .rdy(rs232_tx_rdy),
    .val(rs232_tx_val),
    .bits(rs232_tx_bits),

    .TxD(TxD)
  );

  rs232_rx_ctrl #(.NOISY(0)) rs232_in
  (
    .clk(gclk.clk),
    .rst(cpu_reset),

    .val(rs232_rx_val),
    .bits(rs232_rx_bits),
    .error(rs232_rx_error),

    .RxD()
  );

  lcd_ctrl lcd_out
  (
    .clk(gclk.clk),
    .rst(cpu_reset),

    .rdy(lcd_rdy),
    .val(lcd_val),
    .bits(lcd_bits),

    .lcd_pins({{lcd_db7,lcd_db6,lcd_db5,lcd_db4},lcd_rw,lcd_rs,lcd_e})
  );

  always @(posedge gclk.clk) begin
    if(cpu_reset) begin
      error2_led <= '0;
    //end else if (match) begin
    //  error2_led <= 1'b1;
    end else if(error_mode) begin
      error2_led <= '1;
      //synthesis translate_off
      $display("***** ENTERED ERROR MODE *****");
      $finish(1);
      //synthesis translate_on
    end

    if(cpu_reset)
      error1_led <= '0;
    else if(rs232_rx_error)
      error1_led <= '1;

    //synthesis translate_off
    if(!cpu_reset && htif_error) begin
      $display("***** HTIF ENTERED ERROR MODE *****");
      $finish(1);
    end
    //error2_led <= htif_error;
    //synthesis translate_on
  end
   
endmodule
