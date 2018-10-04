`ifndef VXU_COMMANDS
`define VXU_COMMANDS

`define CMD_X          8'bx

`define CMD_VVCFGIVL   8'b00_0000_00
`define CMD_VSETVL     8'b00_0000_10
`define CMD_VF         8'b00_0000_11

`define CMD_FENCE_L_V  8'b00_001_100
`define CMD_FENCE_G_V  8'b00_001_101
`define CMD_FENCE_L_CV 8'b00_001_110
`define CMD_FENCE_G_CV 8'b00_001_111

`define CMD_LDWB       8'b00_010_000
`define CMD_STAC       8'b00_010_001

`define CMD_VMVV       8'b01_000_000
`define CMD_VMSV       8'b01_001_000
`define CMD_VMST       8'b01_010_000
`define CMD_VMTS       8'b01_011_000
`define CMD_VFMVV      8'b01_000_001
`define CMD_VFMSV      8'b01_001_001
`define CMD_VFMST      8'b01_010_001
`define CMD_VFMTS      8'b01_011_001

`define CMD_VLD        8'b1_00_0_0_0_11
`define CMD_VLW        8'b1_00_0_0_0_10
`define CMD_VLWU       8'b1_00_0_0_1_10
`define CMD_VLH        8'b1_00_0_0_0_01
`define CMD_VLHU       8'b1_00_0_0_1_01
`define CMD_VLB        8'b1_00_0_0_0_00
`define CMD_VLBU       8'b1_00_0_0_1_00
`define CMD_VSD        8'b1_00_1_0_0_11
`define CMD_VSW        8'b1_00_1_0_0_10
`define CMD_VSH        8'b1_00_1_0_0_01
`define CMD_VSB        8'b1_00_1_0_0_00

`define CMD_VFLD       8'b1_00_0_1_0_11
`define CMD_VFLW       8'b1_00_0_1_0_10
`define CMD_VFSD       8'b1_00_1_1_0_11
`define CMD_VFSW       8'b1_00_1_1_0_10

`define CMD_VLSTD      8'b1_01_0_0_0_11
`define CMD_VLSTW      8'b1_01_0_0_0_10
`define CMD_VLSTWU     8'b1_01_0_0_1_10
`define CMD_VLSTH      8'b1_01_0_0_0_01
`define CMD_VLSTHU     8'b1_01_0_0_1_01
`define CMD_VLSTB      8'b1_01_0_0_0_00
`define CMD_VLSTBU     8'b1_01_0_0_1_00
`define CMD_VSSTD      8'b1_01_1_0_0_11
`define CMD_VSSTW      8'b1_01_1_0_0_10
`define CMD_VSSTH      8'b1_01_1_0_0_01
`define CMD_VSSTB      8'b1_01_1_0_0_00

`define CMD_VFLSTD     8'b1_01_0_1_0_11
`define CMD_VFLSTW     8'b1_01_0_1_0_10
`define CMD_VFSSTD     8'b1_01_1_1_0_11
`define CMD_VFSSTW     8'b1_01_1_1_0_10

`define CMD_VLXD       8'b1_10_0_0_0_11
`define CMD_VLXW       8'b1_10_0_0_0_10
`define CMD_VLXWU      8'b1_10_0_0_1_10
`define CMD_VLXH       8'b1_10_0_0_0_01
`define CMD_VLXHU      8'b1_10_0_0_1_01
`define CMD_VLXB       8'b1_10_0_0_0_00
`define CMD_VLXBU      8'b1_10_0_0_1_00
`define CMD_VSXD       8'b1_10_1_0_0_11
`define CMD_VSXW       8'b1_10_1_0_0_10
`define CMD_VSXH       8'b1_10_1_0_0_01
`define CMD_VSXB       8'b1_10_1_0_0_00

`define CMD_VFLXD      8'b1_10_0_1_0_11
`define CMD_VFLXW      8'b1_10_0_1_0_10
`define CMD_VFSXD      8'b1_10_1_1_0_11
`define CMD_VFSXW      8'b1_10_1_1_0_10

`define CMD_VAMOADDD   8'b1_11_000_11
`define CMD_VAMOSWAPD  8'b1_11_001_11
`define CMD_VAMOANDD   8'b1_11_010_11
`define CMD_VAMOORD    8'b1_11_011_11
`define CMD_VAMOMIND   8'b1_11_100_11
`define CMD_VAMOMAXD   8'b1_11_101_11
`define CMD_VAMOMINUD  8'b1_11_110_11
`define CMD_VAMOMAXUD  8'b1_11_111_11

`define CMD_VAMOADDW   8'b1_11_000_10
`define CMD_VAMOSWAPW  8'b1_11_001_10
`define CMD_VAMOANDW   8'b1_11_010_10
`define CMD_VAMOORW    8'b1_11_011_10
`define CMD_VAMOMINW   8'b1_11_100_10
`define CMD_VAMOMAXW   8'b1_11_101_10
`define CMD_VAMOMINUW  8'b1_11_110_10
`define CMD_VAMOMAXUW  8'b1_11_111_10

`endif
