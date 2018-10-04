`include "riscvConst.vh"
`include "macros.vh"

module riscvCoreDRAMAdapter
(
  input clk,
  input reset,

  input                       mem_req_val,
  output                      mem_req_rdy,
  input                       mem_req_rw,
  input [`MEM_ADDR_BITS-1:0]  mem_req_addr,
  input [`MEM_DATA_BITS-1:0]  mem_req_data,
  input [`MEM_TAG_BITS-1:0]   mem_req_tag,

  output                      mem_resp_val,
  output [`MEM_DATA_BITS-1:0] mem_resp_data,
  output [`MEM_TAG_BITS-1:0]  mem_resp_tag,

  mem_controller_interface.yunsup user_if
);

  bit tagq_rdy;

  assign user_if.mem_req_val = mem_req_val & tagq_rdy;
  assign mem_req_rdy = user_if.mem_req_rdy & tagq_rdy;
  assign user_if.mem_req_rw = mem_req_rw;
  assign user_if.mem_req_addr = mem_req_addr;
  assign user_if.mem_req_data = mem_req_data;
  assign mem_resp_val = user_if.mem_resp_val;
  assign mem_resp_data = user_if.mem_resp_data;

  bit reg_cnt;

  always_ff @(posedge clk)
  begin
    if (reset)
      reg_cnt <= '0;
    else if (mem_resp_val)
      reg_cnt <= reg_cnt + 1'b1;
  end

  `VC_SIMPLE_QUEUE(`MEM_TAG_BITS,32) tagq
  (
    .clk(clk),
    .reset(reset),

    .enq_bits(mem_req_tag),
    .enq_val(mem_req_val & ~mem_req_rw & user_if.mem_req_rdy),
    .enq_rdy(tagq_rdy),

    .deq_bits(mem_resp_tag),
    .deq_val(),
    .deq_rdy(mem_resp_val & (reg_cnt == 1'b1))
  );

endmodule
