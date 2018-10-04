//
// this module reads dma commands from the FIFO and issues them to the DMA controller
//
 
`timescale 1ns / 1ps

`ifndef SYNP94
import libdebug::*;
`else
`include "../cpu/libiu.sv"
`endif

module dma_control (
	input	bit		clk,
	input	bit		reset,
	input 	bit		start_dma_empty,
	input 	bit		fifo_empty,
	input	bit [31:0]	fifo_data,
	input	bit		dma_cmd_ack,
	input	bit		dma_done,
	output	bit		fifo_read,
	output bit start_dma_re,
	output  debug_dma_cmdif_in_type dma_cmd_in,
	output	bit		send_data
);

	typedef enum bit [1:0] {dma_idle, dma_start, dma_write, dma_wait} dma_control_state_type;
	dma_control_state_type	state, nstate;

	bit [7:0] cmd_count;
	bit [7:0] done_count;
	bit done_count_reset;
	bit cmd_count_reset;
	bit [31:0] cmd_reg;
	bit store_cmd;
	
	debug_dma_cmdif_in_type 	v_cmd_in;

  always_comb begin
     nstate = state;
     fifo_read = '0;
     send_data = '0;
     start_dma_re = '0;
     cmd_count_reset = '0;
     done_count_reset = '0;
     store_cmd = '0;
	
     v_cmd_in.tid           = cmd_reg[25:20];
     v_cmd_in.addr_reg.addr = fifo_data[29:0];          //target virtual address		
     v_cmd_in.addr_we       = '0;
		
     v_cmd_in.ctrl_reg.buf_addr = cmd_reg[19:10];	//starting location in buffer
     v_cmd_in.ctrl_reg.count    = cmd_reg[9:0];		//amount of data to process
     v_cmd_in.ctrl_reg.cmd      = dma_OP;		//default command
     v_cmd_in.ctrl_we           = '0;				


	unique case (state)
	dma_idle: begin
		cmd_count_reset = '1;
		done_count_reset = '1;
		if (~start_dma_empty) begin
			nstate = dma_start;
			start_dma_re = '1;
			fifo_read = '1;
		end
  end
  
	dma_start: begin
		store_cmd = '1;
		fifo_read = '1;
		nstate = dma_write;
	end
	dma_write: begin
		v_cmd_in.ctrl_we = '1;
		v_cmd_in.addr_we = '1;
		if (dma_cmd_ack) begin
			if (fifo_empty)
				nstate = dma_wait;
			else begin
				nstate = dma_start;
				fifo_read = '1;
			end
		end
	end
	dma_wait: begin
		if (done_count == cmd_count) begin
			send_data = '1;
			nstate = dma_idle;
		end
	end
	endcase
  end

  always_ff @(posedge clk) begin
     if (reset)
        state <= dma_idle;
     else 
	state <= nstate;

     dma_cmd_in <= v_cmd_in;

     if (cmd_count_reset)
	cmd_count <= '0;
     else if (store_cmd)
	cmd_count <= cmd_count + 1;

     if (done_count_reset)
	done_count <= '0;
     else if (dma_done)
	done_count <= done_count + 1;

     if (store_cmd)
	cmd_reg <= fifo_data;
	
   end
endmodule