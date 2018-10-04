`ifndef VXU_CONFIG
`define VXU_CONFIG

`define INT_STAGES 3'd2
`define IMUL_STAGES 3'd3
`define FMA_STAGES 3'd5
`define FCONV_STAGES 3'd3

`define SHIFT_BUF_READ 3
`define SHIFT_BUF_WRITE (`FMA_STAGES+4)

`define M0 2'b00
`define MR 2'b01
`define ML 2'b10
`define MI 2'b11

`define R_ 1'bx
`define RX 1'b0
`define RF 1'b1

`define I_ 2'dx
`define II 2'd0
`define IB 2'd1
`define IL 2'd2

`define DW__ 1'bx
`define DW32 1'b0
`define DW64 1'b1

`define FP_ 1'bx
`define FPS 1'b0
`define FPD 1'b1

`define VIU_X     5'dx
`define VIU_ADD   5'd1
`define VIU_SLL   5'd2
`define VIU_SLT   5'd3
`define VIU_SLTU  5'd4
`define VIU_XOR   5'd5
`define VIU_SRL   5'd6
`define VIU_SRA   5'd7
`define VIU_OR    5'd8
`define VIU_AND   5'd9
`define VIU_SUB   5'd10
`define VIU_IDX   5'd11
`define VIU_MOV   5'd12
`define VIU_FSJ   5'd13
`define VIU_FSJN  5'd14
`define VIU_FSJX  5'd15
`define VIU_FEQ   5'd16
`define VIU_FLT   5'd17
`define VIU_FLE   5'd18
`define VIU_FMIN  5'd19
`define VIU_FMAX  5'd20
`define VIU_MOVZ  5'd21
`define VIU_MOVN  5'd22

// in the decode table
`define VAU0_X     2'dx
`define VAU0_M     2'd0
`define VAU0_MH    2'd1
`define VAU0_MHU   2'd2
`define VAU0_MHSU  2'd3

// acutal ops
`define VAU0_32    {`DW32,`VAU0_M}
`define VAU0_32H   {`DW32,`VAU0_MH}
`define VAU0_32HU  {`DW32,`VAU0_MHU}
`define VAU0_32HSU {`DW32,`VAU0_MHSU}
`define VAU0_64    {`DW64,`VAU0_M}
`define VAU0_64H   {`DW64,`VAU0_MH}
`define VAU0_64HU  {`DW64,`VAU0_MHU}
`define VAU0_64HSU {`DW64,`VAU0_MHSU}

`define VAU1_X     3'dx
`define VAU1_ADD   3'd0
`define VAU1_SUB   3'd1
`define VAU1_MUL   3'd2
`define VAU1_MADD  3'd4
`define VAU1_MSUB  3'd5
`define VAU1_NMSUB 3'd6
`define VAU1_NMADD 3'd7

`define VAU2_X     4'dx
`define VAU2_CLTF  4'b0000
`define VAU2_CLUTF 4'b0001
`define VAU2_CWTF  4'b0010
`define VAU2_CWUTF 4'b0011
`define VAU2_MXTF  4'b0100
`define VAU2_CFTL  4'b1000
`define VAU2_CFTLU 4'b1001
`define VAU2_CFTW  4'b1010
`define VAU2_CFTWU 4'b1011
`define VAU2_MFTX  4'b1100
`define VAU2_CDTS  4'b1110
`define VAU2_CSTD  4'b1111

`define SZ_ADDR 32
`define SZ_INST 32
`define SZ_DATA 65
`define SZ_EXC 5
`define SZ_XLEN 64
`define SZ_FLEN 65

`define DEF_ADDR [`SZ_ADDR-1:0]
`define DEF_INST [`SZ_INST-1:0]
`define DEF_DATA [`SZ_DATA-1:0] // data width
`define DEF_EXC [`SZ_EXC-1:0]
`define DEF_XLEN [`SZ_XLEN-1:0]
`define DEF_FLEN [`SZ_FLEN-1:0]

`define SZ_STALL 5

`define RG_VLDQ 4
`define RG_VSDQ 3
`define RG_UTAQ 2
`define RG_UTLDQ 1
`define RG_UTSDQ 0

`define DEF_STALL [`SZ_STALL-1:0]

`define SZ_VIU_FN  11
`define SZ_VAU0_FN 3
`define SZ_VAU1_FN 6
`define SZ_VAU2_FN 7

`define RG_VIU_T  10:7
`define RG_VIU_T0 10:9
`define RG_VIU_T1 8:7
`define RG_VIU_DW 6
`define RG_VIU_FP 5
`define RG_VIU_FN 4:0

`define RG_VAU1_FP 5
`define RG_VAU1_RM 4:3
`define RG_VAU1_FN 2:0
`define RG_VAU2_FP 6
`define RG_VAU2_RM 5:4
`define RG_VAU2_FN 3:0

`define DEF_VIU_FN  [`SZ_VIU_FN-1:0]
`define DEF_VAU0_FN [`SZ_VAU0_FN-1:0]
`define DEF_VAU1_FN [`SZ_VAU1_FN-1:0]
`define DEF_VAU2_FN [`SZ_VAU2_FN-1:0]

`define SZ_VLEN 11
`define SZ_REGLEN 6
`define SZ_REGCNT 6

`define DEF_VLEN [`SZ_VLEN-1:0]  // issue vector length
`define DEF_REGLEN [`SZ_REGLEN-1:0] // issue reg specifier length
`define DEF_REGCNT [`SZ_REGCNT-1:0]

`define SZ_BANK 8
`define SZ_LGBANK 3
`define SZ_LGBANK1 4
`define SZ_BVLEN 3
`define SZ_BREGLEN 8
`define SZ_BOPL 2
`define SZ_BRPORT `SZ_BANK
`define SZ_BWPORT 3

`define DEF_BANK [`SZ_BANK-1:0]
`define DEF_BPTR [`SZ_LGBANK-1:0]
`define DEF_BPTR1 [`SZ_LGBANK:0]
`define DEF_BPTR2 [`SZ_LGBANK+1:0]
`define DEF_BCNT [`SZ_LGBANK:0]
`define DEF_BVLEN [`SZ_BVLEN-1:0]  // bank vector length
`define DEF_BREGLEN [`SZ_BREGLEN-1:0] // bank reg specifier length
`define DEF_BOPL [`SZ_BOPL-1:0]
`define DEF_BRPORT [`SZ_BRPORT-1:0]
`define DEF_BWPORT [`SZ_BWPORT-1:0]

`endif // VXU_CONFIG
