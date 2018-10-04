//---------------------------------------------------------------------------   
// File:        mt36htf51272pz.sv
// Author:      Zhangxi Tan
// Description: Micron 4 GB ECC RDIMM (36*256M*4) simulation module
//              `define RDIMM, x4, ECC, DUAL_RANK, MAX_MEM (if simulate all the memory space)
//------------------------------------------------------------------------------  

`timescale 1ns/1ps;

module mt36htf51272pz(
input                      reset_n,
inout  [71:0]              dq,
input [13:0]               addr,                  //COL/ROW addr
input [2:0]                ba,                    //bank addr
input                      ras_n,
input                      cas_n,
input                      we_n,
input [1:0]                cs_n,
input [1:0]                odt,
input [1:0]                cke,
inout [17:0]               dqs,
inout [17:0]               dqs_n,
input                      ck,
input                      ck_n
);

//wires  
bit [15:0]    w_addr   ;

assign w_addr[13:0] = addr;

ddr2_module ddr2_4GB_rdimm(     
    .s_n({2'b00, cs_n})   ,
    .addr(w_addr)  ,
    .dq(dq[63:0]),
    .cb(dq[71:64]),    
    .scl()         ,
    .sa()          ,
    .sda()         ,
    .*
  );
endmodule

