//------------------------------------------------------------------------------ 
// File:        libtm.sv
// Author:      Zhangxi Tan
// Description: Data structures for CPU pipeline timing model
//              Timing model will control the pipeline by toggling the 'replay' 
//              signal and invalid signals (adder, misc, mul) at the 'regacc' stage
//------------------------------------------------------------------------------  


`timescale 1ns / 1ps


`ifndef SYNP94
package libtm;
import libconf::*;
import libdebug::*;
`endif

typedef enum bit [1:0] {tm_START, tm_STOP, tm_NOP} tm_unit_ctrl_type;      //Unit start/stop control

typedef enum bit [2:0] {tm_dbg_nop, tm_dbg_start, tm_dbg_stop, tm_dbg_select_start, tm_dbg_select_stop}  tm_dbg_ctrl_type;      //timing model control type

typedef struct {
  bit [NTHREADIDMSB:0]  threads_active;
  bit [NTHREADIDMSB:0]  threads_total;
  tm_dbg_ctrl_type      tm_dbg_ctrl;
} dma_tm_ctrl_type;

// FM -> TM
typedef struct {
  bit [NTHREADIDMSB:0]  tid;        //thread ID
  bit                   valid;      //timing token between FM and TM.
  bit                   run;        //run bit.  run & ~replay <=> insn retired
  bit                   replay;     //this instruction needs to replay
  bit                   retired;    //retiring an instruction
  bit [31:0]            inst;       //the instruction that was retired
  bit [31:0]            paddr;      //load/store physical address (only valid if ldst)
  bit [31:0]            npc;        //PC of next fetched insn
}tm_cpu_ctrl_token_type;

// TM -> FM
typedef struct {
  bit                   valid;      //timing token between FM and TM.
  bit                   run;        //run bit
  bit [NTHREADIDMSB:0]  tid;        //thread ID
  bit                   running;    //TM is running
}tm2cpu_token_type;

`ifndef SYNP94
endpackage
`endif




