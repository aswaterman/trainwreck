//---------------------------------------------------------------------------   
// File:        libmmu.sv
// Author:      Zhangxi Tan
// Description: Data structures for MMU. Might use different page size for I/D TLB
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;

package libmmu;

import libiu::*;
import libstd::*;
import libconf::*;
import libopcodes::*;
`endif


parameter int PAGESIZE = 4096;				//4k page size 
parameter int NITLBASSOC = 2;     //itlb associativity
parameter int NDTLBASSOC = 2;     //dtlb associativity
parameter int NITLBENTRY = 8;				//8 entry ITLB
parameter int NDTLBENTRY = 8;				//8 entry DTLB
parameter int ITLBINDEXMSB = log2x(NITLBENTRY)+log2x(PAGESIZE)-1;	//ITLB index MSB
parameter int DTLBINDEXMSB = log2x(NDTLBENTRY)+log2x(PAGESIZE)-1;	//DTLB index MSB
parameter int ITLBINDEXLSB = log2x(PAGESIZE);
parameter int DTLBINDEXLSB = log2x(PAGESIZE);
parameter int ITLBTAGLSB = log2x(PAGESIZE)+log2x(NITLBENTRY);	//LSB of address tag in pc  
parameter int DTLBTAGLSB = log2x(PAGESIZE)+log2x(NDTLBENTRY);	//LSB of address tag in pc  

parameter int MMUCTXMSB = log2x(MMUCTXNUM)-1;		//ctx # msb

parameter int ITLBLARGETAGLSB = 18 + log2x(NITLBENTRY);
parameter int DTLBLARGETAGLSB = 18 + log2x(NDTLBENTRY);

const bit [ITLBINDEXMSB:ITLBINDEXLSB] LASTITLBINDEX = '1;
const bit [DTLBINDEXMSB:DTLBINDEXLSB] LASTDTLBINDEX = '1;
//----------------------------------MMU registers data structures------------------------------------------------
typedef struct packed {
  bit         parity;     //parity
  bit [31:28] impl;       //implementatino bits (ro)
  bit [27:24] ver;        //version bits (ro)
  bit [23:8]  sc;         //RAMP implementation defined (rw)
  bit         pso;        //pso/tso bit (ro?)
  bit [6:2]   reserved;   //reserved (all 0)
  bit         nf;         //no fault bit
  bit         e;          //mmu enable bit
}mmu_control_register_type;       //control register

typedef struct packed {
  bit   parity;
  bit   nf;
  bit   e;
}mmu_control_register_ram_type;   //control register storage

typedef struct packed {
  bit                parity;
  bit [MMUCTXMSB:0]  ctx;         //current context number
}mmu_context_register_type;

typedef mmu_context_register_type mmu_context_register_ram_type;

typedef struct packed {
  bit         parity;     
  bit [31:18] reserved;   //all 0
  bit [17:10] ebe;        //Extended bus error (0 for RAMP)
  bit [9:8]   l;          //level
  bit [7:5]   at;         //access type
  bit [4:2]   ft;         //fault type
  bit         fav;        //fault address register valid
  bit         ow;         //overflow (0 for RAMP)
}mmu_fault_status_register_type;

typedef struct packed {
  bit         parity;     
  bit [9:8]   l;          //level
  bit [7:5]   at;         //access type
  bit [4:2]   ft;         //fault type
  bit         fav;        //fault address register valid
}mmu_fault_status_register_ram_type;

//access type constants
const bit [2:0] MMU_AT_LOAD_FROM_USER_DATA      = 3'h0;
const bit [2:0] MMU_AT_LOAD_FROM_KERNEL_DATA    = 3'h1;
const bit [2:0] MMU_AT_LOADEXE_FROM_USER_INST   = 3'h2;
const bit [2:0] MMU_AT_LOADEXE_FROM_KERNEL_INST = 3'h3;
const bit [2:0] MMU_AT_STORE_TO_USER_DATA       = 3'h4;
const bit [2:0] MMU_AT_STORE_TO_KERNEL_DATA     = 3'h5;
const bit [2:0] MMU_AT_STORE_TO_USER_INST       = 3'h6;
const bit [2:0] MMU_AT_STORE_TO_KERNEL_INST     = 3'h7;

//fault type constants
const bit [2:0] MMU_FT_NONE            = 3'h0;
const bit [2:0] MMU_FT_INVALID_ADDR    = 3'h1;
const bit [2:0] MMU_FT_PROTECTION_ERR  = 3'h2;
const bit [2:0] MMU_FT_PRIVILEGE_ERR   = 3'h3;
const bit [2:0] MMU_FT_TRANSLATION_ERR = 3'h4;      
const bit [2:0] MMU_FT_BUS_ERR         = 3'h5;      //never used in RAMP
const bit [2:0] MMU_FT_INTERNAl_ERR    = 3'h6;      //never used in RAMP

typedef struct packed {
  bit         parity;
  bit [31:0]  addr;
}mmu_fault_address_register_type;

typedef mmu_fault_address_register_type mmu_fault_address_register_ram_type;

typedef struct packed {
  bit         parity;
  bit [27:2]  pt;
}mmu_context_table_ptr_register_ram_type;

/*
typedef struct {
  bit [NTHREADMSB:0]  tid;
  bit [MMUCTXMSB:0]   ctx;
  bit [31:2]          pt;
  bit                 we;
}mmu_context_table_ptr_write_in_type;
*/

typedef enum bit [3:0] {mmureg_nop, mmureg_ctx_ptr, mmureg_ctx, mmureg_ctr, mmureg_fs, mmureg_faddr, mmureg_iflush_all, mmureg_iflush_l0, mmureg_iflush_l1, mmureg_iflush_l2, mmureg_iflush_l3} mmureg_op_type;

typedef struct {
  bit [NTHREADIDMSB:0]  tid;
//  bit [MMUCTXMSB:0]   ctx;
//  bit                 itlb_flush;   //is itlb flush
  bit [31:0]          data;
  mmureg_op_type      op;
}mmureg_write_in_type;

//----------------------------------Old TLB data structures----------------------------------------------------------
typedef struct packed {
`ifdef SYNP94
	struct packed{
`else
	union packed{
`endif
		bit [31:ITLBTAGLSB]	I;
		bit [31:DTLBTAGLSB]	D;
	}vpn;					//virtual page number
		
	bit [MMUCTXMSB:0]	ctx;		   //context ID	
	bit			            valid;		 //entry is valid
	bit [1:0]		       level;		 //current level
	bit			            dirty;		 //entry is modified (referenced/modified bit is touched)	
	//mapped to DIP on BRAM
	bit			            parity;		//parity bit
}mmu_tlb_tag_type; 

