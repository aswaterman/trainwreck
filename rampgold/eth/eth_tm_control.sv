//-------------------------------------------------------------------------------------------------  
// File:        eth_tm_control.sv
// Author:      Zhangxi Tan 
// Description: DMA timing model controls for ramp gold 
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
import libiu::*;
import libconf::*;
import libtm::*;
import libeth::*;
`else
`include "../cpu/libiu.sv"
`include "../tm/libtm.sv"
`include "libeth.sv"

`endif

module eth_tm_control(
        input bit clk,
        input bit reset,
        //rx pipe
        input  eth_rx_pipe_data_type   rx_pipe_in,                                                
        output eth_rx_pipe_data_type   rx_pipe_out,
        //tx ring interface
        input  eth_tx_ring_data_type   tx_ring_in,
        output eth_tx_ring_data_type   tx_ring_out,                       

        //timing model interface
        output  dma_tm_ctrl_type                dma2tm,
        output  bit                             cpurst
        );
        
      typedef enum bit [2:0] {eth_tm_idle, eth_tm_set, eth_tm_ack_wait_token,eth_tm_ack_wait_append, eth_tm_drop} eth_tm_state_type;
      
      typedef struct {
        eth_tm_state_type     state;        
        bit [15:0]            seqnum;       //old sequence number
        bit [15:0]            tmpseq;
        //tm states   (can be set through I/O bus?)
        dma_tm_ctrl_type      dma2tm;
        bit                   tm_packet;
        bit                   nack;
      }eth_tm_reg_type; 
      eth_tm_reg_type vstate, rstate;

	  eth_rx_pipe_data_type	  v_rx_pipe_out;
      eth_tx_ring_data_type   v_tx_ring_out;

      
      bit             isRetry;
      bit             dma2tm_we;
      
      always_comb begin         
        v_rx_pipe_out = rx_pipe_in;       
        v_tx_ring_out = tx_ring_in;
        
        vstate = rstate;
        vstate.tm_packet = '1;
        vstate.nack = rx_pipe_in.msg.data[0];
        
        isRetry = isRetransmit(rstate.seqnum, rx_pipe_in.msg.header.seqnum);        
                
        dma2tm_we = '0;
        cpurst = '0;
                
        unique case (rstate.state)
        eth_tm_idle: begin
                      if (rx_pipe_in.stype == rx_start && rx_pipe_in.msg.header.pid == TMPID) begin
                          vstate.tmpseq = rx_pipe_in.msg.header.seqnum;
                          
                          if (rx_pipe_in.msg.header.ptype == tmPacketType) begin
                            vstate.state = (isRetry) ? eth_tm_drop : eth_tm_set; 
                          end
                          else if (rx_pipe_in.msg.header.ptype == rstPacketType) begin
                            if (!isRetry) begin
                              vstate.tm_packet = '0;
                              vstate.state = eth_tm_set;
//                              vstate.dma2tm.threads_total = NTHREAD-1;
//                              vstate.dma2tm.threads_active = NTHREAD-1;                                                    
                              vstate.dma2tm.tm_dbg_ctrl = tm_dbg_stop;
                            end 
                            else
                              vstate.state = eth_tm_drop;
                          end                    
                      end
                    end
        eth_tm_set : begin
                        if (rx_pipe_in.stype == rx_data) begin
                          if (rstate.tm_packet) begin
                            vstate.dma2tm.threads_total  = rx_pipe_in.msg.data[0 +: NTHREADIDMSB+1];
                            vstate.dma2tm.threads_active = rx_pipe_in.msg.data[8 +: NTHREADIDMSB+1];
                            vstate.dma2tm.tm_dbg_ctrl = rx_pipe_in.msg.data[16] ? tm_dbg_start : tm_dbg_stop;
                          end
                        end
                        else if (rx_pipe_in.stype == rx_end) begin        
                          if (!rx_pipe_in.msg.data[0]) begin
                            if (!rstate.tm_packet)  
                              cpurst = '1;                          
                            
                            vstate.seqnum = rstate.tmpseq;      //update sequenc number
                            dma2tm_we = '1;
                          end
                          
                          vstate.state = eth_tm_ack_wait_token;
                        end
                   end
        eth_tm_drop: begin //drop retry packet
                      if (rx_pipe_in.stype == rx_end) begin
                        vstate.state = eth_tm_ack_wait_token;
                        vstate.nack = rx_pipe_in.msg.data[0];
                      end
                  end
        eth_tm_ack_wait_token : begin  //eth_tm_ack
                      if (tx_ring_in.stype == tx_start_empty) begin   //empty token
                         v_tx_ring_out.stype = tx_start;
                         v_tx_ring_out.msg.header.pid = TMPID;
                         v_tx_ring_out.msg.header.seqnum = ldsts_big_endian(rstate.seqnum);
                         v_tx_ring_out.msg.header.ptype = (rstate.nack)? nackPacketType : ackPacketType;
          
                         vstate.state = eth_tm_idle;
                      end
                      else if (tx_ring_in.stype == tx_start)     //token with something (this should never happen if mac_ram is the first unit on the tx ring
                        vstate.state = eth_tm_ack_wait_append;            
                  end
        default : begin
                    if (tx_ring_in.stype == tx_none) begin
                        v_tx_ring_out.stype = slot_start;
                        v_tx_ring_out.msg.header.pid = TMPID;
                        v_tx_ring_out.msg.header.seqnum = ldsts_big_endian(rstate.seqnum);
                        v_tx_ring_out.msg.header.ptype = (rstate.nack)? nackPacketType : ackPacketType;                  
                        
                        vstate.state = eth_tm_idle;
                      end
                  end
                  
        endcase

        if (reset) begin
          vstate.state  = eth_tm_idle;
          vstate.seqnum = '0;
        
          vstate.dma2tm.threads_total  = NTHREAD-1;
          vstate.dma2tm.threads_active = NTHREAD-1;          
          vstate.dma2tm.tm_dbg_ctrl = tm_dbg_stop;
          
          v_tx_ring_out.stype = tx_none;
          v_rx_pipe_out.stype = rx_none;
          
          dma2tm_we = '1;
        end        
      end
            
      always_ff @(posedge clk) begin
        rstate <= vstate;        
        
        tx_ring_out <= v_tx_ring_out;
        rx_pipe_out <= rx_pipe_in;
          
        if (dma2tm_we)
            dma2tm <= rstate.dma2tm;            
      end      
endmodule