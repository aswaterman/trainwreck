module EthernetDDRAdapter
(
  input clk,
  input reset,

  input [63:0] rxq_bits,
  input [7:0]  rxq_aux_bits,
  input        rxq_val,
  output       rxq_rdy,

  output [63:0] txq_bits,
  output [7:0]  txq_aux_bits,
  output        txq_val,
  input         txq_rdy,

  mem_controller_interface.yunsup user_if
);

  localparam RISCV_TYPE = 16'h8888;
  localparam CMD_LOAD = 32'h0;
  localparam CMD_STORE = 32'h1;

  localparam RX_IDLE = 2'd0;
  localparam RX_IGNORE = 2'd1;
  localparam RX_PAYLOAD1 = 2'd2;
  localparam RX_PAYLOAD5 = 2'd3;

  localparam TX_IDLE = 3'd0;
  localparam TX_WAIT = 3'd1;
  localparam TX_HEADER_LD1 = 3'd2;
  localparam TX_HEADER_LD2 = 3'd3;
  localparam TX_HEADER_ST1 = 3'd4;
  localparam TX_HEADER_ST2 = 3'd5;
  localparam TX_BODY = 3'd6;

  localparam MAC_DST = 48'hff_ff_ff_ff_ff_ff;
  localparam MAC_SRC = 48'h01_02_03_04_05_06;

  // rx adapter

  reg [1:0] reg_rx_state, next_rx_state;
  reg [9:0] reg_rx_cnt, next_rx_cnt;
  reg reg_mem_req_rw, next_mem_req_rw;
  reg [31:0] reg_mem_req_addr, next_mem_req_addr;
  reg [255:0] reg_mem_req_data, next_mem_req_data;

  always @(posedge clk)
  begin
    if (reset)
    begin
      reg_rx_state <= RX_IDLE;
      reg_rx_cnt <= 10'd0;
      reg_mem_req_rw <= 1'b0;
      reg_mem_req_addr <= 32'd0;
      reg_mem_req_data <= 64'd0;
    end
    else
    begin
      reg_rx_state <= next_rx_state;
      reg_rx_cnt <= next_rx_cnt;
      reg_mem_req_rw <= next_mem_req_rw;
      reg_mem_req_addr <= next_mem_req_addr;
      reg_mem_req_data <= next_mem_req_data;
    end
  end

  always @(*)
  begin
    next_rx_state = reg_rx_state;

    if (rxq_val)
    begin
      if (reg_rx_state == RX_IDLE)
        next_rx_state = RX_IGNORE;

      if (rxq_aux_bits[6])
        next_rx_state = RX_IDLE;

      if (reg_rx_state == RX_IGNORE && reg_rx_cnt == 10'd1 && rxq_bits[47:32] == RISCV_TYPE)
        next_rx_state = RX_PAYLOAD1;

      if (reg_rx_state == RX_PAYLOAD1 && reg_rx_cnt == 10'd2 && rxq_bits[31:0] == CMD_STORE)
        next_rx_state = RX_PAYLOAD5;
    end
  end

  always @(*)
  begin
    next_rx_cnt = reg_rx_cnt;
    next_mem_req_rw = reg_mem_req_rw;
    next_mem_req_addr = reg_mem_req_addr;
    next_mem_req_data = reg_mem_req_data;

    if (rxq_val)
    begin
      if (reg_rx_state != RX_IDLE)
        next_rx_cnt = reg_rx_cnt + 1'b1;

      if (rxq_aux_bits[6])
        next_rx_cnt = 10'd0;
    end

    if (reg_rx_state == RX_PAYLOAD1 && reg_rx_cnt == 10'd2)
    begin
      next_mem_req_rw = rxq_bits[0];
      next_mem_req_addr = rxq_bits[63:32];
    end

    if (reg_rx_state == RX_PAYLOAD5)
    begin
      case (reg_rx_cnt)
      10'd3: next_mem_req_data[63:0] = rxq_bits;
      10'd4: next_mem_req_data[127:64] = rxq_bits;
      10'd5: next_mem_req_data[191:128] = rxq_bits;
      10'd6: next_mem_req_data[255:192] = rxq_bits;
      endcase
    end
  end

  assign rxq_rdy = (reg_rx_state != RX_IDLE);

  assign user_if.mem_req_val = rxq_val & rxq_aux_bits[6];
  assign user_if.mem_req_rw = reg_mem_req_rw;
  assign user_if.mem_req_addr = reg_mem_req_addr[30:5];
  assign user_if.mem_req_data = reg_mem_req_data;

  // tx adapter

  reg [2:0] reg_tx_state, next_tx_state;
  reg [2:0] reg_tx_cnt, next_tx_cnt;
  reg [255:0] reg_mem_resp_bits;

  always @(posedge clk)
  begin
    if (reset)
    begin
      reg_tx_state <= TX_IDLE;
      reg_tx_cnt <= 3'd0;
      reg_mem_resp_bits <= 256'd0;
    end
    else
    begin
      reg_tx_state <= next_tx_state;
      reg_tx_cnt <= next_tx_cnt;
      
      if (user_if.mem_resp_val)
        reg_mem_resp_bits <= user_if.mem_resp_data;
    end
  end

  always @(*)
  begin
    next_tx_state = reg_tx_state;

    if (txq_rdy)
    begin
      if (reg_tx_state == TX_IDLE && rxq_val && rxq_aux_bits[6])
      begin
        if (reg_rx_state == RX_PAYLOAD1)
          next_tx_state = TX_WAIT;
        else if (reg_rx_state == RX_PAYLOAD5)
          next_tx_state = TX_HEADER_ST1;
      end

      if (reg_tx_state == TX_WAIT && user_if.mem_resp_val)
        next_tx_state = TX_HEADER_LD1;

      if (reg_tx_state == TX_HEADER_LD1)
        next_tx_state = TX_HEADER_LD2;

      if (reg_tx_state == TX_HEADER_LD2)
        next_tx_state = TX_BODY;

      if (reg_tx_state == TX_HEADER_ST1)
        next_tx_state = TX_HEADER_ST2;

      if (reg_tx_state == TX_HEADER_ST2)
        next_tx_state = TX_IDLE;

      if (reg_tx_state == TX_BODY && reg_tx_cnt == 3'd3)
        next_tx_state = TX_IDLE;
    end
  end

  assign txq_bits
    = (reg_tx_state == TX_HEADER_LD1 || reg_tx_state == TX_HEADER_ST1) ? {MAC_SRC[15:0], MAC_DST}
    : (reg_tx_state == TX_HEADER_LD2 || reg_tx_state == TX_HEADER_ST2) ? {16'd0, RISCV_TYPE, MAC_SRC[47:16]}
    : (reg_tx_state == TX_BODY && reg_tx_cnt == 3'd0) ? reg_mem_resp_bits[63:0]
    : (reg_tx_state == TX_BODY && reg_tx_cnt == 3'd1) ? reg_mem_resp_bits[127:64]
    : (reg_tx_state == TX_BODY && reg_tx_cnt == 3'd2) ? reg_mem_resp_bits[191:128]
    : (reg_tx_state == TX_BODY && reg_tx_cnt == 3'd3) ? reg_mem_resp_bits[255:192]
    : 64'd0;
  assign txq_aux_bits = 8'd7;
  assign txq_val = 
    reg_tx_state == TX_HEADER_LD1 || reg_tx_state == TX_HEADER_LD2 ||
    reg_tx_state == TX_HEADER_ST1 || reg_tx_state == TX_HEADER_ST2 ||
    reg_tx_state == TX_BODY;
  assign next_tx_cnt
    = (reg_tx_state == TX_BODY) ? reg_tx_cnt + 1'b1
    : 3'd0;

endmodule
