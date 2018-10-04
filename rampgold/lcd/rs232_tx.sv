import libstd::*;
import libconf::*;

module rs232_tx_ctrl
(
  input  bit       clk,
  input  bit       rst,

  output bit       rdy,
  input  bit       val,
  input  bit [7:0] bits,

  output bit       TxD
);

  `ifdef MODEL_TECH
  parameter int BAUD = 1000000000*CLKMUL/(CLKDIV*CLKIN_PERIOD)/4;
  `else
  parameter int BAUD = 9600;
  `endif
  parameter int NOISY = 0;

  localparam int CLOCKS_PER_BIT = 1000000000*CLKMUL/(BAUD*CLKDIV*CLKIN_PERIOD);

  logic [log2x(CLOCKS_PER_BIT)-1:0] cnt;
  logic [8:0] outreg;
  logic [3:0] bitcnt;

  logic rs232_tick;
  assign rs232_tick = cnt == CLOCKS_PER_BIT-1;

  always_ff @(posedge clk) begin
    if(rst)
      cnt <= '0;
    else
      cnt <= rs232_tick ? '0 : cnt+1;

    if(rst)
      bitcnt <= '0;
    else if(rdy && val || rs232_tick)
      bitcnt <= bitcnt == 10 ? '0 : bitcnt+1;

    if(rst)
      outreg <= '1;
    else if(rdy && val) begin
      // ModelSim is fucking retarded.  outreg <= {bits,1'b0} crashes it!!
      outreg[0] <= 1'b0;
      for(int i = 0; i < 8; i++)
        outreg[i+1] <= bits[i];
    end
    else if(rs232_tick)
      outreg <= {1'b1,outreg[8:1]};
    
    //synthesis translate_off
    if(NOISY && rdy && val)
      $display("serial write %c",bits);
    //synthesis translate_on
  end

  assign rdy = bitcnt == '0 && cnt == '0;
  assign TxD = outreg[0];

endmodule
