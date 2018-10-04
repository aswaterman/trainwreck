//---------------------------------------------------------------------------   
// File:        dramctrl_mig.sv
// Author:      Zhangxi Tan
// Description: Instantiate BEE3 mem controller for ML505
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libtech::*;
import libmemif::*;
import libcache::*;
`else
`include "../../../cpu/libiu.sv"
`include "../../../cpu/libmmu.sv"
`include "../../../cpu/libcache.sv"
`include "../../../mem/libmemif.sv"
`endif

module dramctrl_mig_ml505( 
 //dram clock
 input dram_clk_type        ram_clk,   //dram clock
 //signals to cpu
 mem_controller_interface.dram  user_if,

 //SODIMM signals
 inout  [63:0]              ddr2_dq,
 output [12:0]              ddr2_a,
 output [1:0]               ddr2_ba,
 output                     ddr2_ras_n,
 output                     ddr2_cas_n,
 output                     ddr2_we_n,
 output [0:0]               ddr2_cs_n,
 output [0:0]               ddr2_odt,
 output [0:0]               ddr2_cke,
 output [7:0]               ddr2_dm,
 inout  [7:0]               ddr2_dqs,
 inout  [7:0]               ddr2_dqs_n,
 output [1:0]               ddr2_ck,
 output [1:0]               ddr2_ck_n,

 output			                  idelay_ctrl_rdy		//used for dramrst	

 );

bit [30:0] app_af_addr;
bit [2:0]  app_af_cmd;
bit [15:0] app_wdf_mask_data;

wire       rd_valid; 

assign    app_af_addr = unsigned'({user_if.Address, {DRAMADDRPAD{1'b0}}});
assign    app_af_cmd  = unsigned'(user_if.Read);
assign    app_wdf_mask_data = unsigned'(1'b0);


ddr2_sdram 
`ifdef MODEL_TECH 
#(.SIM_ONLY(1))               //increase the simulation speed
`endif 
gen_dram_ctrl
  (
    .*, 
/*  
    .ddr2_dq(ddr2_dq),
    .ddr2_a(ddr2_a),
    .ddr2_ba(ddr2_ba),
    .ddr2_ras_n(ddr2_ras_n),
    .ddr2_cas_n(ddr2_cas_n),
    .ddr2_we_n(ddr2_we_n),
    .ddr2_cs_n(ddr2_cs_n),
    .ddr2_odt(ddr2_odt),
    .ddr2_cke(ddr2_cke),
    .ddr2_dm(ddr2_dm),
    .ddr2_dqs(ddr2_dqs),
    .ddr2_dqs_n(ddr2_dqs_n),
    .ddr2_ck(ddr2_ck),
    .ddr2_ck_n(ddr2_ck_n),
    .idelay_ctrl_rdy(idelay_ctrl_rdy),		//used for dramrst	
*/     
    .rst0(ram_clk.mig.rst0),
    .rst90(ram_clk.mig.rst90),
    .rstdiv0(ram_clk.mig.rstdiv0),
    .rst200(ram_clk.mig.rst200),
    .clk0(ram_clk.mig.clk0),
    .clk90(ram_clk.mig.clk90),
    .clkdiv0(ram_clk.mig.clkdiv0),
    .clk200(ram_clk.mig.clk200),
    
    .af_clk(user_if.AFclock),			  //address fifo clk
    .rb_clk(user_if.RBclock),			  //read buffer clk
    .wb_clk(user_if.WBclock),			  //write buffer clk
    .rb_re(user_if.ReadRB),       //read buffer enable
    .rb_full(user_if.RBfull),			  //read buffer is full

    .phy_init_done(),             //don't care
    .app_wdf_afull(user_if.WBfull),
    .app_af_afull(user_if.AFfull),
    .rd_data_valid(rd_valid),            
    .app_wdf_wren(user_if.WriteWB),
    .app_af_wren(user_if.WriteAF),
//    .app_af_addr(unsigned'(user_if.Address)),
    .app_af_addr,
//    .app_af_cmd(unsigned'(user_if.Read)),
    .app_af_cmd,
    .rd_data_fifo_out(user_if.ReadData),
    .app_wdf_data(user_if.WriteData),
//    .app_wdf_mask_data(unsigned'(1'b0))
    .app_wdf_mask_data
   );

  assign user_if.RBempty = ~rd_valid;
endmodule


//proxy to mig in XST
module dramctrl_mig_ml505_xst( 
 //dram clock
 input dram_clk_type            ram_clk,   //dram clock
 //signals to cpu
 mem_controller_interface.dram  user_if,

 output			                      dramrstn,		//used for dramrst	
 
 //Inteface to XST 
 output                         rst0,
 output                         rst90,
 output                         rstdiv0,
 output                         rst200,
 output                         clk0,
 output                         clk90,
 output                         clkdiv0,
 output                         clk200,

 input			      idelay_ctrl_rdy,		//used for dramrst	

 output			      af_clk,			//address fifo clk
 output			      rb_clk,			//read buffer clk
 output		       wb_clk,			//write buffer clk
 output         rb_re,    //read buffer enable
 input		        rb_full,			//read buffer is full


// input                            phy_init_done,
 input                            app_wdf_afull,
 input                            app_af_afull,
 input                            rd_data_valid,
 output                           app_wdf_wren,
 output                           app_af_wren,
 output [30:0]                    app_af_addr,
 output [2:0]                     app_af_cmd,
 input  [127:0]                   rd_data_fifo_out,
 output [127:0]                   app_wdf_data,
 output [15:0]                    app_wdf_mask_data
 );



//always_comb begin
 assign   app_af_addr = unsigned'({user_if.Address, {DRAMADDRPAD{1'b0}}});
 assign   app_af_cmd  = unsigned'(user_if.Read);
 assign   app_wdf_mask_data = unsigned'(1'b0);
 assign   rst0    = ram_clk.mig.rst0;
 assign   rst90   = ram_clk.mig.rst90;
 assign   rstdiv0 = ram_clk.mig.rstdiv0;
 assign   rst200  = ram_clk.mig.rst200;
 assign   clk0    = ram_clk.mig.clk0;
 assign   clk90   = ram_clk.mig.clk90;
 assign   clkdiv0 = ram_clk.mig.clkdiv0;
 assign   clk200  = ram_clk.mig.clk200;
   
 assign   af_clk  = user_if.AFclock;			  //address fifo clk
 assign   rb_clk  = user_if.RBclock;			  //read buffer clk
 assign   wb_clk  = user_if.WBclock;			  //write buffer clk
 assign   rb_re   = user_if.ReadRB;      //read buffer enable
 assign   user_if.RBfull = rb_full;			   //read buffer is full
//  .phy_init_done(),              //don't care
 assign   user_if.WBfull  = app_wdf_afull;
 assign   user_if.AFfull  = app_af_afull;
 assign   user_if.RBempty = ~rd_data_valid;   
 assign   app_wdf_wren    = user_if.WriteWB;
 assign   app_af_wren     = user_if.WriteAF;
 assign   user_if.ReadData = rd_data_fifo_out;
 assign   app_wdf_data     = user_if.WriteData;
 assign   dramrstn         = idelay_ctrl_rdy;
endmodule
