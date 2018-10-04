//------------------------------------------------------------------------------   
// File:        libconf.v
// Author:      Zhangxi Tan
// Description: The global configuration header file. Define global constants
//------------------------------------------------------------------------------  


//`define XILINX
//`define VIRTEX5 

`ifndef SYNP94
package libconf;

import libstd::*;
`endif

parameter int NTHREAD = 64;
parameter int NWIN = 7;					//number of regsier windows
parameter int NTHREADIDMSB = log2x(NTHREAD) - 1;
parameter int NWINMSB = log2x(NWIN)-1;			//cwp bit
parameter int NREGADDRMSB = log2x(NTHREAD*16*(NWIN+1)) - 1;	//asssume 16 regs per window per thread 
parameter int NFPREGADDRMSB = log2x(NTHREAD*32) - 1;        //FP reg file has 32 entries
const     bit [NREGADDRMSB-NTHREADIDMSB-4:0] REGADDRPAD0 = 1;
const     bit [NREGADDRMSB-NTHREADIDMSB-6:0] REGADDRPAD1 = 0;

parameter int NOTAG = 0;	  //support tag add/sub
const     bit CPEN = 1'b0;	//enable co-processor
`ifndef SYNP94
parameter bit FPEN = 1;	   //enable FPU
`else
const     bit FPEN = 1'b1;
`endif
parameter int MULEN = 1;	  //enable multipler
parameter int DIVEN = 1;	  //enable divider
parameter int ASREN = 1;	  //enable ASR support
parameter int ASR15EN = 1; //enable ASR15 support for TID
parameter int MMUEN = 1;	  //enable MMU

parameter int MMUCTXNUM = 8;             //max mmu context count

parameter int TRAP_PSR_EN = 1;		 //PSR illegal cwp trap (assume OSes are well written)
parameter int TRAP_IINST_EN = 1;	//Illegal instruction exception enable

parameter int V8_ERROR_MODE = 1; //v8 compatibale error mode, update tt field of TBR

parameter int CWPMIN = 0;	//min register window pointer
parameter int CWPMAX = NWIN - 1;	//max register window pointer, 2 register windows by default	

`ifndef DIAB					//this ifdef will be removed once synplify gets better
parameter int NMEMCTRLPORT = 1;	//number of ports on memory controller
`else
parameter int NMEMCTRLPORT = 4; //DIAB settings here
`endif
//mapping parameters
parameter int SPRBRAM = 0;	//handle PC/nPC/thread state with BRAM, by default implemented with LUTram

//constant value for PSR
const bit [31:28] PSR_IMPL = 4'd0;
const bit [27:24] PSR_VER = 4'd0;		//undefined now

//memory network credit count
parameter int MAXMEMCREDIT     =  64; 
parameter int MAXMEMCREDITMSB  =  log2x(MAXMEMCREDIT);

//constant for error detection
parameter int BRAMPROT = 1;	  //0 - no ECC,  1 - software parity, 2 - hard ECC. Only ECC can protect BRAM from SEU
parameter int LUTRAMPROT = 0;	//0 - no parity, 1 - software parity for distributed ram

//constant for clk, currently set to (3*100)/12 = 25 MHz
parameter CLKMUL = 3.0;
parameter CLKDIV = 12.0;
parameter CLKIN_PERIOD = 10.0;     //external input clock for cpu, dram and etc.

parameter DRAM_PERIOD    = 10.0;      //DDR2 PLL input clock period
parameter DRAM_CLKMUL    = 9.0;
parameter DRAM_CLKDIV200 = 3.0;
parameter DRAM_CLKDIV    = 4.0;
parameter DRAM_PLLDIV    = 1.0;

parameter BOARDSEL = 1;           //ML505 = 1, BEE3 = 0

// max pipelines per chip
//parameter int MAXPIPE = 8;
//parameter int MAXPIPEMSB = log2x(MAXPIPE) - 1;

//debugging option
parameter ADVDEBUGDMA = 0;        //advanced debug DMA support, support read/write register content
`ifndef SYNP94
endpackage
`endif