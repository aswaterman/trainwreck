import libstd::*;
import libconf::*;

module rs232_rx_ctrl
(
  input  bit       clk,
  input  bit       rst,

  output bit       val,
  output bit [7:0] bits,
  output bit       error,

  input  bit       RxD
);

  `ifdef MODEL_TECH
  parameter int BAUD = 1000000000*CLKMUL/(CLKDIV*CLKIN_PERIOD)/4;
  localparam int FILTER_BITS = 2;
  `else
  parameter int BAUD = 9600;
  localparam int FILTER_BITS = 16;
  `endif
  parameter int NOISY = 0;

  localparam int CLOCKS_PER_BIT = 1000000000*CLKMUL/(BAUD*CLKDIV*CLKIN_PERIOD);

  logic [FILTER_BITS-1:0] RxD_history;
  logic RxD_filtered;

  always_ff @(posedge clk) begin
    if(rst)
      RxD_history <= '1;
    else
      RxD_history <= {RxD, RxD_history[FILTER_BITS-1:1]};

    if(rst)
      RxD_filtered <= '1;
    else if(RxD_history == '0 || RxD_history == '1)
      RxD_filtered <= RxD_history[0];
  end

  logic [log2x(CLOCKS_PER_BIT)-1:0] cnt;
  logic [7:0] inreg;
  logic [3:0] bitcnt;

  logic rs232_tick, rs232_sample, start;
  assign rs232_tick = cnt == CLOCKS_PER_BIT-1;
  assign rs232_sample = cnt == CLOCKS_PER_BIT/2-1;
  assign start = (bitcnt == 0 || bitcnt == 10 && rs232_tick) && RxD_filtered == '0;

  always_ff @(posedge clk) begin
    cnt <= start ? 1 : rs232_tick ? 0 : cnt+1;

    if(rst)
      bitcnt <= '0;
    else if(start || (rs232_tick && bitcnt != 0))
      bitcnt <= bitcnt == 10 ? '0 : bitcnt+1;

    if(rs232_sample && bitcnt != 10)
      inreg <= {RxD_filtered,inreg[7:1]};

    if(rst) begin
      val <= '0;
      error <= '0;
    end else begin
      val <= rs232_sample && bitcnt == 10 && RxD_filtered == '1;
      error <= rs232_sample && bitcnt == 10 && RxD_filtered == '0;
    end

    //synthesis translate_off
    if(NOISY && val)
      $display("serial read %c",bits);
    //synthesis translate_on
  end

  assign bits = inreg;

endmodule
