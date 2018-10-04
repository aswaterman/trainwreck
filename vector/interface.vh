`ifndef INTERFACE_VH
`define INTERFACE_VH

`define VLENMAX_SZ 11

// vcmdq
`define VCMD_SZ       20

`define VCMD_CMD_SZ   8
`define VCMD_VD_SZ    6
`define VCMD_VS_SZ    6

`define VCMD_CMCODE   19:12
`define VCMD_VD       11:6
`define VCMD_VS       5:0

// vimmq
`define VIMM_SZ       64

`define VIMM_DATA     63:0

// vstrideq
`define VSTRIDE_SZ    32

`define VSTRIDE_DATA  31:0

// vrespq
`define VRESP_SZ      32

// xcmdq
`define XCMD_SZ       20

`define XCMD_CMCODE   19:12
`define XCMD_VD       11:6
`define XCMD_VS       5:0

`define XCMD_CMD_SZ   8
`define XCMD_VD_SZ    6
`define XCMD_VS_SZ    6

// ximmq
`define XIMM_SZ       64

`define XIMM_DATA     63:0

// xrespq
`define XRESP_SZ      1

// xfcmdq

`define XFCMD_SZ      68

`define XFCMD_OP      67:64
`define XFCMD_RS      63:32
`define XFCMD_RT      31:0

`define XFCMD_OP_SZ   4
`define XFCMD_RS_SZ   32
`define XFCMD_RT_SZ   32

// xfrespq
`define XFRESP_SZ     32

// xf interface
`define XFOP_FADD     4'd0
`define XFOP_FSUB     4'd1
`define XFOP_IDIV     4'd2
`define XFOP_IREM     4'd3
`define XFOP_IDIVU    4'd4
`define XFOP_IREMU    4'd5
`define XFOP_FDIV     4'd6
`define XFOP_IMUL     4'd7
`define XFOP_FMUL     4'd8
`define XFOP_FSQRT    4'd9
`define XFOP_CVTSW    4'd10
`define XFOP_CVTWS    4'd11
`define XFOP_CEIL     4'd12
`define XFOP_FLOOR    4'd13
`define XFOP_ROUND    4'd14
`define XFOP_TRUNC    4'd15

// vmcmdq
`define VMCMD_SZ      19

`define VMCMD_CMDCODE 18:11
`define VMCMD_VLEN_M1 10:0

`define VMCMD_CMD_SZ  8
`define VMCMD_VLEN_SZ `VLENMAX_SZ

// vimmq
`define VMIMM_SZ        32

`define VMIMM_DATA      31:0

// vmstrideq
`define VMSTRIDE_SZ     32

`define VMSTRIDE_DATA   31:0

// vmresp
`define VMRESP_SZ       1

`define VM_STCMD_SZ   4+`VMCMD_VLEN_SZ+`VMIMM_SZ+`VMSTRIDE_SZ
`define VM_ISCMD_SZ  `VMCMD_VLEN_SZ+`VMIMM_SZ+`VMSTRIDE_SZ
`define VM_WBCMD_SZ   4+`VMCMD_VLEN_SZ+`VMIMM_SZ+`VMSTRIDE_SZ

// utmcmdq
`define UTMCMD_SZ       19

`define UTMCMD_CMDCODE  18:11
`define UTMCMD_VLEN_M1  10:0

`define UTMCMD_CMD_SZ   8
`define UTMCMD_VLEN_SZ  `VLENMAX_SZ

// utmimmq
`define UTMIMM_SZ       32

`define UTMIMM_DATA     31:0

// utmrespq
`define UTMRESP_SZ      1

`define UT_ISCMD_SZ  `UTMIMM_SZ+`UTMCMD_VLEN_SZ
`define UT_WBCMD_SZ  5+`UTMCMD_VLEN_SZ // add amo
`define UT_STCMD_SZ  6+`UTMIMM_SZ+`UTMCMD_VLEN_SZ // add amo

`define DEF_VXU_CMDQ [`XCMD_SZ-1:0]
`define DEF_VXU_IMMQ [`XIMM_SZ-1:0]
`define DEF_VXU_ACKQ [`XRESP_SZ-1:0]
`define DEF_VMU_VCMDQ [`VMCMD_SZ-1:0]
`define DEF_VMU_VBASEQ [`VMIMM_SZ-1:0]
`define DEF_VMU_VSTRIDEQ [`VMSTRIDE_SZ-1:0]
`define DEF_VMU_VACKQ [`VMRESP_SZ-1:0]
`define DEF_VMU_UTCMDQ [`UTMCMD_SZ-1:0]
`define DEF_VMU_UTIMMQ [`UTMIMM_SZ-1:0]
`define DEF_VMU_UTACKQ [`UTMRESP_SZ-1:0]

`endif // INTERFACE_VH
