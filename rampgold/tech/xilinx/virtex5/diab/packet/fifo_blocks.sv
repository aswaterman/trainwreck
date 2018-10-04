//------------------------------------------------------------------------------   
// File:        fifo_blocks.sv
// Author:      Zhangxi Tan
// Description: FIFO blocks for voq command fifos
//------------------------------------------------------------------------------  
`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
`else
`include "libstd.sv"
`endif


//72*512
module voq_command_fifo #(parameter int DEPTH=512, parameter int WIDTH = 72)(
                                             input  bit wclk,
                                             input  bit rclk,
                                             input  bit rst,
                                             input  bit [DWIDTH-1:0] din,
                                             input  bit re,
                                             input  bit we,
                                             output bit [DWIDTH-1:0] dout, 
                                             output bit empty,
                                             output bit sberr,                //ecc output
                                             output bit dberr);
        bit [63:0]    w_dout;                                         

        always_comb begin
          //parameter check
          //synthesis translate_off
          assert (DEPTH <= 512 && WIDTH <=72) else $error("%m: depth must <=512, width must <= 72);
          //synthesis translate_on
          
          dout = w_dout[0 +: WIDTH];
        end
        
        FIFO36_72 #(        
        .DO_REG(1), // Enable output register (0 or 1)
        // Must be 1 if EN_SYN = "FALSE"
        .EN_ECC_READ("TRUE"),  // Enable ECC decoder, "TRUE" or "FALSE"
        .EN_ECC_WRITE("TRUE"), // Enable ECC encoder, "TRUE" or "FALSE"
        .EN_SYN("FALSE"), // Specifies FIFO as Asynchronous ("FALSE")
        // or Synchronous ("TRUE")
        .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
        
        ) WBfifoA (
        .ALMOSTEMPTY(), // 1-bit almost empty output flag
        .ALMOSTFULL(), // 1-bit almost full output flag
        .DBITERR(dberr), // 1-bit double bit error status output
        .DO(w_dout), // 64-bit data output
        .DOP(), // 4-bit parity data output
        .ECCPARITY(), // 8-bit generated error correction parity
        .EMPTY(empty), // 1-bit empty output flag
        .FULL(), // 1-bit full output flag
        .RDCOUNT(), // 9-bit read count output
        .RDERR(), // 1-bit read error output
        .SBITERR(sberr), // 1-bit single bit error status output
        .WRCOUNT(), // 9-bit write count output
        .WRERR(), // 1-bit write error
        .DI(unsigned'(din)), // 64-bit data input
        .DIP(), // 4-bit parity input
        .RDCLK(rclk), // 1-bit read clock input
        .RDEN(re), // 1-bit read enable input
        .RST(rst), // 1-bit reset input
        .WRCLK(wclk), // 1-bit write clock input
        .WREN(we) // 1-bit write enable input
        );                                             
endmodule

