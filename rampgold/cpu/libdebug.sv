//---------------------------------------------------------------------------   
// File:        libdebug.v
// Author:      Zhangxi Tan
// Description: Data structures for onchip debuging: 
//              Initialization DMA engine
//------------------------------------------------------------------------------  

`ifndef SYNP94
package libdebug;
import libconf::*;
`endif

//typedef enum bit [1:0] {dma_NOP=2'b0, dma_ST, dma_LD, dma_FMT3} debug_dma_cmd_type;

typedef enum bit {dma_NOP=1'b0, dma_OP} debug_dma_cmd_type;

parameter DMABUFMSB = 9;

typedef struct packed {           //dma write/read, iu write
  bit [29:0]     addr;            //word aligned virtual address
  bit            parity;
}debug_dma_addr_reg_type;

typedef struct packed {           //dma write/read, iu write
  bit [DMABUFMSB:0]           buf_addr;  //support up to 1024*4 buffer 
  bit [DMABUFMSB:0]           count;     //dma counter
  debug_dma_cmd_type          cmd;       //dma control & status
  bit                         parity;
}debug_dma_ctrl_reg_type;


typedef struct packed {
  bit [29:0]                  addr;
  bit [31:0]                  data;
  bit [DMABUFMSB:0]           count;
  bit [DMABUFMSB:0]           buf_addr;
//  bit                 dma_req;    //dma running
  debug_dma_cmd_type          cmd;         //dma control & status
}debug_dma_iu_state_type;         //dma states passed with the cpu pipeline

typedef struct {
    bit [NTHREADIDMSB:0]      tid;    //thread ID
    bit                       ack;    //DMA ack (increment address counter)
    bit                       done;   //dma xact accomplished
    debug_dma_iu_state_type   state;
}debug_dma_in_type;       //debug dma input (IU->DMA), at the end of xc/com stage

typedef struct {
    bit [31:0]                inst;     //injected SPARC v8 LD/ST instructions
    debug_dma_iu_state_type   state;
}debug_dma_out_type;      //debug dma output at ifetch (DMA->IU)


`ifdef SYNP94
const debug_dma_iu_state_type debug_dma_iu_state_none = {30'b0, 32'b0, '0, '0, 2'b0};
//const debug_dma_cmd_type debug_dma_iu_state_none = {30'b0, 32'b0, 10'b0, 10'b0, dma_NOP};
//const debug_dma_cmd_type debug_dma_iu_state_none = '{default:0, dma_iu_state_none:dma_NOP};
`else
const debug_dma_iu_state_type debug_dma_iu_state_none = '{default:0, debug_dma_cmd_type:dma_NOP};
//const debug_dma_iu_state_type debug_dma_iu_state_none = '{0,0,0,0,dma_NOP};
`endif

typedef struct {
	bit [DMABUFMSB:0] addr;
	//no use when read
	bit				          we;
	bit [31:0]        inst;   //injected instruction
	bit [31:0]        data;   //read buffer data
}debug_dma_read_buffer_in_type;

typedef struct {
  bit [31:0]            inst;   //injected instruction
  bit [31:0]            data;   //read buffer data
}debug_dma_read_buffer_out_type;

typedef struct {
  bit [DMABUFMSB:0]     addr;
  bit                   we;
  bit [31:0]            data;
  bit					parity;		//parity of data
}debug_dma_write_buffer_in_type;

typedef struct { 
  bit [31:0]  data;
  bit         parity;             //in case we only want to use parity to protect the TX path
}debug_dma_write_buffer_out_type;

typedef struct {
  bit [NTHREADIDMSB:0]    tid;
  debug_dma_addr_reg_type addr_reg;        //target virtual address
  bit                     addr_we;

  debug_dma_ctrl_reg_type ctrl_reg;         //control register
  bit                     ctrl_we;
}debug_dma_cmdif_in_type;


`ifndef SYNP94
endpackage
`endif