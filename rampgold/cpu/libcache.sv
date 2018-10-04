//---------------------------------------------------------------------------   
// File:        libcache_udc.v
// Author:      Zhangxi Tan
// Description: Data structures for directmap I$, D. 
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps

`ifndef SYNP94
package libcache;

import libmmu::*;
import libstd::*;
import libiu::*;
import libconf::*;
import libopcodes::*;
`endif

parameter int ICACHELINESIZE_MEM = 32;							//32-byte I$ line size/memory
parameter int ICACHELINESIZE_IU = ICACHELINESIZE_MEM /2;					//16-byte line size/IU 

parameter int DCACHELINESIZE_MEM = 32;							//32-byte D$ line size/memory
parameter int DCACHELINESIZE_IU = DCACHELINESIZE_MEM /2;					//16-byte line size/IU 

parameter int NICACHEBLOCK_MEM = 8;							//8 blocks each thread
parameter int NDCACHEBLOCK_MEM = 8;							//8 blocks each 

//icache size in 36kb blocks, constant
parameter int ICSIZE = ICACHELINESIZE_MEM/8;
parameter int DCSIZE = DCACHELINESIZE_MEM/8; 

parameter int DRAMADDRPAD = log2x(DCACHELINESIZE_MEM/8);
/*
+---------------------------------------+
|31                    8|7      5|4    0|
+---------------------------------------+
|         tag           |  index |offset|
+-----------------------+--------+------+
*/

parameter int ICACHEINDEXLSB_MEM = log2x(ICACHELINESIZE_MEM);				                       //I$ index LSB
parameter int ICACHEINDEXMSB_MEM = log2x(ICACHELINESIZE_MEM)+log2x(NICACHEBLOCK_MEM)-1;	//I$ index MSB
parameter int ICACHEINDEXLSB_IU  = log2x(ICACHELINESIZE_IU);				                        //I$ index LSB
parameter int ICACHEINDEXMSB_IU  = ICACHEINDEXMSB_MEM;					                             //I$ index MSB
parameter int ICACHETAGLSB       = log2x(ICACHELINESIZE_MEM)+log2x(NICACHEBLOCK_MEM);		 //I$ tag LSB
parameter int ICACHELINEMSB_IU   = ICACHELINESIZE_IU*8-1; 					                         //half cache line MSB 
parameter int ICACHELINEMSB_MEM  = ICACHELINESIZE_MEM*8-1;

parameter int DCACHEINDEXLSB_MEM = log2x(DCACHELINESIZE_MEM);				                       //D$ index LSB
parameter int DCACHEINDEXMSB_MEM = log2x(DCACHELINESIZE_MEM)+log2x(NDCACHEBLOCK_MEM)-1;	//D$ index MSB
parameter int DCACHEINDEXLSB_IU  = log2x(DCACHELINESIZE_IU);	                         		//D$ index LSB
parameter int DCACHEINDEXMSB_IU  = DCACHEINDEXMSB_MEM;					                             //D$ index MSB
parameter int DCACHETAGLSB       = log2x(DCACHELINESIZE_MEM)+log2x(NDCACHEBLOCK_MEM);		 //D$ tag LSB
parameter int DCACHELINEMSB_IU   = DCACHELINESIZE_IU*8-1; 					                         //half cache line MSB 
parameter int DCACHELINEMSB_MEM  = DCACHELINESIZE_MEM*8-1;

