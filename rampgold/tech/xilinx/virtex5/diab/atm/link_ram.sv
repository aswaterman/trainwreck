//simple dual-port ram (read first), max depth = 16k
`ifndef SYNP94
import libstd::*;
`else
`include "../../../../../stdlib/libstd.sv"
`endif


//read first dual port bram
module link_fifo_ram #(parameter int DWIDTH = 32, parameter int DEPTH = 1024, parameter bit DOREG=1)(input bit clk,
                                             input  bit rst,
                                             input  bit [log2x(DEPTH)-1:0]      waddr, raddr,
                                             input  bit [DWIDTH-1:0] din,
                                             input  bit we,
                                             output bit [DWIDTH-1:0] dout);
  
  parameter int BRAMWIDTH = (log2x(DEPTH) <= 10)? 18 : (log2x(DEPTH)==11)? 9 : (log2x(DEPTH)==12)? 4 : (log2x(DEPTH)==13) ? 2 : 1;
  parameter int NBRAM = (DWIDTH+BRAMWIDTH-1)/BRAMWIDTH;
  
  genvar i;
  
  bit [17:0]  bram_din[0:NBRAM-1];
  bit [17:0]  bram_dout[0:NBRAM-1];
  
  bit [13:0]  bram_waddr, bram_raddr;

  always_comb begin
    bram_din = '{default:0};    
    bram_waddr = '1;
    bram_raddr = '1;
    
    bram_waddr[13 -: log2x(DEPTH)] = waddr;
    bram_raddr[13 -: log2x(DEPTH)] = raddr;
    
    for (int j=0;j<NBRAM;j++) begin
      //bram_din[j] = unsigned'(din[j*BRAMWIDTH +: min(BRAMWIDTH, DWIDTH-j*BRAMWIDTH)]);
      if (j== NBRAM-1) begin
        bram_din[j] = unsigned'(din[j*BRAMWIDTH +:  DWIDTH-(NBRAM-1)*BRAMWIDTH]);
        dout[j*BRAMWIDTH +: DWIDTH-(NBRAM-1)*BRAMWIDTH] = bram_dout[j][0 +: DWIDTH-(NBRAM-1)*BRAMWIDTH];        
      end
      else begin
        bram_din[j] = unsigned'(din[j*BRAMWIDTH +:  BRAMWIDTH]);
        dout[j*BRAMWIDTH +: BRAMWIDTH] = bram_dout[j];
      end
    end
  end
  
  generate                                           
    for (i=0;i<NBRAM;i++) begin
      RAMB18 #(
            .DOA_REG(DOREG), // Optional output registers on A portatm_l1_sched_ram (0 or 1)
            .DOB_REG(0), // Optional output registers on B port (0 or 1)
            .INIT_A(18'h00000), // Initial values on A output patm_l1_sched_ramort
            .INIT_B(18'h00000), // Initial values on B output port
            .READ_WIDTH_A(BRAMWIDTH), // Valid values are 0, 1, 2, 4, 9 or 18
            .READ_WIDTH_B(BRAMWIDTH), // Valid values are 0, 1, 2, 4, 9atm_l1_sched_ram or 18
            .SIM_COLLISION_CHECK("ALL"), // Collision check enable "ALL", "WARNING_ONLY",
            // "GENERATE_X_ONLY" or "NONE"
            .SRVAL_A(18'h00000), // Set/Reset value for A port output
            .SRVAL_B(18'h00000), // Set/Reset value for B port output
            .WRITE_MODE_A("READ_FIRST"), // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE"
            .WRITE_MODE_B("READ_FIRST"), // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE"
            .WRITE_WIDTH_A(BRAMWIDTH), // Valid values are 0, 1, 2, 4, 9 or 18
            .WRITE_WIDTH_B(BRAMWIDTH) // Valid values are 0, 1, 2, 4, 9 or 18
    ) link_ram (
            .DOA(bram_dout[i][15:0]), // 16-bit A port data output
            .DOB(),    // 16-bit B port data output
            .DOPA(bram_dout[i][17:16]), // 2-bit A port parity data output
            .DOPB(), // 2-bit B port parity data output
            .ADDRA(bram_raddr), // 14-bit A port address input
            .ADDRB(bram_waddr), // 14-bit B port address input
            .CLKA(clk), // 1-bit A port clock input
            .CLKB(clk),  // 1-bit B port clock inputWEB
            .DIA(), // 16-bit A port data input
            .DIB(bram_din[i][15:0]), // 16-bit B port data input
            .DIPA(), // 2-bit A port parity data input
            .DIPB(bram_din[i][17:16]), // 2-bit B port parity data input
            .ENA(1'b1), // 1-bit A port enable input
            .ENB(1'b1), // 1-bit B port enable input
            .REGCEA(1'b1), // 1-bit A port register enable input
            .REGCEB(1'b0), // 1-bit B port register enable input
            .SSRA(rst), // 1-bit A port set/reset input
            .SSRB(1'b1), // 1-bit B port set/reset input
            .WEA(2'b0), // 2-bit A port write enable input
            .WEB({we,we}) // 2-bit B port write enable input
    );
    end
  endgenerate
endmodule