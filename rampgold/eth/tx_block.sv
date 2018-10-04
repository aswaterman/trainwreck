`timescale 1ns / 1ps

module eth_tx_block #(
  parameter mac_addr = 48'h112233445566)
(
	input	bit		clk,
	input	bit		reset,
	input	bit		tx_ack,
	input	bit		ack_empty,
	input	bit		ack_data,
	input	bit		send_data_empty,
	input bit [15:0] tx_len,
	input	bit [31:0]	din,
	
	output bit ack_re,
	output bit send_data_re,
	output	bit [7:0]	tx_data,
	output	bit		tx_en,
	output	bit [9:0]	addr,
	
	input bit [3:0] mac_lsn
);

  typedef enum bit [2:0] {tx_idle, tx_header_start, tx_header_data, tx_send_nack, tx_send_data} tx_block_state_type;

  tx_block_state_type state, nstate;
  bit [3:0]	rom_addr;
  bit [7:0] 	rom_dout;
  bit 		romcount_reset; 

  bit [10:0]	addr_count;
  bit		addrcount_reset;
  bit 		addrcount_ce;

  bit [1:0]	packet_type;
  bit [1:0]	tx_data_sel;
  bit [1:0]	bram_sel;
  bit [7:0]	bram_data;

  tx_header_rom gen_tx_rom(.addr(rom_addr), .dout(rom_dout), .mac_lsn);

// 4:1 mux to select where outgoing data comes from
  always_comb begin
     unique case (tx_data_sel)
	0: tx_data = rom_dout;
	1: tx_data = bram_data;
	2: tx_data = 8'hAA;
	3: tx_data = 8'hBB;
     endcase
  end

  assign addr = addr_count;
  assign bram_sel = rom_addr[1:0];

// 4:1 mux to select which byte of data word from BRAM to send
  always_comb begin
     unique case (bram_sel)
	0: bram_data = din[31:24];
	1: bram_data = din[23:16];
	2: bram_data = din[15:8];
	3: bram_data = din[7:0];
     endcase
  end

  always_comb begin
     tx_en = '0;
     ack_re = '0;
     send_data_re = '0;
     
     tx_data_sel = '0;
     romcount_reset = '1;
     addrcount_reset = '1;
     addrcount_ce = '0;
     nstate = state;

     unique case (state)
     
     tx_idle: begin
	     if (~ack_empty || ~send_data_empty) 
	       nstate = tx_header_start;
     end
     
     tx_header_start: begin
	       tx_en = '1;
	       if (tx_ack) begin
	         romcount_reset = '0;
	       nstate = tx_header_data;
    	    end
     end
     
     tx_header_data: begin
        tx_en = '1;
	      romcount_reset = '0;
	      if (rom_addr == 13 && ~ack_empty && ~ack_data) 
	      begin
	         ack_re = '1;	        
	     	   nstate = tx_send_nack;
	     	end
	      if (rom_addr == 15 && ~ack_empty && ack_data)
	      begin
	         ack_re = '1;
	         nstate = tx_idle;
	      end
	      if (rom_addr == 15 && ~send_data_empty) 
	      begin
	         send_data_re = '1;
	         if (tx_len == 0)
		          nstate = tx_idle;
		       else
		          nstate = tx_send_data;
		    end
     end
        
     tx_send_nack: begin
	      tx_en = '1;
	      tx_data_sel = 2'b11;
	      romcount_reset = '0;
	      if (rom_addr == 15)
		       nstate = tx_idle;
     end
     
     tx_send_data: begin
	       addrcount_reset = '0;
	       tx_en = '1;
	       romcount_reset = '0;
	       tx_data_sel = 2'b01;
	       if (bram_sel == 1)
		        addrcount_ce = '1;
	       if (bram_sel == 3 && addr_count == tx_len)
		        nstate = tx_idle;
     end
     
     endcase
  end

  always_ff @(posedge clk) begin
    if (reset)
        state <= tx_idle;
    else 
	     state <= nstate;

    if (romcount_reset)
        rom_addr <= '0;
    else 
        rom_addr <= rom_addr + 1;

    if (addrcount_reset)
	     addr_count <= '0;
    else if (addrcount_ce)
	     addr_count <= addr_count+1;

  end
endmodule

module tx_header_rom #(
  parameter mac_addr = 48'h112233445566)
(input bit [3:0] addr, output bit [7:0] dout, input bit [3:0] mac_lsn);	
	always_comb begin
		unique case(addr)
		0: dout = 8'hFF;
		1: dout = 8'hFF;
		2: dout = 8'hFF;
		3: dout = 8'hFF;
		4: dout = 8'hFF;
		5: dout = 8'hFF;
		6: dout = mac_addr[47:40];
		7: dout = mac_addr[39:32];
		8: dout = mac_addr[31:24];
		9: dout = mac_addr[23:16];
		10: dout = mac_addr[15:8];
		11: dout = {mac_addr[7:4], mac_lsn};
		12: dout = 8'h88;
		13: dout = 8'h88;
		14: dout = 8'hAA;
		15: dout = 8'hAA;
		endcase
	end
endmodule