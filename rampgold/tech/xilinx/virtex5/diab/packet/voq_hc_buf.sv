//------------------------------------------------------------------------------   
// File:        voq_hc_buf.sv
// Author:      Zhangxi Tan
// Description: FIFO blocks for voq command fifos
//------------------------------------------------------------------------------  
`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
`else
`include "libstd.sv"
`endif


//DEPTH == # of physical queues * max flit size / 16 (128-bit) 
module voq_write_buffer #(parameter int DEPTH=512, parameter int DOREG=1)(input bit wclk,
                                             input  bit rclk,
                                             input  bit rst,
                                             input  bit [63:0] din,                 
                                             input  bit we,
                                             input  bit [log2x(DEPTH*2)-1:0]  waddr,    //64-bit address
                                             input  bit [log2x(DEPTH)-1:0]    raddr,    //128-bit read address
                                             output bit [143:0] dout, 
                                             output bit sberr,                //ecc output (used with 
                                             output bit dberr);
        bit [1:0]       bram_we;
        bit [71:0]      w_din[0:1];
        
        bit [1:0]       single_err, double_err;

        bit [8:0]       w_raddr, w_waddr; //used for DEPTH <= 512 only
        

        always_comb begin
          bram_we = '0;
          bram_we[waddr[0]] = we;
          single_err = '0; double_err = '0;
          
          w_raddr = unsigned'(raddr);
          w_waddr = unsigned'(waddr[$left(waddr):1]);
          
          if (DEPTH > 512) begin
            for (int i=0;i<2;i++) 
                     w_din[i] = {bram_dip_ecc(din), din};         
          end
          else
            w_din[i] = unsigned'(din);
          
          sberr = |single_err;
          dberr = |double_err;  
        end
        
        function bit [143:0] shuffle_dout(bit [143:0] a);
          return  {a[143:136], a[71:64], a[135:72], a[63:0]};
        endfunction

        genvar j;
        
        generate 
          if (DEPTH<=512) begin   //instantiate           
            for (j=0;j<2;j++) begin
              RAMB36SDP #(.DO_REG(DOREG), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE("TRUE"),.EN_ECC_SCRUB("TRUE"))
                                                 write_buf (
                                                 .DBITERR(double_err[j]),
                                                 .SBITERR(single_err[j]),
                                                 .DO(dout[j*64 +: 64]),
                                                 .DOP(dout[128+j*8 +: 8]),             
                                                 .DI(w_din[j][0:63]),
                                                 .RDADDR(w_raddr),
                                                 .RDCLK(rclk),
                                                 .RDEN(1'b1),
                                                 .REGCE(1'b1),
                                                 .SSR(rst),
                                                 .WE(8'hFF),
                                                 .WRADDR(w_waddr),
                                                 .WRCLK(gclk.clk2x),
                                                 .WREN(bram_we[j]),
                                                 //unconnected ports
                                                 .DOP(),
                                                 .DIP(),
                                                 .ECCPARITY()
                                                 );
            end
          end
          else begin                      
           bit [143:0]     rdata, r_dout;
           (* syn_ramstyle="block_ram"*) bit [71:0]    mem_lo[0:DEPTH-1], mem_hi[0:DEPTH-1];
                        
           //use memory compiler and soft ECC
           always_ff @(posedge wclk) begin
             if (bram_we[0])
               mem_lo[waddr] <= w_din[0];
             
             if (bram_we[1])
               mem_lo[waddr] <= w_din[1];  
           end
           
           always_ff @(posedge rclk) begin
              rdata[71:0] <= mem_lo[raddr];
              rdata[143:72] <= mem_hi[raddr];               

              //output register
              if (rst)
                     r_dout <= '0;
              else
                     r_dout <= rdata;
           end
           
           assign dout = dout_shuffle((DOREG)? r_dout : rdata);
          end           
        endgenerate
endmodule

//DEPTH == # of physical queues * max flit size / 16 (128-bit) 
module voq_read_buffer #(parameter int DEPTH=512, parameter int DOREG=1)(input bit wclk,
                                             input  bit rclk,
                                             input  bit rst,
                                             output bit [63:0] dout,                 
                                             input  bit we,
                                             input  bit [log2x(DEPTH*2)-1:0]  raddr,    //64-bit address
                                             input  bit [log2x(DEPTH)-1:0]    waddr,    //128-bit write address
                                             input  bit [143:0] din
                                             );
        bit [127:0]     rdata;
        bit [63:0]      rdout;
        (* syn_ramstyle="block_ram"*) bit [127:0]    mem[0:DEPTH-1];
        bit [1:0]       sel;                          
        

        always_comb begin
          if (DOREG)
            dout = r_dout;
          else
            dout = (sel[0]) ? rdata[127:64] : rdata[63:0]
        end
        
        bit [143:0]     rdata, r_dout;
        (* syn_ramstyle="block_ram"*) bit [127:0]    mem_lo[0:DEPTH-1], mem_hi[0:DEPTH-1];
                        
        always_ff @(posedge wclk) begin
            if (we)
               mem[waddr] <= din[127:0];      //discard ECC bits
        end
           
        always_ff @(posedge rclk) begin
            rdata <= mem[raddr[$left(raddr):1]];

            sel <= {raddr[0], sel[1]};
            //output register
            if (rst)
                  r_dout <= '0;
            else
                  r_dout <= (sel[1]) ? rdata[127:64] : rdata[63:0];
        end
endmodule

