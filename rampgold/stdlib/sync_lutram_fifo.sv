//------------------------------------------------------------------------------   
// File:        sync_lutram_fifo.sv
// Author:      Zhangxi Tan
// Description: Synchronize LUTRAM fifo implemenation. 
//------------------------------------------------------------------------------  
`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
`else
`include "libstd.sv"
`endif

//the depth must be power of two
module sync_lutram_fifo #(parameter DWIDTH=1, parameter DEPTH=64, parameter bit DOREG=1)(input bit clk,
                                             input  bit rst,
                                             input  bit [DWIDTH-1:0] din,
                                             input  bit we,
                                             input  bit re,
                                             output bit	empty,
                                             output bit full,
                                             output bit [DWIDTH-1:0] dout);
                                             
   (* syn_ramstyle = "select_ram" *)	bit [DWIDTH-1:0]	 fifo_ram[0:DEPTH-1];
   
   bit [DWIDTH-1:0] ram_dout, r_dout;
                                           
   (* syn_maxfan = 16 *) bit [log2x(DEPTH)-1:0] head, tail, nhead, ntail;
                                           
                                              
    always_ff @(posedge clk) begin		
      //synthesis translate_off
      assert (DEPTH == 2**log2x(DEPTH)) else $error ("%m : depth must be power of two");      
      //synthesis translate_on

      if (rst) begin
         tail <= '0;
         head <= '0;
         
         empty <= '1;
         full <= '0;
      end
      else begin
         tail <= (we) ? ntail : tail;
         head <= (re) ? nhead : head;
         
         unique case({we, re})
         2'b10 : begin empty <= '0; full <= (head == ntail); end
         2'b01 : begin empty <= (nhead == tail); full <= '0; end
         default : empty <= empty;
         endcase
      end

      //RAMs
      if (we) fifo_ram[tail] <= din;
      if (DOREG)                                     
        r_dout <= ram_dout;                                               
    end 
                                           
    always_comb begin
      nhead = head + 1;
      ntail = tail + 1;
    
      ram_dout = fifo_ram[head]; 
     
      dout = (DOREG) ? r_dout : ram_dout;       
    end
                                                                                        
    //synthesis translate_off
    property chk_overflow_underflow;
      disable iff(rst)
        @(posedge clk)
          (full |-> we == 0) and (empty |-> re == 0);        
    endproperty
    assert property(chk_overflow_underflow) else $error("%m : sync lutram fifo over/underflow");
    //synthesis translate_on                                             
endmodule

//two enqueue one dequeue (no output register is defined)
//depth must be power of 2
module sync_lutram_fifo_2w_1r #(parameter DWIDTH=1, parameter DEPTH=64, parameter bit DOREG=1)(input bit clk,
                                             input  bit ce,       //i.e. gclk.ce
                                             input  bit clk2x,
                                             input  bit rst,
                                             input  bit [DWIDTH-1:0] din[0:1],
                                             input  bit [1:0] we,
                                             input  bit re,
                                             output bit	empty,
                                             output bit full,
                                             output bit [DWIDTH-1:0] dout);
                                             
    (* syn_ramstyle = "select_ram" *)	bit [DWIDTH-1:0]	 fifo_ram[0:DEPTH-1];                                                                                                                                  
    (* syn_maxfan = 16 *) bit [log2x(DEPTH)-1:0] head, tail, nhead, ntail;
    bit [DWIDTH-1:0] l_din;
    bit              l_we;
    bit [DWIDTH-1:0] ram_dout, r_dout;
    
    always_comb begin
      //read 
      nhead = head + 1;      
      //write
      ntail = tail + 1; 
      
      l_we  = (ce) ? we[0] : we[1];        //we[0] -> ram, and din[0] -> ram are MCP 
      l_din = (ce) ? din[0] : din[1];
      
      ram_dout = fifo_ram[head];            
      
      dout = (DOREG) ? r_dout : ram_dout;    
    end
    
    //read
    always_ff @(posedge clk) begin		
      //synthesis translate_off
      assert (DEPTH == 2**log2x(DEPTH)) else $error ("%m : depth must be power of two");      
      //synthesis translate_on

      if (rst) begin
        head <= '0;
        empty <= '1;
      end
      else begin
        head <= (re) ? nhead : head;
        
        unique case({|we, re})
        2'b10 : begin empty <= '0; full <= (head == ntail); end
        2'b01 : begin empty <= (nhead == tail); full <= '0; end
        default : begin 
                    empty <= (we[0] == 1'b0 || we[1] == 1'b0) ? empty : '1;
                  end
        endcase  
      end      
    end
    
    //write    
    always_ff @(posedge clk2x) begin
      if (rst) 
        tail <= '0;
      else 
       tail <= (l_we) ? ntail : tail;
    
     //RAMs
      if (l_we) fifo_ram[tail] <= l_din;
      if (ce & DOREG) r_dout <= ram_dout;  
    end

  //synthesis translate_off
  property chk_overflow_underflow;
    disable iff(rst)
      @(posedge clk)
        (full |-> l_we == 0) and (empty |-> re == 0);        
  endproperty
  assert property(chk_overflow_underflow) else $error("%m : sync lutram fifo over/underflow");
  //synthesis translate_on                                                                                           
endmodule
