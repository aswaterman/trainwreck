//---------------------------------------------------------------------------   
// File:        mt16htf25664hy.sv
// Author:      Zhangxi Tan
// Description: Micron 2 GB SODIMM (16*128M*8) simulation module
//              `define SODIMM, x8, DUAL_RANK, MAX_MEM (if simulate all the memory space)
//------------------------------------------------------------------------------  

`timescale 1ns/1ps;

module mt16htf25664hy(
inout  [63:0]              dq,
input [13:0]               addr,                  //COL/ROW addr
input [2:0]                ba,                    //bank addr
input                      ras_n,
input                      cas_n,
input                      we_n,
input [1:0]                cs_n,
input [1:0]                odt,
input [1:0]                cke,
input [7:0]                dm,
inout [7:0]                dqs,
inout [7:0]                dqs_n,
input [1:0]                ck,
input [1:0]                ck_n
);

//wires  
bit [15:0]    w_addr   ;
//wire [17:0]   w_dqs    ;
//wire [17:0]   w_dqs_n  ;

wire       zero = 1'b0;
wire [9:0] ones = '1;

assign w_addr[13:0] = addr;

ddr2_module ddr2_2GB_sodimm(     
    .s_n(cs_n)   ,
    .addr(w_addr)  ,
    .dqs({zero, dm, zero, dqs})    ,
    .dqs_n({ones, dqs_n}),
    .scl()         ,
    .sa()          ,
    .sda()         ,
    .*
  );
endmodule

