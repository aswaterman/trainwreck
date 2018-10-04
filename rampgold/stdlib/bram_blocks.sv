//------------------------------------------------------------------------------   
// File:        bram_blocks.sv
// Author:      Zhangxi Tan
// Description: BRAM  using the memory compiler
//------------------------------------------------------------------------------  
`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
`else
`include "libstd.sv"
`endif


//simple dual-port ram (one write, one read)
module bram_sdp #(parameter int DWIDTH = 32, parameter int DEPTH = 1024, parameter bit DOREG=1)(input bit rclk,
                                             input  bit wclk,
                                             input  bit rst,
                                             input  bit [log2x(DEPTH)-1:0]      waddr, raddr,
                                             input  bit [DWIDTH-1:0] din,
                                             input  bit we,
                                             output bit [DWIDTH-1:0] dout);
                                             
        (* syn_ramstyle="block_ram"*) bit [DWIDTH-1:0]       mem[0:DEPTH-1];
        bit [DWIDTH-1:0]                rdata, r_dout;
//      bit [log2x(DEPTH)-1:0]          raddr_reg;
                                             
        always_ff @(posedge wclk) begin
        //write port
                if (we)
                        mem[waddr] <= din;
        end          

        //read port
        always_comb begin
//          rdata = mem[raddr_reg];     
          dout = (DOREG) ? r_dout : rdata;
        end

        always_ff @(posedge rclk) begin                                     
//                raddr_reg <= raddr;
		          rdata <= mem[raddr];                     
                //output register
                if (rst)
                       r_dout <= '0;
                else
                       r_dout <= rdata;
        end  
                                                                                          
endmodule


module bram_sdp_sync #(parameter int DWIDTH = 32, parameter int DEPTH = 1024, parameter bit DOREG=1)(input bit clk,
                                             input  bit rst,
                                             input  bit [log2x(DEPTH)-1:0]      waddr, raddr,
                                             input  bit [DWIDTH-1:0] din,
                                             input  bit we,
                                             output bit [DWIDTH-1:0] dout);
                                             
        (* syn_ramstyle="block_ram"*) bit [DWIDTH-1:0]       mem[0:DEPTH-1];
        bit [DWIDTH-1:0]                rdata, r_dout;

        //read port
        always_comb begin
          dout = (DOREG) ? r_dout : rdata;
        end
        
        function bit[DWIDTH-1:0] bram_ff();
            bit [DWIDTH-1:0] ret;

            ret = mem[raddr];                     
            
            if (we)
              mem[waddr] = din;
              
            return ret;
        endfunction

        always_ff @(posedge clk) begin                                     
              rdata <= bram_ff();                     
        
               //output register
               if (rst)
                   r_dout <= '0;
               else
                   r_dout <= rdata;
        end                                                                                            
endmodule


//dual port read first (this is not synthesizable)
/*
module bram_dp_readfirst #(parameter int DWIDTH = 32, parameter int DEPTH = 1024, parameter int DOAREG=1, parameter int DOBREG=1 )(input bit clka,
                                             input  bit clkb,
                                             input  bit rst,
                                             input  bit [log2x(DEPTH)-1:0]      addra, addrb,
                                             input  bit [DWIDTH-1:0] dina, dinb,
                                             input  bit wea, web,
                                             output bit [DWIDTH-1:0] doa, dob);
                                             
        (* syn_ramstyle="block_ram"*) bit [DWIDTH-1:0]       mem[0:DEPTH-1];
        bit [DWIDTH-1:0]                t_doa, t_dob, r_doa, r_dob;

        function bit[DWIDTH-1:0] bram_ff(bit [log2x(DEPTH)-1:0] addr, bit we, bit [DWIDTH-1:0] din);
          bit [DWIDTH-1:0]  dout;
          
          dout = mem[addr];
          
          if (we) 
            mem[addr] = din;
          
          return dout;
        endfunction

        //port A                                     
        always @(posedge clka) begin
          if (DOAREG) begin
            if (rst)
              r_doa <= '0;
            else
              r_doa <= t_doa;
          end
            
          t_doa <= bram_ff(addra, wea, dina);
        end          

        //port B
        always @(posedge clkb) begin
          if (DOBREG) begin
            if (rst)
              r_dob <= '0;
            else
              r_dob <= t_dob;
          end
            
          t_dob <= bram_ff(addrb, web, dinb);
        end          

        always_comb begin
          doa = (DOAREG) ? r_doa : t_doa;
          dob = (DOBREG) ? r_dob :t_dob;
        end
endmodule
*/

module bram_sp_readfirst #(parameter int DWIDTH = 32, parameter int DEPTH = 1024, parameter bit DOREG=1)(
                                             input  bit clk,
                                             input  bit rst,
                                             input  bit [log2x(DEPTH)-1:0]      addr,
                                             input  bit [DWIDTH-1:0] din,
                                             input  bit we,
                                             output bit [DWIDTH-1:0] dout);
                                             
        (* syn_ramstyle="block_ram"*) bit [DWIDTH-1:0]       mem[0:DEPTH-1];
        bit [DWIDTH-1:0]                rdata, r_dout;
                                             
        //read port
        assign dout = (DOREG) ? r_dout : rdata;

        task bram_ff();
          rdata = mem[addr];
          
          if (we)
            mem[addr] = din;
        endtask

        always_ff @(posedge clk) begin                                     
                bram_ff();
                
                //output register
                if (rst)
                       r_dout <= '0;
                else
                       r_dout <= rdata;
        end  
                                                                                          
endmodule

//dual port bram with only one write (R/W) port (port b) 
module bram_dp_sync_onewrite #(parameter int DWIDTH = 32, parameter int DEPTH = 1024, parameter int DOAREG=1, parameter int DOBREG=1)(
                                             input  bit clk,
                                             input  bit rst,
                                             input  bit [log2x(DEPTH)-1:0]      addra, addrb,
                                             input  bit [DWIDTH-1:0] din,
                                             input  bit we,
                                             output bit [DWIDTH-1:0] doa, dob);
                                             
        (* syn_ramstyle="block_ram"*) bit [DWIDTH-1:0]       mem[0:DEPTH-1];
        bit [DWIDTH-1:0]                rdata[0:1], r_dout[0:1];
                                             
        //read port
        always_comb begin
         doa = (DOAREG) ? r_dout[0] : rdata[0];          
         dob = (DOBREG) ? r_dout[1] : rdata[1];
        end

        task bram_ff();
          rdata[0] = mem[addra];
          rdata[1] = mem[addrb];
          
          if (we)
            mem[addrb] = din;
        endtask

        always_ff @(posedge clk) begin                                                     
                bram_ff();
                
                //output register
                if (rst)
                       r_dout <= '{default:0};
                else
                       r_dout <= rdata;
        end                                                                                            
endmodule