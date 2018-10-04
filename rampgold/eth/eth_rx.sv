//-------------------------------------------------------------------------------------------------  
// File:        eth_rx.sv
// Author:      Zhangxi Tan 
// Description: 1000 BASE-T Ethernet DMA RX logic. Basically, it strips out the header and send 
//              the formatted request on the rx pipe.
//-------------------------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
import libdebug::*;
import libiu::*;
import libconf::*;
import libtm::*;
import libeth::*;
`else
`include "../cpu/libiu.sv"
`include "../tm/libtm.sv"
`include "libeth.sv"

`endif

//ring interface             
module eth_dma_rx(
input  bit reset,
input  bit clk,

input  eth_rx_pipe_data_type   rx_from_mac,  
output eth_rx_pipe_data_type   rx_pipe_out,

input  eth_tx_ring_data_type   tx_ring_in,
output eth_tx_ring_data_type   tx_ring_out
);

//MAC signals
bit [47:0]    mac_addr;
bit           mac_init;

//ack unit signals
eth_rx_pipe_data_type   v_rx_pipe_out, r_rx_pipe_out;

typedef enum bit [1:0] {rx_idle, rx_header, rx_send, rx_drop} rx_state_type;

typedef struct {  
  rx_state_type state;
  bit           isBcast;
  bit           isPktMine;
  bit [3:0]     small_rx_len;   //rx word length for <60 byte packet
//  bit [7:0]     pid;          //buffer pid 
//  bit [7:0]     packet_type;  //packet type
}rx_fsm_reg_type;

rx_fsm_reg_type   rstate, vstate;

bit            rx_word_count_en, rx_word_count_rst;
bit [3:0]      rx_word_count;     

always_comb begin
  vstate = rstate;
  rx_word_count_rst = reset;
  rx_word_count_en = '0;
 
  v_rx_pipe_out.stype    = rx_none;
  v_rx_pipe_out.msg.data = rx_from_mac.msg.data;
 
  unique case (rstate.state)
  rx_idle: begin
              rx_word_count_rst = '1;
              vstate.isBcast = '0;
              vstate.isPktMine = '0;
              
              if (rx_from_mac.stype == rx_data) begin
                rx_word_count_en  = '1;
                rx_word_count_rst = '0;
                vstate.state = rx_header;
                
                if (&rx_from_mac.msg.data) vstate.isBcast = '1;
                if (rx_from_mac.msg.data == mac_addr[31:0]) vstate.isPktMine = '1;                                  
              end
           end
  rx_header: begin
              if (rx_from_mac.stype == rx_data) begin
                rx_word_count_en = '1;
                
                if (rx_word_count == 1) begin       //srcmac[15:0], dstmac[15:0]
                  vstate.isBcast  = rstate.isBcast & (&rx_from_mac.msg.data[15:0]);
                  vstate.isPktMine = rstate.isPktMine & (rx_from_mac.msg.data[15:0] == mac_addr[47:32]); 
                  //vstate.tmpaddr[15:0]  = rx_from_mac.msg.data[31:16];                                   //store source address
                end
                else if (rx_word_count == 3) begin  //L/T, pad/rx length
                  vstate.state = rx_drop;       //drop the current packet.
                  if  (rx_from_mac.msg.data[15:0] == ldsts_big_endian(protocolTypeRAMP) ) begin
                    if (rstate.isPktMine || (rstate.isBcast & ~mac_init)) begin    //accept broadcast packet only when the MAC address is not configured
                      vstate.state = rx_header;
                      vstate.small_rx_len = rx_from_mac.msg.data[27:24];
                    end
                  end
                end
                else if (rx_word_count == 4) begin  //sequence number
                  rx_word_count_rst  = '1;
                  
                  //construct rx packet header
                  //this signals will be used to generate rx message header
                  v_rx_pipe_out.stype         = rx_start;
                  v_rx_pipe_out.msg.header.ptype  = rx_from_mac.msg.data[7:0];
                  v_rx_pipe_out.msg.header.pid    = rx_from_mac.msg.data[15:8];
                  v_rx_pipe_out.msg.header.seqnum = ldsts_big_endian(rx_from_mac.msg.data[31:16]);
                  
                  vstate.state = rx_send;
                end                  
              end
              else if (rx_from_mac.stype == rx_end) begin                     
                rx_word_count_rst = '1;     //corrupted packet
                vstate.state = rx_idle;                
              end
            end            
  rx_send: begin //rx_send;
            if (rx_from_mac.stype == rx_data)  begin              
              if (rx_word_count < rstate.small_rx_len) begin  //drop padding bytes
                rx_word_count_en = '1;
                v_rx_pipe_out.stype = rx_data;
              end
              else if (rstate.small_rx_len == 15) 
                v_rx_pipe_out.stype = rx_data;
            end
            else if (rx_from_mac.stype == rx_end) begin
                  v_rx_pipe_out.stype = rx_end;
                  vstate.state = rx_idle;
            end
         end
  rx_drop: if (rx_from_mac.stype == rx_end) vstate.state = rx_idle;
  endcase
  
  if (reset) begin
  	  v_rx_pipe_out.stype = rx_none;
	  vstate.state = rx_idle;
  end
end


always_ff @(posedge clk) begin  
  rstate <= vstate;  
  
  r_rx_pipe_out <= v_rx_pipe_out;
  
  if (rx_word_count_rst)
    rx_word_count <= '0;
  else if (rx_word_count_en)    
    rx_word_count <= rx_word_count + 1;
end


//instantiate mac ram
  eth_mac_ram  mac_addr_ram(.*, .rx_pipe_in(r_rx_pipe_out));
endmodule