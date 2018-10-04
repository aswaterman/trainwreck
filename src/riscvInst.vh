`ifndef RISCV_INST_VH
`define RISCV_INST_VH

//--------------------------------------------------------------------
// Instruction opcodes
//--------------------------------------------------------------------

`define NOP        (`ADDI & 32'b00000_00000_000000000000_111_1111111) // nop is addiw $x0, $x0, $x0

`include "inst.v"

//--------------------------------------------------------------------
// Instruction bundle
//--------------------------------------------------------------------

`define INST_OPCODE    31:25
`define INST_OPCODE5   31:27
`define INST_RA        24:20
`define INST_RB        19:15
`define INST_RC        4:0
`define INST_SHAMT     5:0
`define INST_IMM       11:0
`define INST_IMM_SIGN  15
`define INST_BIGIMM    19:0
`define INST_TARGET    26:0

module unpackInst
(
  input [31:0] inst
);

  wire [4:0] ra = inst[`INST_RA];
  wire [4:0] rb = inst[`INST_RB];
  wire [4:0] rc = inst[`INST_RC];
  wire [5:0] shamt = inst[`INST_SHAMT];
  wire [11:0] imm = inst[`INST_IMM];
  wire [26:0] target = inst[`INST_TARGET];

endmodule

//--------------------------------------------------------------------
// Instruction disassembly
//--------------------------------------------------------------------

`ifndef SYNTHESIS

// make sure to change disasm-modelsim.cc if you change argument sizes
`ifdef VCS
extern "A" void riscv_disasm
(
  input  bit  [31:0] insn,
  output bit [255:0] dasm,
  output bit  [47:0] minidasm
);
`else // MODEL_TECH
task riscv_disasm
(
  input  bit  [31:0] insn,
  output bit [255:0] dasm,
  output bit  [47:0] minidasm
);
  dasm = 256'd0;
  minidasm = 48'd0;
endtask
`endif

module disasmInst
(
  input [31:0] inst
);

  bit [255:0] dasm;
  bit [47:0] minidasm;

  always @(inst)
  begin
    if (inst === 32'bx) begin
      $sformat(dasm,     "x                    ");
      $sformat(minidasm, "x    ");
    end
    else
      riscv_disasm(inst, dasm, minidasm);
  end
endmodule

module printInst
(
  input clk,
  input [31:0] inst,
  input log_control
);

  bit [255:0] dasm;
  reg [47:0] minidasm;

  always @(inst)
    riscv_disasm(inst, dasm, minidasm);

  always @(posedge clk)
  begin
    if (log_control)
      $display("INST: %s", minidasm);
  end

endmodule
`endif
`endif
