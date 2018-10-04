//-------------------------------------------------------------------------------------------------  
// File:        eth_tx.sv
// Author:      Zhangxi Tan 
// Description: 1000 BASE-T Ethernet DMA TX logic. 
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libeth::*;
`else
`include "libeth.sv"

`endif

//ring interface             
module eth_dma_tx(
input  bit reset,
input  bit clk,

input  eth_tx_ring_data_type   tx_ring_in,
output eth_tx_ring_data_type   tx_to_mac,
output eth_tx_ring_data_type   tx_ring_out
);
  enum bit {wait_for_start, wait_till_done} vstate, rstate;
  
  eth_tx_ring_data_type   v_tx_ring_out;

  always_comb begin
    v_tx_ring_out.stype   = tx_none;
    v_tx_ring_out.msg.data	   = '0;
    vstate = rstate;
    
    //master output FSM
    unique case(rstate)
    wait_for_start : if (tx_ring_in.stype == tx_none || tx_ring_in.stype == tx_start_empty) 
                        v_tx_ring_out.stype = tx_ring_in.stype;
                    else
                        vstate = wait_till_done;
    wait_till_done : if (tx_ring_in.stype == tx_none) begin 
                      vstate = wait_for_start;
                      v_tx_ring_out.stype = tx_start_empty;   //start a new token;
                    end
    endcase

      
    //to tx_fifo in mac (strip out the headers)
    tx_to_mac = tx_ring_in;
    if ((tx_ring_in.stype == tx_start || tx_ring_in.stype == slot_start) && tx_ring_in.msg.header.pid == MACPID)
      tx_to_mac.stype = tx_start;   //override this value to update the mac header
    else if (tx_ring_in.stype == tx_start && tx_ring_in.msg.header.pid != MACPID)
      tx_to_mac.stype = slot_start; //override this value to avoid mac header update
      
    if (reset) begin
		v_tx_ring_out.stype = tx_none;
		vstate = wait_till_done;
    end
  end
  
  always_ff @(posedge clk) begin
    rstate <= vstate;
    tx_ring_out <= v_tx_ring_out;
  end
  
endmodule