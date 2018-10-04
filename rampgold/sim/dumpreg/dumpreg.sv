//-------------------------------------------------------------------------------------------  
// File:        dumpreg.sv
// Author:      Yunsup Lee
// Description: Dumping commited register file and spr
//-------------------------------------------------------------------------------------------   

//synthesis translate_off

`timescale 1ns / 1ps

import libiu::*;

typedef struct {
    int unsigned ph1_addr;
    int unsigned ph2_addr;
    int unsigned ph1_data;
    int unsigned ph2_data;
    int ph1_we;
    int ph2_we;
    int temp;
} regfile_dpi_type;
typedef struct {
    int unsigned psr;
    int unsigned y;
    int unsigned wim;
    int we;
} spr_dpi_type;

import "DPI-C" context function void dump(input regfile_dpi_type regfile, input spr_dpi_type spr);

module dumpreg(input iu_clk_type gclk, input bit rst, input commit_reg_type	comr, input mem_reg_type memr);
  regfile_dpi_type regfile;
  spr_dpi_type spr;

  always_comb begin
    regfile.ph1_addr = int'(comr.regf.ph1_addr);
    regfile.ph2_addr = int'(comr.regf.ph2_addr);
    regfile.ph1_data = int'(comr.regf.ph1_data);
    regfile.ph2_data = int'(comr.regf.ph2_data);
    regfile.ph1_we = int'(comr.regf.ph1_we);
    regfile.ph2_we = int'(comr.regf.ph2_we);
    regfile.temp = int'(memr.ex_res);
    spr.psr = int'({4'b0, 4'b0, comr.spr.psr.icc.N, comr.spr.psr.icc.Z, comr.spr.psr.icc.V, comr.spr.psr.icc.C, 6'b0, 1'b0, 1'b0, comr.spr.psr.pil, comr.spr.psr.s, comr.spr.psr.ps, comr.spr.psr.et, 3'b0, comr.spr.psr.cwp});
    spr.y = int'(comr.spr.y.y);
    spr.wim = int'(comr.spr.wim);
    spr.we = int'(comr.spr.archr_we);
  end
  
  always @(posedge gclk.clk) begin
    if (rst == 0) begin
      dump(regfile, spr);
    end
  end

endmodule

//synthesis translate_on
