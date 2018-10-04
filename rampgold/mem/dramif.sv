//---------------------------------------------------------------------------   
// File:        dramif.sv
// Author:      Zhangxi Tan
// Description: Dram user interface definition
//------------------------------------------------------------------------------  
`timescale 1ns / 1ps

`ifndef DRAMUIF
`define DRAMUIF

import libiu::*;
import libcache::*;
import libmemif::*;

interface mem_controller_interface
(
  input iu_clk_type gclk,
  input rst
);

  // 32-bit memory space: 4 giga bytes
  // 31-bit: 2 giga bytes
  // 26-bit: 2 giga bytes - 32 byte lines

  //Memory controller user logic interface
  bit [27:0]  Address;
  bit         Read;        //1 = Read, 0 = Write
  bit         WriteAF;
  bit         AFfull;      //memory controller address fifo full
  bit         AFclock;
   
  bit [143:0] ReadData;    //read back data
  bit         ReadRB; 
  bit         RBempty;     //memory controller read buffer empty
  bit         RBfull;      //RB is full, used to monitor can we consume the dram data fast enough
  bit         RBclock;     //read buffer read clock
    
  bit [143:0] WriteData;
  bit         WriteWB;     //write data fifo WE
  bit         WBfull;      //memory controller write buffer full
  bit         WBclock;     //write buffer write clock

  // yunsup's logic interface
  bit mem_req_val;
  bit mem_req_rdy;
  bit mem_req_rw;
  bit [25:0] mem_req_addr;
  bit [127:0] mem_req_data;

  bit mem_resp_val;
  bit [127:0] mem_resp_data;
  
  modport dram
  (
    output Address,
    output Read,
    output WriteAF,
    input AFfull,
    output AFclock,
    input ReadData,
    output ReadRB,
    input RBempty,
    input RBfull,
    output RBclock,
    output WriteData,
    output WriteWB,
    input WBfull,
    output WBclock
  );

  modport yunsup
  (
    input mem_req_val,
    output mem_req_rdy,
    input mem_req_rw,
    input mem_req_addr,
    input mem_req_data,

    output mem_resp_val,
    output mem_resp_data
  );

  bit [13:0] c;
  bit mem_controller_rdy;

  always_ff @(posedge gclk.clk)
  begin
    if (rst)
      c <= '0;
    else if (c < 14'h2000)
      c <= c + 1'b1;
  end

  assign mem_controller_rdy = (c == 14'h2000);

  bit reg_cnt;

  always_ff @(posedge gclk.clk)
  begin
    if (rst)
      reg_cnt <= '0;
    else if (mem_req_val & mem_req_rw)
      reg_cnt <= reg_cnt + 1'b1;
  end

  assign AFclock = gclk.clk;
  assign WBclock = gclk.clk;
  assign RBclock = gclk.clk;

  bit af_full;
  bit rb_full;
  bit wb_full;

  always @(posedge gclk.clk)
  begin
    af_full <= AFfull;
    rb_full <= RBfull;
    wb_full <= WBfull;
  end

  assign mem_req_rdy = mem_controller_rdy & ~af_full & ~rb_full & ~wb_full;

  assign Address = {2'd0, mem_req_addr};
  assign Read = ~mem_req_rw;
  assign WriteAF = mem_req_val & mem_req_rdy & (~mem_req_rw | (reg_cnt == 1'b1));
  assign WriteData = {16'd0, mem_req_data};
  assign WriteWB = mem_req_val & mem_req_rw & mem_req_rdy;
  assign ReadRB = ~RBempty;

  assign mem_resp_val = ~RBempty;
  assign mem_resp_data = ReadData[127:0];

endinterface

`endif