typedef struct packed {
`ifdef SYNP94
	struct packed{
`else
	union packed{
`endif
		bit [31:ITLBTAGLSB]	I;
		bit [31:DTLBTAGLSB]	D;
	}ppn;					//physical page number
	bit			c;		//cacheable
	
	bit [2:0]		acc;		//access permissions
	bit [1:0]		et;		//entry type
	//mapped to DIP on BRAM
	bit			m;		//modified, no use in ITLB
	bit			r;		//referenced	
	bit			parity;		//parity bit
}mmu_tlb_data_type;


typedef struct packed{
	bit			tag_parity;	//tlb tag parity
	bit			data_parity;	//tlb data parity
}tlb_error_type;

//----------------------------------Old TLB interface----------------------------------------------------------

typedef struct {
	mmu_tlb_tag_type			tag;		//tlb tag
	mmu_tlb_data_type			data;		//tlb data
}tlb_out_type; 			//tlb output to IU

typedef struct {
	bit [NTHREADIDMSB:0]			tid;		//thread id
`ifdef SYNP94
	struct packed{
`else
	union packed{
`endif	
		bit [ITLBINDEXMSB:ITLBINDEXLSB]	I;
		bit [DTLBINDEXMSB:DTLBINDEXLSB]	D;
	}index;			//direct map	
}tlb_read_in_type;		//read from IU/mem

typedef struct {
	bit [NTHREADIDMSB:0]			tid;		//thread id
`ifdef SYNP94
	struct packed{
`else
	union packed{
`endif	
		bit [ITLBINDEXMSB:ITLBINDEXLSB]	I;
		bit [DTLBINDEXMSB:DTLBINDEXLSB]	D;
	}index;							//direct map		
	mmu_tlb_tag_type			tag;
	mmu_tlb_data_type			data;
	bit					we;		//write enable. only modify tag, m/r/parity in data
}tlb_write_in_type;		//write from IU/mem

typedef struct {
	tlb_read_in_type			read;
	tlb_write_in_type			write;		//input during itlb write 
}tlb_in_type;			//interface to tlb BRAM



//----------------------------------New TLB data structures-----------------------------------------------

typedef struct packed {
  bit [31:8] ppn;             //physical page number
  bit        c;               //cacheable
  bit        m;               //modified
  bit        r;               //referenced
  bit [4:2]  acc;             //access permissions
  bit [1:0]  et;              //entry type
}mmu_page_table_entry_type;


typedef struct packed {
  bit [31:ITLBTAGLSB] vpn_tag;
  bit [MMUCTXMSB:0]	  ctx;		 //ctx ID
  bit                 valid;
  bit [1:0]           lvl;
//  bit                 lru;
}mmu_itlb_tag_type;          //itlb tag

typedef struct packed {
  bit [31:DTLBTAGLSB] vpn_tag;
  bit [MMUCTXMSB:0]	  ctx;		 //ctx ID
  bit                 valid;
  bit				             dirty;
  bit [1:0]           lvl;
//  bit                 lru;   //lru bit
}mmu_dtlb_tag_type;          //dtlb tag


//---------------------------New IU <-> TLB interface----------------------------------------------------------
typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  bit [31:ITLBTAGLSB]             vpn_tag;  
  bit [ITLBINDEXMSB:ITLBINDEXLSB]	index, index1;
//  bit                             replay;
//  bit                             su;
  bit                             valid;    
}mmu_iu_itlb_type;        //iu -> itlb

typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  bit [31:DTLBTAGLSB]             vpn_tag;  
  bit [DTLBINDEXMSB:DTLBINDEXLSB]	index, index1;
  bit [MMUCTXMSB:0]               ctx;
//  bit                             replay;
//  bit                             su;
//  bit                             m;              //touch modified bit 
//  bit                             valid;
}mmu_iu_dtlb_type;        //iu -> dtlb


typedef struct {
  mmu_page_table_entry_type     pte;
  bit [1:0]                     lvl;  
  bit                           valid;
}mmu_itlb_iu_type;        //itlb -> iu

//typedef mmu_itlb_iu_type mmu_dtlb_iu_type;  //dtlb -> iu
typedef struct {
  mmu_page_table_entry_type     pte;
  bit [1:0]                     lvl;  
  bit                           valid;
  bit                           wb;       //write back may required  
}mmu_dtlb_iu_type;  //dtlb -> iu

//typedef enum bit [1:0] = {tlb_stat_pending, tlb_stat_busy, tlb_stat_ready} tlb_status_type;


//---------------------------TLB RAM interface----------------------------------------------------------
typedef struct packed {
  mmu_itlb_tag_type            tag;
  mmu_page_table_entry_type    data;
}mmu_itlbram_data_type;

typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  bit [ITLBINDEXMSB:ITLBINDEXLSB] index;
}mmu_itlbram_addr_type;

typedef struct packed {
  mmu_dtlb_tag_type            tag;
  mmu_page_table_entry_type    data;
}mmu_dtlbram_data_type;

typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  bit [DTLBINDEXMSB:DTLBINDEXLSB] index;
}mmu_dtlbram_addr_type;


//data structure used for ram

typedef enum bit [2:0] {flush_probe_l3, flush_probe_l2, flush_probe_l1, flush_probe_l0, flush_probe_all, flush_probe_none} tlb_flush_probe_op_type; 

typedef struct packed{
    tlb_flush_probe_op_type   op;
    bit [MMUCTXMSB:0]	  ctx;
    bit [31:12]         va;
}mmu_tlb_flush_probe_type;

//----------------------------------mmu walk data structures ---------------------------------------------------
typedef enum bit [1:0] {tlbmem_nop, tlbmem_read_miss, tlbmem_write_miss, tlbmem_noupdate} tlb_mmu_op_type;

typedef struct packed {
//  bit                   isI;      //is instruction tlb miss?
//  tlb_mmu_op_type       op;
//  bit [NTHREADIDMSB:0]  tid;
  bit                   walking;
  bit [31:2]            addr; 
  bit [1:0]             cnt;      //for large
  bit                   parity;               
}mmu_walk_request_data_type;

//----------------------------------tlb <-> mmumem interface----------------------------------------------------------
typedef enum bit [3:0] {tlb_nop, tlb_refill, tlb_flush_all, tlb_flush_l0, tlb_flush_l1, tlb_flush_l2, tlb_flush_l3, update_ctx_reg, update_ctrl_reg} mmu_tlb_op_type;


typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  mmu_page_table_entry_type       pte;  
//  bit                             large_page;      //large page
  bit [1:0]                       lvl;
//  bit [ITLBINDEXMSB:ITLBINDEXLSB]	index;
  mmu_tlb_op_type                 op;  
  //new mmu register values
  //mmu_control_register_ram_type   ctrl_reg;
  //mmu_context_register_ram_type   ctx_reg;  
  bit [31:0]                      mmureg;           //mmu register values 
}mmu_mmumem_itlb_type;

/*
typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  bit [31:ITLBTAGINDEXLSB]        vpn;
  bit [MMUCTXMSB:0]               ctx;
  tlb_mmu_op_type                 op;
}mmu_itlb_mmumem_type;
*/

typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  bit [MMUCTXMSB:0]               ctx;
}mmu_itlb_mmumem_type;

/*
typedef struct {
  bit [NTHREADIDMSB:0]            tid;
  mmu_page_table_entry_type       pte;  
  bit                             large_page;
//  bit [DTLBINDEXMSB:DTLBINDEXLSB]	index;
  mmu_tlb_op_type                 op;
  //new mmu register values
  //mmu_control_register_ram_type   ctrl_reg;
  //mmu_context_register_ram_type   ctx_reg;  
  bit [31:0]                      mmureg;           //mmu register values 
}mmu_mmumem_dtlb_type;
*/

typedef struct {
    bit [NTHREADIDMSB:0]            tid;
    bit                             write;
    bit [31:2]                      addr;
//    bit                             isI;
//    bit                             tlbmiss;
}mmu_dtlb_mmumem_type;

typedef mmu_mmumem_itlb_type mmu_mmumem_dtlb_type;


//----------------------------------mmu walk <-> Host $ interface---------------------------------------------------
typedef struct {
  bit [NTHREADIDMSB:0] tid;
  tlb_mmu_op_type      walk_state;
//  bit [1:0]            cnt;       //used for probe
  bit [31:2]           addr;
}mmu_host_cache_in_type;

typedef struct {
//  bit                   inack;    //in ack
  bit [NTHREADIDMSB:0]  tid;
  bit                   isI;
  tlb_mmu_op_type       walk_state;
  bit [31:0]            data;     //pte/ptd
//  bit [1:0]             cnt;      //walk count
  bit                   valid;
}mmu_host_cache_out_type;

//----------------------------------I-MMU <-> IU interface----------------------------------------------------------
//now keep the MMU interface simple
typedef struct {
	bit [NTHREADIDMSB:0]			tid;			//request threadid
	bit [31:2]				vpc;			      //virtual PC, used as index
	bit					    vpc_parity;		//parity for virtual pc, used for incremental parity calculation
	bit					    valid;			    //lookup valid
	bit					    su;			       //requestor mode: u/s
	bit					    replay;			   //replay mode
	//decode stage input (a little strange naming)
  bit                   iflush;      //flush i$?
  bit [FLUSHIDXMSB:0]   flushidx;    //flush index
}immu_iu_in_type;		//IF stage interface (->immu)

typedef struct { 
  immu_data_type         data;     //immu data status
	bit					             parity_error;		//parity error is detected
}immu_iu_out_type;		//replay request is handled by cache (->iu)

//----------------------------------D-MMU <-> IU interface----------------------------------------------------------
typedef struct {
  struct {
     	mmu_iu_dtlb_type      iu2dtlb;	
//    mmu_itlb_mmumem_type  fromitlb,   
  }ex1;
  
  struct {
    bit [NTHREADIDMSB:0]   tid;
    bit                    ldst_a;      //ASI load/store/		
    immu_data_type			      immu_data;
    	bit [31:0]			         va;
	   bit [31:0]            mmureg_data;
		asi_type               asi;
		bit				               ldst;	 	     //0 - load / 1 - store
		bit					             valid;	      //lookup valid
		bit					             su;			       //requestor mode: u/s    
		bit                    ucmode;      //only write to mmureg during ucmode 
	//	mmu_tlb_flush_type     dtlb_flush;
  }m1;
}dmmu_if_iu_in_type;

//----------------------------------Old D-MMU <-> IU interface----------------------------------------------------------
typedef struct {
	struct {
		bit [NTHREADIDMSB:0]			tid;			  //request threadid
    bit [31:0]				         va;			   //virtual address, used as index
    asi_type               asi;   
    bit                    ldst_a;  //ASI load/store/
	}m1;
	
	struct {	
		bit [NTHREADIDMSB:0]			tid;			      //request threadid
		bit [31:0]				         va;			       //virtual address, used as index		
    bit                    ldst_a;      //ASI load/store/		
		asi_type               asi;   
		bit					             valid;	      //lookup valid
		bit					             su;			       //requestor mode: u/s
		bit					             replay;      //replay mode	
		LDST_CTRL_TYPE				     ldst;	 	     //load/store indication, used for exception detection (e.g. non-write page)
		bit                    dma_mode;   //flush in dma mode (flush $ blocks based on idx not virtual address), i.e. bypass mmu
	}m2;
}dmmu_iu_in_type;		//input from IU

typedef struct { 
	bit					    exception;		   //DAEX, TLB access valid, generated in mem (2nd cycle)	
	bit           store_nop;
	bit [31:0]				paddr;
	bit [31:0]    mmureg_read;        
	bit           mmureg_valid;  
	bit						  replay;
	bit					    parity_error;		//parity error is detected
}dmmu_iu_out_type;		//replay request is handled by cache (->iu)

//mmu fault detection function

function automatic bit [2:0] detect_mmu_fault(bit [2:0] at, mmu_page_table_entry_type pte);
  bit [2:0] ret;

  //default values  
  ret = MMU_FT_NONE;

  unique case(at)
  3'd0: unique case (pte.acc)
        3'd4: ret = MMU_FT_PROTECTION_ERR;
        3'd6,3'd7: ret = MMU_FT_PRIVILEGE_ERR;
        default:;
        endcase
  3'd1: if (pte.acc == 3'd4)
          ret = MMU_FT_PROTECTION_ERR;
  3'd2: unique case (pte.acc)
        3'd0, 3'd1, 3'd5: ret = MMU_FT_PROTECTION_ERR;
        3'd6, 3'd7: ret = MMU_FT_PRIVILEGE_ERR;
        default:;
        endcase
  3'd3: unique case (pte.acc)
        3'd0, 3'd1, 3'd5: ret = MMU_FT_PROTECTION_ERR;
        default:;
        endcase
  3'd4: unique case (pte.acc)
        3'd0, 3'd2, 3'd4, 3'd5: ret = MMU_FT_PROTECTION_ERR;
        3'd6, 3'd7: ret = MMU_FT_PRIVILEGE_ERR;
        default:;
        endcase
  3'd5: unique case (pte.acc)
        3'd0, 3'd2, 3'd4, 3'd6: ret = MMU_FT_PROTECTION_ERR;
        default:;
        endcase
  3'd6: unique case (pte.acc)
        3'd0, 3'd1, 3'd2, 3'd4, 3'd5: ret = MMU_FT_PROTECTION_ERR;
        3'd6, 3'd7: ret = MMU_FT_PRIVILEGE_ERR;
        default:;
        endcase
  3'd7: if (pte.acc != 3'd3 && pte.acc != 3'd7) 
          ret = MMU_FT_PROTECTION_ERR;
  endcase
  
  unique case (pte.et)
  0:    ret = MMU_FT_INVALID_ADDR;
  1, 3: ret = MMU_FT_TRANSLATION_ERR;
  default :;
  endcase
  
  return ret;  
endfunction


//flush 

function automatic bit tlb_flush_match(mmu_tlb_flush_probe_type flush, mmu_page_table_entry_type pte, bit [MMUCTXMSB:0] tlb_ctx, bit [31:12] tlb_va, bit large_page);
  bit   matched;

  bit   ctx_equal;
  bit   l3_va_equal, l2_va_equal, l1_va_equal;
  bit   accge6;
  
  matched = '0;
  
  //comparators
  ctx_equal   = (flush.ctx == tlb_ctx) ? '1 : '0;
  accge6      = (pte.acc >= 6) ? '1 : '0;
  l1_va_equal = (tlb_va[31:24] == flush.va[31:24]) ? '1 : '0;
  l2_va_equal = (tlb_va[23:18] == flush.va[23:18]) ? l1_va_equal : '0;
  l3_va_equal = (tlb_va[17:12] == flush.va[17:12]) ? l2_va_equal : '0;
  
  
  /*
  unique case(flush.op)
  flush_probe_all: matched = '1;
  flush_probe_l3: matched = (((accge6 | ctx_equal) & (pte.et == 2)) | (ctx_equal & (pte.et == 1))) & l3_va_equal & ~large_page;   
  flush_probe_l2: matched = (((accge6 | ctx_equal) & (pte.et == 2)) | (ctx_equal & (pte.et == 1))) & l2_va_equal;
  flush_probe_l1: matched = (((accge6 | ctx_equal) & (pte.et == 2)) | (ctx_equal & (pte.et == 1))) & l1_va_equal;
  flush_probe_l0: matched = ((~accge6 & (pte.et == 2)) | (pte.et == 1)) & ctx_equal;
  default : ;
  endcase
  */
  unique case(flush.op)
  flush_probe_all: matched = '1;
  flush_probe_l3: matched = (accge6 | ctx_equal) & l3_va_equal & ~large_page;   
  flush_probe_l2: matched = (accge6 | ctx_equal) & l2_va_equal;
  flush_probe_l1: matched = (accge6 | ctx_equal)& l1_va_equal;
  flush_probe_l0: matched = ~accge6 & ctx_equal;
  default : ;
  endcase

  return matched;
endfunction

function automatic bit [31:8] get_new_ppn(mmu_page_table_entry_type pte, bit [1:0] level, bit [31:12] vaddr);
  bit [31:8] ppn;
  
  ppn = pte.ppn;

  unique case (level)
  0: ppn |= unsigned'(vaddr);
  1: ppn |= unsigned'(vaddr[23:12]);
  2: ppn |= unsigned'(vaddr[17:12]);
  default: ;
  endcase
  
  return ppn;
endfunction

`ifndef SYNP94
endpackage
`endif 
