//---------------------------------------------------------------------------   
// File:        mt4htf3264hy.sv
// Author:      Zhangxi Tan
// Description: Micron 256MB SODIMM (4*32M*16) simulation module
//              `define SODIMM, x16, MAX_MEM (if simulate all the memory space)
//------------------------------------------------------------------------------  

`timescale 1ns/1ps;

module mt4htf3264hy(
inout  [63:0]              dq,
input [12:0]               addr,                  //COL/ROW addr
input [1:0]                ba,                    //bank addr
input                      ras_n,
input                      cas_n,
input                      we_n,
input [0:0]                cs_n,
input [0:0]                odt,
input [0:0]                cke,
input [7:0]                dm,
inout [7:0]                dqs,
inout [7:0]                dqs_n,
input [1:0]                ck,
input [1:0]                ck_n
);

//wires
bit [1:0]     w_cke;      
bit [1:0]     w_ba     ;
bit [15:0]    w_addr   ;
bit [1:0]     w_odt    ;
//wire [17:0]   w_dqs    ;
//wire [17:0]   w_dqs_n  ;
bit  [1:0]    w_cs_n    ;

wire       zero = 1'b0;
wire [9:0] ones = '1;

//assign w_dqs[16:9]  = dm;
//assign w_dqs[7:0]   = dqs;
//assign w_dqs_n[7:0] = dqs_n;
assign w_odt[0]     = odt;
assign w_cke[0]     = cke;
assign w_ba[1:0]    = ba;
assign w_addr[12:0] = addr;
assign w_cs_n[0]    = cs_n;

ddr2_module ddr2_256MB_sodimm(     
    .cke(w_cke)    ,
    .s_n(w_cs_n)   ,
    .ba(w_ba)      ,
    .addr(w_addr)  ,
    .odt(w_odt)    ,
    .dqs({zero, dm, zero, dqs})    ,
    .dqs_n({ones, dqs_n}),
    .scl()         ,
    .sa()          ,
    .sda()         ,
    .*
  );
endmodule

