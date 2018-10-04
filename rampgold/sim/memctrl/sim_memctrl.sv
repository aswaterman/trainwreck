//---------------------------------------------------------------------------   
// File:        sim_memctrl.sv
// Author:      Zhangxi Tan
// Description: Simulate the memory controller
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libtech::*;
import libstd::*;
`else
`include "../../tech/libtech.sv"
`endif


module sim_memctrl #(parameter int MEMSIZE = 1024*1024) (
 input bit      rst,
 mem_controller_interface.dram  user_if
 );
 
 localparam int DELAYCYCLES = 6;
 
 bit [255:0] mem_data[0:MEMSIZE-1];
 bit [127:0] read_queue[$];
 bit         read_sel;
 
 bit [127:0] write_data_half;
 
 
 bit [log2x(MEMSIZE)-1:0] dly_addr[DELAYCYCLES*2-1:0];
 bit                      dly_read[DELAYCYCLES*2-1:0];

 
 initial begin
   $readmemh("target_mem.list", mem_data);
 end
 
 always_ff @(posedge user_if.WBclock) begin
  dly_addr <= {user_if.Address[log2x(MEMSIZE)-1:0], dly_addr[DELAYCYCLES*2-1:1]};
  dly_read <= {user_if.Read & user_if.WriteAF, dly_read[DELAYCYCLES*2-1:1]};

 end
 
 always_ff @(negedge user_if.AFclock)  write_data_half <= user_if.WriteData;
 always_ff @(posedge user_if.AFclock) begin
    if (user_if.WriteWB)       
      mem_data[user_if.Address] <= {user_if.WriteData, write_data_half};
 end
  
 always_ff @(posedge user_if.RBclock) begin
  if (rst) read_sel  <= '0;
  else begin
    if (dly_read[0]) begin
      read_queue.push_back((read_sel)? mem_data[dly_addr[0]][255:128] : mem_data[dly_addr[0]][127:0]);
      read_sel <= ~read_sel;
    end
   end  
 end

 always_ff @(posedge user_if.RBclock) begin
   if (user_if.ReadRB)
      read_queue.pop_front();
 end
 
 always_comb begin
   user_if.ReadData = read_queue[0];
   user_if.RBempty = (read_queue.size() == 0) ? '1 : '0;   
   user_if.AFfull = '0;
   user_if.WBfull = '0;
 end
endmodule
