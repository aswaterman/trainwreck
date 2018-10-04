`include "macros.vh"
`include "riscvConst.vh"

module riscvHTIF
(
  input  bit          clk,
  input  bit          rst,

  input  logic        in_val,
  input  logic [63:0] in_bits,

  input  logic        out_rdy,
  output logic        out_val,
  output logic [63:0] out_bits,

  output logic        htif_start,
  output logic        htif_fromhost_wen,
  output logic [31:0] htif_fromhost,
  input  logic [31:0] htif_tohost,
  output logic        htif_req_val,
  input  logic        htif_req_rdy,
  output logic  [3:0] htif_req_op,
  output logic [31:0] htif_req_addr,
  output logic [63:0] htif_req_data,
  output logic  [7:0] htif_req_wmask,
  output logic [11:0] htif_req_tag,
  input  logic        htif_resp_val,
  input  logic [63:0] htif_resp_data,
  input  logic [11:0] htif_resp_tag,

  output logic        error
);

  localparam MAX_PACKET_WORDS = 3;

  typedef enum logic [2:0]
  {
    state_read,
    state_process,
    state_cpu_req,
    state_cpu_wait,
    state_respond,
    state_error
  } state_t;

  typedef enum logic [3:0]
  {
    cmd_read_mem,
    cmd_write_mem,
    cmd_read_cr,
    cmd_write_cr,
    cmd_start,
    cmd_stop,
    cmd_ack,
    cmd_nack
  } cmd_t;
  
  state_t state, next_state;

  logic [15:0] cmd, seqno;
  logic [31:0] paysize, incoming_paysize;
  logic [63:0] addr;
  logic [63:0] payload;

  logic [`ceilLog2(MAX_PACKET_WORDS)-1:0] words, next_words;
  logic [63:0] buf_ram [MAX_PACKET_WORDS-1:0];

  always_ff @(posedge clk)
  begin
    if(in_val)
      buf_ram[words] <= in_bits;
    else
    begin
      if(state != state_respond && next_state == state_respond)
        buf_ram[0] <= {(cmd == cmd_read_mem || cmd == cmd_read_cr) ? 32'd8 : 32'd0, seqno, 12'b0, cmd_ack};

      if(state == state_process && cmd == cmd_read_cr || state == state_cpu_wait)
        buf_ram[2] <= state == state_process ? {32'd0, htif_tohost} : htif_resp_data;
    end
  end

  logic cmd_val, seqno_val, paysize_val, cmd_needs_cpu_req, cmd_needs_cpu_resp;

  always_comb
  begin
    {paysize,seqno,cmd} = buf_ram[0];
    addr = buf_ram[1];
    payload = buf_ram[2];

    cmd_val = cmd == cmd_read_mem || cmd == cmd_write_mem ||
              cmd == cmd_read_cr  || cmd == cmd_write_cr  ||
              cmd == cmd_start    || cmd == cmd_stop;
    seqno_val = '1;
    cmd_needs_cpu_resp
      = cmd == cmd_read_mem || cmd == cmd_write_mem || cmd == cmd_start;
    cmd_needs_cpu_req = cmd_needs_cpu_resp || cmd == cmd_write_mem;

    paysize_val = cmd == cmd_write_mem || cmd == cmd_write_cr ||
                  cmd == cmd_read_mem || cmd == cmd_read_cr   ? (paysize == 8)
                :                                               (paysize == 0);
    incoming_paysize = cmd == cmd_read_mem || cmd == cmd_read_cr ? 0 : paysize;
  end

  always_comb
  begin
    next_words = '0;

    case(state)
      state_read: begin
        next_state = words == MAX_PACKET_WORDS      ? state_error
                   : words == 1 && !cmd_val         ? state_error
                   : words == 1 && !seqno_val       ? state_error
                   : words == 1 && !paysize_val     ? state_error
                   : in_val && words >= 1 &&
                     words - 1 == incoming_paysize[31:3] ? state_process
                   :                                  state_read;
        next_words = words + in_val;
      end
      state_process: begin
        next_state = in_val                         ? state_error
                   : cmd == cmd_start && htif_start ? state_error
                   : cmd == cmd_stop && !htif_start ? state_error
                   : cmd_needs_cpu_req              ? state_cpu_req
                   :                                  state_respond;
      end
      state_cpu_req: begin
        next_state = in_val                             ? state_error
                   : htif_req_rdy && cmd_needs_cpu_resp ? state_cpu_wait
                   : htif_req_rdy                       ? state_respond
                   :                                      state_cpu_req;
      end
      state_cpu_wait: begin
        next_state = in_val        ? state_error
                   : htif_resp_val ? state_respond
                   :                 state_cpu_wait;
      end
      state_respond: begin
        next_state = in_val                              ? state_error
                   : out_rdy && words == 1+paysize[31:3] ? state_read
                   :                                       state_respond;
        next_words = next_state == state_read ? '0 : words + out_rdy;
      end
      state_error: begin
        next_state = state_error;
      end
      default: begin
        next_state = state_t'('x);
      end
    endcase
  end

  always_ff @(posedge clk)
  begin
    if(rst)
    begin
      words <= '0;
      state <= state_read;
    end
    else
    begin
      words <= next_words;
      state <= next_state;
    end

    //if(state != next_state)
    //  $display("transition to state %s",next_state);

    if(rst)
      htif_start <= '0;
    else if(state == state_process && cmd == cmd_stop || next_state == state_respond && cmd == cmd_start)
    begin
      htif_start <= (cmd == cmd_start);
      //synthesis translate_off
      if(cmd == cmd_stop)
        $finish;
      //synthesis translate_on
    end
  end

  assign out_val = state == state_respond;
  assign out_bits = buf_ram[words];

  assign htif_fromhost = payload[31:0];
  assign htif_fromhost_wen = cmd == cmd_write_cr && state == state_process;

  assign htif_req_val = state == state_cpu_req;
  assign htif_req_op = cmd == cmd_write_mem ? `M_XWR
                     : cmd == cmd_read_mem  ? `M_XRD
                     :                        `M_FLA;
  assign htif_req_addr = addr[31:0];
  assign htif_req_data = payload;
  assign htif_req_wmask = '1;
  assign htif_req_tag = '0;

  assign error = state == state_error;

endmodule


module serialHTIF_rx
(
  input  bit          clk,
  input  bit          rst,

  input  logic        serial_val,
  input  logic [ 7:0] serial_bits,

  output logic        htif_val,
  output logic [63:0] htif_bits
);

  logic [2:0] byte_cnt;

  always_ff @(posedge clk)
  begin
    if(rst)
    begin
      byte_cnt <= '0;
    end
    else
    begin
      htif_val <= serial_val && byte_cnt == '1;

      if(serial_val)
      begin
        htif_bits <= {serial_bits, htif_bits[63:8]};
        byte_cnt <= byte_cnt+1;
      end
    end
  end

endmodule


module serialHTIF_tx
(
  input  bit          clk,
  input  bit          rst,

  output logic        htif_rdy,
  input  logic        htif_val,
  input  logic [63:0] htif_bits,

  input  logic        serial_rdy,
  output logic        serial_val,
  output logic [ 7:0] serial_bits
);

  logic val;
  logic [63:0] bits;
  logic [2:0] byte_cnt;

  always_ff @(posedge clk)
  begin
    if(htif_rdy && htif_val)
      bits <= htif_bits;
    else if(serial_rdy && serial_val)
      bits <= {8'bx, bits[63:8]};

    if(rst)
    begin
      val <= '0;
      byte_cnt <= '0;
    end
    else
    begin
      if(htif_rdy && htif_val)
        val <= '1;
      else if(serial_val && serial_rdy && byte_cnt == '1)
        val <= '0;

      if(serial_rdy && serial_val)
        byte_cnt <= byte_cnt+1;
    end
  end

  assign htif_rdy = ~val;
  assign serial_val = val;
  assign serial_bits = bits[7:0];

endmodule


module riscvHTIFSerialAdapter
(
  input  bit          clk,
  input  bit          rst,

  input  logic        serial_rx_val,
  input  logic [ 7:0] serial_rx_bits,

  output logic        htif_in_val,
  output logic [63:0] htif_in_bits,

  input  logic        serial_tx_rdy,
  output logic        serial_tx_val,
  output logic [ 7:0] serial_tx_bits,

  output logic        htif_out_rdy,
  input  logic        htif_out_val,
  input  logic [63:0] htif_out_bits
);

  serialHTIF_rx rx
  (
    .clk(clk),
    .rst(rst),

    .serial_val(serial_rx_val),
    .serial_bits(serial_rx_bits),

    .htif_val(htif_in_val),
    .htif_bits(htif_in_bits)
  );

  serialHTIF_tx tx
  (
    .clk(clk),
    .rst(rst),

    .htif_rdy(htif_out_rdy),
    .htif_val(htif_out_val),
    .htif_bits(htif_out_bits),

    .serial_rdy(serial_tx_rdy),
    .serial_val(serial_tx_val),
    .serial_bits(serial_tx_bits)
  );

endmodule
