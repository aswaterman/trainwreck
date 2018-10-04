//-------------------------------------------------------------------------------------------  
// File:        disasm.sv
// Author:      Zhangxi Tan
// Description: SPARC disassembler implemented using DPI
//-------------------------------------------------------------------------------------------   

//synthesis translate_off

`timescale 1ns / 1ps

import libiu::*;

typedef struct {
  int pid;            //pipeline ID
  longint ctime;
  int tid;
  int inst;
  int pc;
  int replay;
  int annul;
  int dma_mode;
  int uc_mode;
  int upc;
}disasm_info_type;

import "DPI-C" context function void sparc_disasm(input disasm_info_type dis);
import "DPI-C" context function void init_disasm();

module disassembler #(parameter int PID=0) (input iu_clk_type gclk, input bit rst, input xc_reg_type xcr, input bit dcache_replay);  
  disasm_info_type  dis;

  initial begin
    init_disasm();
  end
  
  always @(posedge gclk.clk) begin    
    if (rst == 0 && (xcr.ts.run == 1 | xcr.ts.dma_mode == 1) && xcr.ts.icmiss == 0) begin
//      if(xcr.ts.ucmode == 0) begin
        dis.pid      = PID;
        dis.tid      = int'(xcr.ts.tid);
        dis.inst     = int'(xcr.ts.inst);
        dis.pc       = int'(xcr.ts.pc);
        dis.replay   = int'(xcr.ts.replay | dcache_replay);
        dis.annul    = int'(xcr.ts.annul);
        dis.ctime    = longint'($time);
        dis.dma_mode = int'(xcr.ts.dma_mode);
        dis.uc_mode  = int'(xcr.ts.ucmode);
        dis.upc      = int'(xcr.ts.upc);
        //disassembler is done by DPI function
        sparc_disasm(dis);
//      end
//      else begin
//        $display("@%t Thread %d in microcode mode: upc =%d, dma_mode = %d", $time, xcr.ts.tid, xcr.ts.upc, xcr.ts.dma_mode);
//      end
    end
  end

endmodule

//synthesis translate_on