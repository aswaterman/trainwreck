`ifndef RISCV_CONST_VH
`define RISCV_CONST_VH

`include "vuVXU-B8-Config.vh"

//`define IPREFETCH

`define CPU_ADDR_BITS 18
`define CPU_INST_BITS 32
`define CPU_DATA_BITS 128
`define CPU_OP_BITS 4
`define CPU_WMASK_BITS 16
`define CPU_TAG_BITS 15
`define MEM_ADDR_BITS 14  // mem size in bits = MEM_DATA_BITS*2^MEM_ADDR_BITS
`define MEM_DATA_BITS 128
`define MEM_DATA_CYCLES 4 // CL size in bits = MEM_DATA_BITS * MEM_DATA_CYCLES
`define DC_MEM_TAG_BITS 1 // this is log2(# of MSHRs)
`define MEM_TAG_BITS (`DC_MEM_TAG_BITS+2)
`define MEM_L2TAG_BITS (`MEM_TAG_BITS+2)

`define PCR_STATUS   5'd0
`define PCR_EPC      5'd1
`define PCR_BADVADDR 5'd2
`define PCR_EVEC     5'd3
`define PCR_COUNT    5'd4
`define PCR_COMPARE  5'd5
`define PCR_CAUSE    5'd6
`define PCR_MEMSIZE  5'd8
`define PCR_LOG      5'd10
`define PCR_COREID   5'd12
`define PCR_TOHOST   5'd16
`define PCR_FROMHOST 5'd17
`define PCR_VECBANK  5'd18
`define PCR_CONSOLE  5'd31
`define PCR_K0       5'd24
`define PCR_K1       5'd25

`define LG_PCR_MEMSIZE (`ceilLog2(`MEM_DATA_BITS/8 << (`MEM_ADDR_BITS-12)))

`ifdef ASIC
`define VC_SIMPLE_QUEUE(w,d) vcQueue_simple_pf #((w),(d),`ceilLog2(d))
`define VC_PIPE_QUEUE(w,d) vcQueue_pipe_pf #((w),(d),`ceilLog2(d))
`define VC_FLOW_QUEUE(w,d) vcQueue_flow_pf #((w),(d),`ceilLog2(d))
`else
`define VC_SIMPLE_QUEUE(w,d) vcQueue_simple_pf #((w),(d),`ceilLog2(d))
`define VC_PIPE_QUEUE(w,d) vcQueue_pipe_pf #((w),(d),`ceilLog2(d))
`define VC_FLOW_QUEUE(w,d) vcQueue_flow_pf #((w),(d),`ceilLog2(d))
`endif
`define VC_SIMPLE1_QUEUE(w) vcQueue_simple1_pf #(w)
`define VC_PIPE1_QUEUE(w) vcQueue_pipe1_pf #(w)
`define VC_FLOW1_QUEUE(w) vcQueue_flow1_pf #(w)

`define BR_N    4'd0
`define BR_EQ   4'd1
`define BR_NE   4'd2
`define BR_LT   4'd3
`define BR_LTU  4'd4
`define BR_GE   4'd5
`define BR_GEU  4'd6
`define BR_J    4'd7
`define BR_JR   4'd8

`define PC_4   3'd0
`define PC_BTB 3'd1
`define PC_EX4 3'd2
`define PC_BR  3'd3
`define PC_J   3'd4
`define PC_JR  3'd5
`define PC_PCR 3'd6

`define KF_Y  1'b1
`define KF_N  1'b0

`define REN_Y 1'b1
`define REN_N 1'b0

`define A2_X     2'd0
`define A2_0     2'd0
`define A2_SEXT  2'd1
`define A2_RS2   2'd2
`define A2_SPLIT 2'd3

`define A1_X    1'b0
`define A1_RS1  1'b0
`define A1_LUI  1'b1

`define FN_X     4'dx
`define FN_ADD   4'd0
`define FN_SUB   4'd8
`define FN_SL    4'd1
`define FN_SLT   4'd2
`define FN_SLTU  4'd3
`define FN_XOR   4'd4
`define FN_SR    4'd5
`define FN_SRA   4'd13
`define FN_OR    4'd6
`define FN_AND   4'd7

`define DW_X   1'bx
`define DW_32  1'b0
`define DW_64  1'b1

`define DW_XPR (xpr64 ? `DW_64 : `DW_32)

`define MUL_X     3'dx
`define MUL_64    `VAU0_64
`define MUL_64H   `VAU0_64H
`define MUL_64HU  `VAU0_64HU
`define MUL_64HSU `VAU0_64HSU
`define MUL_32    `VAU0_32
`define MUL_32H   `VAU0_32H
`define MUL_32HU  `VAU0_32HU
`define MUL_32HSU `VAU0_32HSU