typedef enum bit [1:0] {ICACHE_LD = 2'b00, IMMU_WALK = 2'b10, ITLB_WRITE = 2'b11} imem_op_type;		//bit[1] = cache/mmu, bit[0] =r/w
//ICACHE_LD: refile cache line from memory
//IMMU_WALK: perform MMU walk
//ITLB_WRITE: commit dirty TLB to page tabe (in memory)

typedef enum bit [1:0] {DCACHE_LD = 2'b00, DCACHE_WB = 2'b01, DMMU_WALK = 2'b10, DTLB_WRITE = 2'b11} dmem_op_type;
//------------------------------------------basic cache data structure----------------------------------
typedef struct packed{	
`ifdef SYNP94
	struct packed{
`else
	union packed {
`endif
		bit [31:ICACHETAGLSB]	I;
		bit [31:DCACHETAGLSB]	D;
	}tag;			//cache tag
	bit				valid;			//cache valid bit
	bit				dirty;			//dirty bit
	bit				parity;			//parity
}cache_tag_type;		//cache tag

`ifndef SYNP94
const cache_tag_type cache_tag_none = {'0, '0, '0, '0};
`else
const cache_tag_type cache_tag_none = {{24'd0, 24'd0}, 1'b0, 1'b0, 1'b0};
`endif

typedef struct {
	bit				sberr;			//signle-bit error
	bit				dberr;			//double-bit error
}cache_data_error_type;		//cache ecc

`ifndef SYNP94
const cache_data_error_type cache_data_error_none = '{0, 0};
`else
const cache_data_error_type cache_data_error_none = {1'b0, 1'b0};
`endif

typedef struct {
`ifdef SYNP94
	struct packed{
`else
	union packed{
`endif	
		bit [ICACHELINEMSB_IU:0]	I;
		bit [DCACHELINEMSB_IU:0]	D;	
	}data;			//cache data (half block)

`ifdef SYNP94
	struct packed{
`else
	union packed{
`endif
		bit [ICACHELINESIZE_IU-1:0]	I;
		bit [DCACHELINESIZE_IU-1:0]	D;	
	}ecc_parity;		//ecc parity bit for storing in dram
 	
	cache_data_error_type		ecc_error;		//ecc error	
}cache_data_type;		//cache data

typedef struct {
`ifdef SYNP94
  struct packed{
`else
  union packed{
`endif	
    bit [ICACHELINEMSB_MEM:0]	I;
    bit [DCACHELINEMSB_MEM:0]	D;	
  }data;			//whole cache line data 

`ifdef SYNP94
  struct packed{
`else
  union packed{
`endif
    bit [ICACHELINESIZE_MEM-1:0]	I;
    bit [DCACHELINESIZE_MEM-1:0]	D;	
  }ecc_parity;		//ecc parity bit for storing in dram
   
  cache_data_error_type		ecc_error;		//ecc error	
}cache_data_wide_type;		//cache data

`ifdef SYNP94
const cache_data_type      cache_data_none = {{128'd0, 128'd0}, {16'd0,16'd0}, cache_data_error_none};
const cache_data_wide_type cache_data_wide_none = {{256'd0, 256'd0}, {32'd0,32'd0}, cache_data_error_none};
`else
const cache_data_type      cache_data_none = '{0, 0, cache_data_error_none};
const cache_data_wide_type cache_data_wide_none = '{0, 0, cache_data_error_none};
`endif

typedef struct {
	cache_data_error_type		data_ecc_err;	//data ecc error
	bit				               tag_parity;	//tag parity
}cache_error_type;		//cache BRAM error, to monitor circuit			

//------------------------------------------cache ram interface----------------------------------
typedef struct {
	bit [NTHREADIDMSB:0]				tid;			//request threadid

`ifdef SYNP94
	struct packed{
`else	
	union packed{
`endif	
		bit [ICACHEINDEXMSB_IU:ICACHEINDEXLSB_IU]	I;
		bit [DCACHEINDEXMSB_IU:DCACHEINDEXLSB_IU]	D;
	}index;			//cache line index
}cache_ram_read_in_type;

typedef struct {
	bit [NTHREADIDMSB:0]				tid;	//request threadid

`ifdef SYNP94
	struct packed{
`else	
	union packed{
`endif
		bit [ICACHEINDEXMSB_IU:ICACHEINDEXLSB_IU]	I;
		bit [DCACHEINDEXMSB_IU:DCACHEINDEXLSB_IU]	D;	
	}index;	//cache line index
	
	cache_tag_type					 tag;	//tag
	cache_data_type					data;	//data
	bit						        we_tag;	//tag write enable

`ifdef SYNP94
	struct packed{
`else	
	union packed{
`endif
		bit [ICSIZE-1:0]			I;
		bit [DCSIZE-1:0]			D;						
	}we_data;//data write enable
}cache_ram_write_in_type;	//write tag or data

typedef struct {
  bit [NTHREADIDMSB:0]				tid;			//request threadid

`ifdef SYNP94
  struct packed{
`else	
  union packed{
`endif	
    bit [ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]	I;
    bit [DCACHEINDEXMSB_MEM:DCACHEINDEXLSB_MEM]	D;
  }index;			//cache line index
}cache_ram_read_wide_in_type;

typedef struct {
  bit [NTHREADIDMSB:0]				tid;	//request threadid

`ifdef SYNP94
  struct packed{
`else	
  union packed{
`endif
    bit [ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]	I;
    bit [DCACHEINDEXMSB_MEM:DCACHEINDEXLSB_MEM]	D;	
  }index;	//cache line index
  
  cache_tag_type					      tag;	     //tag
  cache_data_wide_type					data;	    //data
  bit						               we_tag;	  //tag write enable (not used by mem)

`ifdef SYNP94
  struct packed{
`else	
  union packed{
`endif
    bit [ICSIZE-1:0]			I;
    bit [DCSIZE-1:0]			D;						
  }we_data;//data write enable
}cache_ram_write_wide_in_type;	//write tag or data


typedef struct {
	cache_ram_read_in_type		 read;			 //read cache_ram input
	cache_ram_write_in_type		write;			//write cache_ram input
}cache_ram_in_type;		//interface to icache bram

typedef struct {
	cache_tag_type			 tag;			 //tag
	cache_data_type			data;			//data
}cache_ram_out_type;		//interface to icache bram

typedef struct {
  cache_ram_read_wide_in_type		 read;			 //read cache_ram_wide input
  cache_ram_write_wide_in_type		write;			//write cache_ram_wide input
}cache_ram_wide_in_type;		//interface to cache bram

typedef struct {
  cache_tag_type			      tag;			 //tag
  cache_data_wide_type			data;			//data
}cache_ram_wide_out_type;		//interface to cache bram

//------------------------------------------I$ <-> interface----------------------------------
typedef struct {
	bit [NTHREADIDMSB:0]		tid;			      //request threadid
	bit				              tid_parity;		//threadid parity
	bit [31:2]			         vpc;			      //virtual PC,; used as index	
	bit				              valid;			    //lookup valid	
	bit				              replay;			   //replay mode
}icache_if_in_type;      //I$ input from IU

typedef bit[31:0] 			icache_data_out_type;

typedef struct {
	//tlb_read_in_type		mmu_req;		   //used as mmu request 
	bit [31:ITLBINDEXLSB]		paddr;			   //physical address	(PPN)
	bit 				             tlb_hit;		  //tlb hit & no exception
//	imem_op_type			      rtype;			   //request type
	bit				             valid;			   //valid tlb output
	bit				             exception;		//IAEX exception

	bit                  iflush;      //flush i$?
  bit [FLUSHIDXMSB:0]  flushidx;    //flush index
}icache_de_in_type;						//decode input, from IMMU

typedef struct {
	bit				replay;			   //replay request from cache
	bit				luterr;			   //lutram error
	bit				bramerr;		   //bram error (db bits)
	bit				sb_ecc;			   //sb error corrected by ECC	
}cache2iu_ctrl_type;			//cache -> IU control signals	

//-------------------------------------------dcache data structures-------------------------------------------------
typedef struct {
//	tlb_read_in_type		   mmu_req;		  //used as mmu request 
	bit [31:DTLBINDEXLSB]		paddr;			   //physical address	
	bit 				             tlb_hit;		  //tlb hit & no exception
//	dmem_op_type			      rtype;			   //request type
	bit				             valid;	  	  //exception or invalid
	bit				             exception;		//DAEX exception
}dcache_mmu_in_type;	

typedef struct {
	struct {
		bit [NTHREADIDMSB:0]		tid;			      //request threadid
		bit [31:2]			         va;			       //virtual PC,; used as index						
//    bit                   ldst_a;      //ASI load/store/		
//    asi_type              asi;   
	}m1;			//first cycle input

	struct {
    tlb_mmu_op_type       walk_state;
		bit [NTHREADIDMSB:0]		tid;			      //request threadid
		bit				              tid_parity;		//threadid parity
//		bit                   ldst_a;      //ASI load/store/		
    // added for udc
    bit                   atomic;      //is instruction SWAP/ST/LDSTUB?
    // end for udc
    	bit					  no_ldreplay;				//ld miss latency hiding in microcode mode
//	    asi_type              asi;   
		bit [31:2]			         va;		 	      //virtual address,; used as index	
		bit				              valid;			    //lookup valid	
//		bit				              replay;			   //replay mode
		//duplicate inputs of m1 to save DFFs
		bit [31:0]			         store_data;
		bit [3:0]			          byte_mask; 		 			
		LDST_CTRL_TYPE			     ldst;			     //ld/st/flush/nop indicator
		bit                   dma_mode;   //flush in dma mode (flush $ blocks based on idx not virtual address)
	}m2;			//second cycle input
}dcache_iu_in_type;

typedef bit [63:0] 			dcache_data_out_type;	//d$ 64-bit data output

//type for cache statistics
typedef enum {hit, miss, nop}  cache_stat_type;

`ifndef SYNP94
endpackage
`endif

