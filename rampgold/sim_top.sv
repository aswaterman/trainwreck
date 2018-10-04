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

//synthesis translate_off

//import "DPI-C" context function void htif_init
//(
//  input string thost,
//  input string fhost
//);
//
//import "DPI-C" context function void fromhost_getbyte
//(
//  output bit       valid,
//  output bit [7:0] bits
//);
//
//import "DPI-C" context function void tohost_putbyte
//(
//  input bit [7:0] bits
//);

module sim_top;

  bit clk=0;
  bit rst;
  bit cpurst;
  bit do_htif;

  bit phy_rxclk, phy_gtxclk, phy_txen, phy_rxdv;
  bit [7:0] phy_txd, phy_rxd;

  //IO interface
  //io_bus_out_type      io_in;
  //io_bus_in_type       io_out;

  wire [63:0]              ddr2_dq;
  wire [13:0]              ddr2_a;
  wire [2:0]               ddr2_ba;
  wire                     ddr2_ras_n;
  wire                     ddr2_cas_n;
  wire                     ddr2_we_n;
  wire [1:0]               ddr2_cs_n;
  wire [1:0]               ddr2_odt;
  wire [1:0]               ddr2_cke;
  wire [7:0]               ddr2_dm;
  wire [7:0]               ddr2_dqs;
  wire [7:0]               ddr2_dqs_n;
  wire [1:0]               ddr2_ck;
  wire [1:0]               ddr2_ck_n;

  wire                     TxD;
  wire                     RxD;

  default clocking main_clk @(posedge clk);
  endclocking

  initial begin
    forever #2.5 clk = ~clk;
  end

  initial begin
    forever #4 phy_rxclk = ~phy_rxclk;
  end

  initial begin

    rst    = '0;
    cpurst = '0;
    do_htif = '0;

  //  io_in.retry = '0;
  //  io_in.irl   = '0;
  //  io_in.rdata = '0;

  //  ##10;
  //  rst = '0;
    
    ##200;
    rst = '1;
    
    ##10;
    rst = '0;
    
    ##200;
    cpurst = '1;
    
    ##10;
    cpurst = '0;

    ##10;
    do_htif = '1;

  end

  mt16htf25664hy gen_sodimm
  (
    .dq(ddr2_dq),
    .addr(ddr2_a),           //COL/ROW addr
    .ba(ddr2_ba),            //bank addr
    .ras_n(ddr2_ras_n),
    .cas_n(ddr2_cas_n),
    .we_n(ddr2_we_n),
    .cs_n(ddr2_cs_n),
    .odt(ddr2_odt),
    .cke(ddr2_cke),
    .dm(ddr2_dm),
    .dqs(ddr2_dqs),
    .dqs_n(ddr2_dqs_n),
    .ck(ddr2_ck),
    .ck_n(ddr2_ck_n)
  );

  mac_fedriver mac
  (
    .rxclk(phy_rxclk),
    .txclk(phy_gtxclk),
    .rst(cpurst),
    .rxdv(phy_rxdv),
    .rxd(phy_rxd),
    .txd(phy_txd),
    .txen(phy_txen)
  );

  fpga_top sim
  (
    .clkin_200_p(clk),		//no use in simulation
    .clkin_200_n(~clk),
    .resetin(rst),
    .RxD(RxD),
    .TxD(TxD),
    .lcd_db4(),
    .lcd_db5(),
    .lcd_db6(),
    .lcd_db7(),
    .lcd_rw(),
    .lcd_rs(),
    .lcd_e(),
    .led(),
    .PHY_TXD(phy_txd),
    .PHY_TXEN(phy_txen),
    .PHY_TXER(),
    .PHY_GTXCLK(phy_gtxclk),
    .PHY_RXD(phy_rxd),
    .PHY_RXDV(phy_rxdv),
    .PHY_RXER(1'b0),
    .PHY_RXCLK(phy_rxclk),
    .PHY_RESET()
  );

  //string thost,fhost;
  //initial begin
  //  if(!$value$plusargs("fromhost=%s",fhost) || !$value$plusargs("tohost=%s",thost))
  //    $stop(1);
  //  htif_init(thost,fhost);
  //end

  //bit tohost_val;
  //bit [7:0] tohost_bits;

  //rs232_rx_ctrl #(.NOISY(0)) rs232_tohost
  //(
  //  .clk(sim.gclk.clk),
  //  .rst(sim.cpu_reset),

  //  .val(tohost_val),
  //  .bits(tohost_bits),

  //  .RxD(TxD)
  //);

  //bit fromhost_val, fromhost_rdy;
  //bit [7:0] fromhost_bits;

  //rs232_tx_ctrl #(.NOISY(0)) rs232_fromhost
  //(
  //  .clk(sim.gclk.clk),
  //  .rst(sim.cpu_reset),

  //  .rdy(fromhost_rdy),
  //  .val(fromhost_val),
  //  .bits(fromhost_bits),

  //  .TxD(RxD)
  //);

  //always_ff @(posedge sim.gclk.clk) begin
  //  if(!do_htif) begin
  //    fromhost_val <= '0;
  //  end else begin
  //    if(fromhost_rdy)
  //      fromhost_getbyte(fromhost_val,fromhost_bits);
  //    if(tohost_val)
  //      tohost_putbyte(tohost_bits);
  //  end
  //end

endmodule
//synthesis translate_on

module dram_driver
(
  input iu_clk_type gclk,
  input reset,
  mem_controller_interface.yunsup user_if,
  output match
);

  bit [1:0] state;

  bit mem_req_val;
  bit mem_req_rw;
  bit [25:0] mem_req_addr;
  bit [255:0] mem_req_data;

  bit [23:0] c;

  always_ff @(posedge gclk.clk)
  begin
    if (reset)
    begin
      c <= '0;
      state <= '0;
    end
    else
    begin
      c <= c + 1'b1;
      if (state == 2'd0 && c == 24'h00_1fff) state <= 2'd1;
      //if (state == 2'd0 && c == 24'h0f_ffff) state <= 2'd1;
      if (state == 2'd1 && user_if.mem_req_rdy) state <= 2'd2;
      if (state == 2'd2 && user_if.mem_req_rdy) state <= 2'd3;
    end
  end

  always_comb
  begin
    mem_req_val = 1'b0;
    mem_req_rw = 1'b0;
    mem_req_addr = 26'd0;
    mem_req_data = 256'd0;

    if (state == 2'd1)
    begin
      mem_req_val = 1'b1;
      mem_req_rw = 1'b1;
      mem_req_addr = 26'd1;
      mem_req_data = 256'd5;
    end

    if (state == 2'd2)
    begin
      mem_req_val = 1'b1;
      mem_req_rw = 1'b0;
      mem_req_addr = 26'd1;
    end
  end

  always_ff @(posedge gclk.clk)
  begin
    user_if.mem_req_val <= mem_req_val;
    user_if.mem_req_rw <= mem_req_rw;
    user_if.mem_req_addr <= mem_req_addr;
    user_if.mem_req_data <= mem_req_data;
  end

  assign match = user_if.mem_resp_val && user_if.mem_resp_data[7:0] == 8'd5;

endmodule