`define MUL_XPR    (xpr64 ? `MUL_64    : `MUL_32   )
`define MUL_XPRH   (xpr64 ? `MUL_64H   : `MUL_32H  )
`define MUL_XPRHU  (xpr64 ? `MUL_64HU  : `MUL_32HU )
`define MUL_XPRHSU (xpr64 ? `MUL_64HSU : `MUL_32HSU)

`define DIV_X    3'dx
`define DIV_64D  3'd0
`define DIV_64DU 3'd1
`define DIV_64R  3'd2
`define DIV_64RU 3'd3
`define DIV_32D  3'd4
`define DIV_32DU 3'd5
`define DIV_32R  3'd6
`define DIV_32RU 3'd7

`define DIV_XPRD  (xpr64 ? `DIV_64D  : `DIV_32D )
`define DIV_XPRDU (xpr64 ? `DIV_64DU : `DIV_32DU)
`define DIV_XPRR  (xpr64 ? `DIV_64R  : `DIV_32R )
`define DIV_XPRRU (xpr64 ? `DIV_64RU : `DIV_32RU)

`define M_N 1'b0
`define M_Y 1'b1

`define M_X       4'd0
`define M_XRD     4'b0000 // integer load
`define M_XWR     4'b0001 // integer store
`define M_FRD     4'b0010 // FP load
`define M_FWR     4'b0011 // FP store
`define M_FLA     4'b0100 // flush all lines
`define M_RST     4'b0101 // reset all lines
`define M_XA_ADD  4'b1000
`define M_XA_SWAP 4'b1001
`define M_XA_AND  4'b1010
`define M_XA_OR   4'b1011
`define M_XA_MIN  4'b1100
`define M_XA_MAX  4'b1101
`define M_XA_MINU 4'b1110
`define M_XA_MAXU 4'b1111

`define OP_IS_XWR(x) ((x) == `M_XWR)

`define OP_IS_AMO(x) ((x) == `M_XA_ADD  || (x) == `M_XA_SWAP || \
                      (x) == `M_XA_AND  || (x) == `M_XA_OR   || \
                      (x) == `M_XA_MIN  || (x) == `M_XA_MINU || \
                      (x) == `M_XA_MAX  || (x) == `M_XA_MAXU)

`define MT_X  3'd0
`define MT_B  3'b000
`define MT_H  3'b001
`define MT_W  3'b010
`define MT_D  3'b011
`define MT_BU 3'b100
`define MT_HU 3'b101
`define MT_WU 3'b110

`define WEN_N 1'b0
`define WEN_Y 1'b1

`define WA_X  1'd0
`define WA_RD 1'd0
`define WA_RA 1'd1

`define RA    5'd1

`define WB_X   2'd0
`define WB_PC  2'd0
`define WB_ALU 2'd1
`define WB_PCR 2'd2
`define WB_VEC 2'd3

`define X 1'b0
`define N 1'b0
`define Y 1'b1

`define Y_SH (xpr64 | ~dpath_inst[15])

`define FPU_N 1'b0
`define FPU_Y (HAS_FPU ? 1'b1 : 1'b0)

`define FWBQ_N 1'b0
`define FWBQ_Y 1'b1

`define FSDQ_N 1'b0
`define FSDQ_Y 1'b1

`define MEM_RQ_DEPTH 4
`define XP_SDQ_DEPTH 4
`define FP_SDQ_DEPTH 4
`define LOAD_WBQ_DEPTH 4
`define FP_LOAD_WBQ_DEPTH 4
`define MUL_WBQ_DEPTH 4
`define DIV_WBQ_DEPTH 2
`define FPU_WBQ_DEPTH 4
`define FP_CMDQ_DEPTH 4

`define VEC_CMDQ_DEPTH 8
`define VEC_XIMM1Q_DEPTH 4
`define VEC_XIMM2Q_DEPTH 4

`define VEC_N 1'b0
`define VEC_Y (HAS_VECTOR ? 1'b1 : 1'b0)

`define VEC_X   1'bx
`define VEC_VL  1'b0
`define VEC_CFG 1'b1

`define VCMD_I 3'd0
`define VCMD_F 3'd1
`define VCMD_TX 3'd2
`define VCMD_TF 3'd3
`define VCMD_MX 3'd4
`define VCMD_MF 3'd5
`define VCMD_X 3'dx

`define VIMM_VLEN 2'd0
`define VIMM_ALU 2'd1
`define VIMM_RS1 2'd2
`define VIMM_X 2'dx

`endif // RISCV_CONST_VH
