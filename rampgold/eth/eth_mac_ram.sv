//-------------------------------------------------------------------------------------------------  
// File:        eth_mac_ram.sv
// Author:      Zhangxi Tan 
// Description: Ethernet mac address ram. Add your own i2c logic if you want to use EEPROM
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

//ACK payload format (update MAC)
//0-5:  dst mac
//6-11: src mac
//12:   packet type (ack or nack)
//13-14:sequence number
//15 :  pid
//16-: payload 

//sequence number is not used currently, as this unit is idempotent
module eth_mac_ram (input bit reset,
                        input  bit clk,
                        output bit [47:0]              mac_addr,
                        output bit                     mac_init,        //is mac address is configured
                        //rx pipe
                        input  eth_rx_pipe_data_type   rx_pipe_in,                                                
                        output eth_rx_pipe_data_type   rx_pipe_out,
                        //tx ring interface
                        input  eth_tx_ring_data_type   tx_ring_in,
                        output eth_tx_ring_data_type   tx_ring_out                        
);    

typedef enum bit [2:0]  {mac_ram_idle, mac_ram_read, mac_ram_ack_wait_token, mac_ram_ack_send, mac_ram_ack_wait_append} mac_ram_state_type;

bit mac_addr_we, word_count_en, word_count_rst;
bit [1:0]     word_count;

typedef struct {
  mac_ram_state_type   state;   
  bit [31:0]           txheader[0:2];
  bit [15:0]           seqnum;
}mac_ram_reg_type;

mac_ram_reg_type vstate, rstate;

eth_rx_pipe_data_type	v_rx_pipe_out;
eth_tx_ring_data_type   v_tx_ring_out;

always_comb begin
  vstate = rstate;
  word_count_rst = reset;
  word_count_en  = '0;
  
  v_rx_pipe_out = rx_pipe_in;
  v_tx_ring_out = tx_ring_in;
  
  mac_addr_we = '0;
  
  unique case(rstate.state)
  mac_ram_idle: begin 
                word_count_rst = '1;
                if (rx_pipe_in.stype == rx_start && rx_pipe_in.msg.header.pid == MACPID && rx_pipe_in.msg.header.ptype == rstPacketType) begin    //only accept reset packet
                  vstate.state = mac_ram_read;  
                  vstate.seqnum = rx_pipe_in.msg.header.seqnum;
                end
              end
  mac_ram_read: begin
                  if (rx_pipe_in.stype == rx_data) begin
                    word_count_en = '1;                    
//                    vstate.txheader[0:2] = {rstate.txheader[1:2],rx_pipe_in.msg.data};      
					vstate.txheader[0] = rstate.txheader[1];
					vstate.txheader[1] = rstate.txheader[2];
					vstate.txheader[2] = rx_pipe_in.msg.data;
                  end
                  else if (rx_pipe_in.stype == rx_end) begin
                    if (word_count < 2 || rx_pipe_in.msg.data[0]) vstate.state = mac_ram_idle;  //corrupted frame
                    else begin
                      mac_addr_we = '1;                          //update mac
                      vstate.state = mac_ram_ack_wait_token;     //send ack
                    end
                  end                    
              end
  mac_ram_ack_wait_token : begin //  mac_ram_ack
              word_count_rst = '1;
              if (tx_ring_in.stype == tx_start_empty) begin   //empty token
                v_tx_ring_out.stype = tx_start;
                v_tx_ring_out.msg.header.pid = MACPID;
                v_tx_ring_out.msg.header.seqnum = ldsts_big_endian(rstate.seqnum);
                v_tx_ring_out.msg.header.ptype = ackPacketType;
                
                vstate.state = mac_ram_ack_send;      //start sending payload
              end
              else if (tx_ring_in.stype == tx_start)     //token with something (this should never happen if mac_ram is the first unit on the tx ring
                vstate.state = mac_ram_ack_wait_append;            

            end
  mac_ram_ack_wait_append : begin            
                if (tx_ring_in.stype == tx_none) begin
                  v_tx_ring_out.stype = slot_start;
                  v_tx_ring_out.msg.header.pid = MACPID;
                  v_tx_ring_out.msg.header.seqnum = ldsts_big_endian(rstate.seqnum);
                  v_tx_ring_out.msg.header.ptype = ackPacketType;                  
                  
                  vstate.state = mac_ram_ack_send;
                end
            end            
  default : begin     //send data;
              word_count_en        = '1;
              
              v_tx_ring_out.stype    = slot_data;
              v_tx_ring_out.msg.data = rstate.txheader[0];
//              vstate.txheader[0:2] = {rstate.txheader[1:2],rx_pipe_in.msg.data}; 
			  vstate.txheader[0] = rstate.txheader[1];
			  vstate.txheader[1] = rstate.txheader[2];
			  vstate.txheader[2] = rx_pipe_in.msg.data;
              
              if (word_count == 3) begin
                v_tx_ring_out.msg.data = {ldsts_big_endian(rstate.seqnum), MACPID, ackPacketType};
                vstate.state = mac_ram_idle;
              end                
            end
  endcase

  if (reset) begin
	vstate.state = mac_ram_idle;
	
	v_rx_pipe_out.stype = rx_none;
	v_tx_ring_out.stype = tx_none;
  end
end

  
always_ff @(posedge clk) begin
  rstate <= vstate;
  
  rx_pipe_out <= v_rx_pipe_out;                                                
  tx_ring_out <= v_tx_ring_out;
  
  if (reset) begin
    mac_addr <= '0;
    mac_init <= '0;
  end
  else begin
    if (mac_addr_we) begin 
      mac_addr <= {rstate.txheader[2], rstate.txheader[1][31:16]};
      mac_init <= '1;
    end
  end
  
  if (word_count_rst) word_count <= '0;
  else if (word_count_en) word_count <= word_count + 1;
end

endmodule