//-------------------------------------------------------------------------------------------------  
// File:        eth_cpu_control.sv
// Author:      Zhangxi Tan 
// Description: DMA cpu controls for ramp gold. RX and TX works in a lock-step mode because 
//              no double buffering
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
import libiu::*;
import libconf::*;
import libdebug::*;
import libeth::*;
`else
`include "../cpu/libiu.sv"
`include "libeth.sv"

`endif


module eth_cpu_control #(parameter bit [7:0] mypid=8'b0)(
        input bit clk,
        input bit reset,
        input iu_clk_type gclk,
        //rx pipe
        input  eth_rx_pipe_data_type   rx_pipe_in,                                                
        output eth_rx_pipe_data_type   rx_pipe_out,
        //tx ring interface
        input  eth_tx_ring_data_type   tx_ring_in,
        output eth_tx_ring_data_type   tx_ring_out,                        

        //cpu dma interface
        output  debug_dma_cmdif_in_type         dma_cmd_in,     //cmd input 
        input 	 bit                             dma_done,		//dma status      
        
        //cpu dma buffer interface
        input  debug_dma_read_buffer_in_type   dma_rb_in,
        output debug_dma_read_buffer_out_type  dma_rb_out,
        input  debug_dma_write_buffer_in_type  dma_wb_in,
        output bit                             sberr,
        output bit                             dberr,
        output bit                             luterr
        ) /* synthesis syn_sharing = on*/;
  typedef enum bit [3:0] {eth_cpu_idle, eth_cpu_buf_addr, eth_cpu_cmd, eth_cpu_data, eth_cpu_drop, eth_cpu_dma_op, eth_cpu_ack_wait_token, eth_cpu_ack_wait_append, eth_cpu_ack_send} eth_cpu_state_type;
        
  typedef struct {
    eth_cpu_state_type    state;
    bit [DMABUFMSB:0]     buf_addr;         
    bit [DMABUFMSB:0]     tx_count;         
    bit [NTHREADIDMSB+1:0]  active_count;
    bit                   isodd;
    bit                   dma_cmd_we;
    bit                   nack;
    bit [15:0]            seqnum;
    bit [31:0]            tmpdata;
    bit [15:0]            tmpseq;
  }eth_cpu_control_reg_type;
  
  eth_cpu_control_reg_type vstate, rstate; 

  eth_rx_pipe_data_type   v_rx_pipe_out;
  eth_tx_ring_data_type   v_tx_ring_out;

  bit                     isRetry;
  bit [DMABUFMSB:0]       next_addr, next_count;         
  
  typedef struct packed{
    bit [DMABUFMSB:0]           buf_addr;  //support up to 1024*4 buffer 
    bit [DMABUFMSB:0]           count;     //dma counter
    bit [NTHREADIDMSB:0]        tid;       //thread id
    bit                         parity;    
  }eth_cmd_fifo_type;     //buffered command fifo
  
  eth_cmd_fifo_type       cmd_fifo_din, cmd_fifo_dout;
  bit                     cmd_fifo_we, cmd_fifo_re, cmd_fifo_empty, cmd_fifo_rst;

  bit [31:0]              le_data;
  
  bit                     r_dma_done;
  
  //dma buffer interface
  debug_dma_read_buffer_in_type   eth_rb_in;
  debug_dma_write_buffer_in_type  eth_wb_in;
  debug_dma_write_buffer_out_type eth_wb_out;		
  
 always_comb begin   
   le_data = ldst_big_endian(rx_pipe_in.msg.data);
   vstate = rstate;
   
   v_rx_pipe_out = rx_pipe_in;
   v_tx_ring_out = tx_ring_in;
   
   isRetry = isRetransmit(rstate.seqnum, rstate.tmpseq);        
   
   eth_wb_in = '{default:0};
   eth_wb_in.addr = rstate.buf_addr;
   
   eth_rb_in.inst = rstate.tmpdata;
   eth_rb_in.data = le_data;
   eth_rb_in.we   = '0;
   eth_rb_in.addr = rstate.buf_addr;
   
   next_addr = rstate.buf_addr + 1;   //adders
   next_count = rstate.tx_count - 1;
   
   if (r_dma_done)
     vstate.active_count =  rstate.active_count - 1;

     
   dma_cmd_in.tid = (rstate.dma_cmd_we) ? cmd_fifo_dout.tid : le_data[DMABUFMSB*2+2 +: NTHREADIDMSB+1];
   dma_cmd_in.addr_reg.addr = rstate.tmpdata[29:0];        //target virtual address
   dma_cmd_in.addr_reg.parity = (LUTRAMPROT) ? rstate.tmpdata[30] : '0;
   dma_cmd_in.addr_we = '0;

   cmd_fifo_din.buf_addr = le_data[DMABUFMSB+1 +: DMABUFMSB+1];         //control register
   cmd_fifo_din.count    = le_data[0 +: DMABUFMSB+1];
   cmd_fifo_din.tid      = le_data[DMABUFMSB*2+2 +: NTHREADIDMSB+1];
   cmd_fifo_din.parity   = (LUTRAMPROT) ? le_data[31] : '0;
   cmd_fifo_we = '0;
   cmd_fifo_re = '0;   
   cmd_fifo_rst = reset;
   
   dma_cmd_in.ctrl_reg.buf_addr = cmd_fifo_dout.buf_addr;
   dma_cmd_in.ctrl_reg.count    = cmd_fifo_dout.count;
   dma_cmd_in.ctrl_reg.cmd      = dma_OP;          //this will help synthesis to optimize unused ram.
   dma_cmd_in.ctrl_reg.parity   = (LUTRAMPROT) ? ^{cmd_fifo_dout.parity, cmd_fifo_dout.tid, dma_OP} : '0;
   dma_cmd_in.ctrl_we  = rstate.dma_cmd_we;

   luterr = (LUTRAMPROT & rstate.dma_cmd_we) ? ^cmd_fifo_dout : '0;
   
   unique case(rstate.state)
   eth_cpu_idle: begin
                	   vstate.buf_addr = '0;
                	   vstate.active_count = '0;
                    vstate.nack = '0;
                    vstate.tx_count = '0;

                    if (rx_pipe_in.stype == rx_start && rx_pipe_in.msg.header.pid == mypid || rx_pipe_in.msg.header.pid == BCASTPID) begin
                      vstate.isodd = '1;
                      if (rx_pipe_in.msg.header.ptype == dataPacketType) begin
                        vstate.state =  eth_cpu_data; vstate.tmpseq = rx_pipe_in.msg.header.seqnum;                        
                      end
                      else if (rx_pipe_in.msg.header.ptype == cmdPacketType) begin
                        vstate.state =  eth_cpu_buf_addr; vstate.tmpseq = rx_pipe_in.msg.header.seqnum;  
                      end
                    end
               end
   eth_cpu_buf_addr: begin
                      if (rx_pipe_in.stype == rx_data) begin
                    			if (!isRetry)
	                        vstate.active_count = le_data[16 +: NTHREADIDMSB+2];
	                        
                        vstate.tx_count = le_data[0 +: DMABUFMSB+1];
                        vstate.state = (isRetry) ? eth_cpu_drop : eth_cpu_cmd;
                      end
                      else if (rx_pipe_in.stype == rx_end) begin //corrupted packet
                        vstate.nack = '1;
                        vstate.state = eth_cpu_ack_wait_token;
                      end
                    end
   eth_cpu_data: begin
                  if (rx_pipe_in.stype == rx_data) begin
                    vstate.tmpdata = le_data;
                    if (!rstate.isodd) begin 
                      eth_rb_in.we = '1;
                      vstate.buf_addr = next_addr;
                    end
                    vstate.isodd = ~rstate.isodd;
                  end
                  else if (rx_pipe_in.stype == rx_end) begin
                    vstate.nack  = rx_pipe_in.msg.data[0];
                    vstate.state = eth_cpu_ack_wait_token;

                    if (!rx_pipe_in.msg.data[0])
                      vstate.seqnum = rstate.tmpseq;      //update sequenc number
                  end
                end
   eth_cpu_cmd: begin
                if (rx_pipe_in.stype == rx_data) begin
                  vstate.tmpdata = le_data;
                  if (!rstate.isodd) begin
                    dma_cmd_in.addr_we = '1;    //write address but not command
                    cmd_fifo_we = '1;           //queue the command till we receive all
                  end
                  
                  vstate.isodd = ~rstate.isodd;
                end
                else if (rx_pipe_in.stype == rx_end) begin
                  if (rx_pipe_in.msg.data[0]) begin  //corrupted packet
                    cmd_fifo_rst = '1;
                    vstate.nack = '1;
                    vstate.state = eth_cpu_ack_wait_token;
                  end  
                  else begin    //finish the packet 
                    vstate.state = eth_cpu_dma_op;
                    vstate.seqnum = rstate.tmpseq;      //update sequenc number                    
                  end
                end                  
              end
   eth_cpu_dma_op : begin                               //issue to dma from FIFO
                      if (!cmd_fifo_empty)
                        cmd_fifo_re = '1;
                      else 
                        vstate.state = eth_cpu_ack_wait_token;                    
                    end                 
   eth_cpu_ack_wait_token: begin
                    if (rstate.nack || rstate.active_count ==0) begin   //wait till write is finished to prevent dma overrun
                      if (tx_ring_in.stype == tx_start_empty) begin   //empty token
                        v_tx_ring_out.stype = tx_start;
                        v_tx_ring_out.msg.header.pid = mypid;
                        v_tx_ring_out.msg.header.seqnum = ldsts_big_endian(rstate.seqnum);
                        v_tx_ring_out.msg.header.ptype = (rstate.nack)? nackPacketType : ackPacketType;

                        vstate.state = (rstate.nack || rstate.tx_count == 0) ? eth_cpu_idle : eth_cpu_ack_send;
                        vstate.buf_addr = next_addr;                        
                        
                        eth_wb_in.addr = next_addr;

                      end
                      else if (tx_ring_in.stype == tx_start)     //token with something (this should never happen if mac_ram is the first unit on the tx ring
                       vstate.state = eth_cpu_ack_wait_append;            
                    end
                  end      
   eth_cpu_ack_wait_append: begin
                      if (tx_ring_in.stype == tx_none) begin
                         v_tx_ring_out.stype = slot_start;
                         v_tx_ring_out.msg.header.pid = mypid;
                         v_tx_ring_out.msg.header.seqnum = ldsts_big_endian(rstate.seqnum);
                         v_tx_ring_out.msg.header.ptype = (rstate.nack)? nackPacketType : ackPacketType;                  
                                                  
                         vstate.state = (rstate.nack || rstate.tx_count == 0) ? eth_cpu_idle : eth_cpu_ack_send;
                         
                         vstate.buf_addr = next_addr;                                                                         
                         eth_wb_in.addr = next_addr;                         
                     end
                  end
   eth_cpu_drop : begin //drop retry packet, but don't drop corrupted retry
                    if (rx_pipe_in.stype == rx_end) begin
                      vstate.state = eth_cpu_ack_wait_token;
                      vstate.nack = rx_pipe_in.msg.data[0];
                    end
                  end
   default : begin
                vstate.buf_addr = next_addr;
                eth_wb_in.addr = next_addr;                
                vstate.tx_count = next_count;
                
                v_tx_ring_out.stype = slot_data;
                v_tx_ring_out.msg.data = ldst_big_endian(eth_wb_out.data);   //ignore the parity check here

                if (rstate.tx_count == 1)
                  vstate.state = eth_cpu_idle;
            end
   endcase

  vstate.dma_cmd_we = cmd_fifo_re;  //we use the "free" output register from the LUTRAM fifo   
  
  if (reset) begin
  	vstate.state = eth_cpu_idle;
  	vstate.seqnum = '0;
  	
  	v_tx_ring_out.stype = tx_none;
  	v_rx_pipe_out.stype = rx_none;
  end
 end

 //synthesis translate_off
 property guard_active_count;
  @(posedge(gclk.clk))
     disable iff (reset)
      dma_done |-> (rstate.active_count > 0);
 endproperty

 assert property (guard_active_count) else $display ("Error: %t dma_done overflow in eth_cpu_control!", $time);
 
 //synthesis translate_on

         
 always_ff @(posedge clk) begin
   rstate <= vstate;

   rx_pipe_out <= v_rx_pipe_out;
   tx_ring_out <= v_tx_ring_out;   
   
   r_dma_done <= dma_done;
 end      
 
 //instantiate cmdfifo
 sync_lutram_fifo #(.DWIDTH($bits(eth_cmd_fifo_type)), .DEPTH(NTHREAD)) cmdfifo(.clk,
                                              .rst(reset),
                                              .din(cmd_fifo_din),
                                              .we(cmd_fifo_we),
                                              .re(cmd_fifo_re),
                                              .empty(cmd_fifo_empty),
                                              .full(),
                                              .dout(cmd_fifo_dout));
//generate the dual-port DMA buffer
debug_dma_buf   gen_dma_buf(.*, .rst(reset), .eth_rx_clk(clk), .eth_tx_clk(clk));  
   
endmodule