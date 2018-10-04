//---------------------------------------------------------------------------   
// File:        libmemif.v
// Author:      Zhangxi Tan
// Description: Data structures for memory interface
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps


`ifndef SYNP94
import libiu::*;
import libcache::*;

package libmemif;
import libstd::*;
import libcache::*;
import libconf::*;
`endif

//-------------------------memory data structures------------------------------
//dual port lutram
typedef struct packed{	
	bit			busy;		//memory is busy
	bit			parity;		//parity bit if enabled	
}mem_stat_out_type;

//imem cmd fifo
typedef struct packed{
	bit [NTHREADIDMSB:0]				                    tid;	
	//imem_op_type					                           cmd;		     //i mem ops
	//bit [$bits(imem_op_type)-1:0]               cmd;
	bit [1:0]                                   cmd;
	bit [ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]	ret_index;	//return index
	bit						parity;
}imem_cmd_fifo_type;

//dmem cmd fifo
typedef struct packed {
	bit [NTHREADIDMSB:0]				                    tid;
	//dmem_op_type					                         cmd;		      //d mem ops
//	bit [$bits(dmem_op_type)-1:0]					          cmd;		      //d mem ops
  bit [1:0]                                   cmd;        //d mem ops
	bit [DCACHEINDEXMSB_MEM:DCACHEINDEXLSB_MEM]	ret_index;	//return index
	bit						parity;
}dmem_cmd_fifo_type;

typedef struct {	
	bit [NTHREADIDMSB:0]	head;		
	bit [NTHREADIDMSB:0]	tail;	
} mem_cmd_fifo_pt_type;			//FIFO pointers

//-------------------------------memory if--------------------------------------
//mem if input from IU
typedef struct{
	bit [NTHREADIDMSB:0]	tid;
	bit			tid_parity;
`ifdef SYNP94
	struct packed{
`else	
	union packed{
`endif	
		bit [ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]	I;
		bit [DCACHEINDEXMSB_MEM:DCACHEINDEXLSB_MEM]	D;
	}ret_index;		//write back block index;	
	bit			valid;		//valid input
`ifdef SYNP94
	struct packed{
`else	
	union packed{
`endif	
		//imem_op_type		I;	//i mem ops
		//dmem_op_type		D;	//d mem ops
		//bit [$bits(imem_op_type)-1:0] I;
		//bit [$bits(dmem_op_type)-1:0] D;
		bit [1:0] I;
		bit [1:0] D;
  	}cmd;	
}mem_cmd_in_type;		//memory op command

typedef struct {
	struct {
		bit [NTHREADIDMSB:0]		rtid;		//read tid
		bit [NTHREADIDMSB:0]		wtid;		//write tid
		bit				we;
		mem_stat_out_type		wdin;		//write data
	}iu;
	struct {
		bit [NTHREADIDMSB:0]		wtid;		//write tid
		bit				we;
		mem_stat_out_type		wdin;		//write data
	}mem;
}mem_stat_buf_in_type;


//input to memory controller
`ifdef SYNP94
typedef	struct packed{
`else	
typedef	union packed{
`endif  	
		  bit [31:ICACHETAGLSB]	I;
    		bit [31:DCACHETAGLSB]	D;
}mem_ctrl_addr_prefix_type;			          //cache tag as address prefix, (tag : index)

typedef struct {
    bit [NTHREADIDMSB:0]	tid;
    bit			               tid_index_parity;			//used for parity generation in lutram fifo in memctrl

`ifdef SYNP94
	struct packed{
`else	
    union packed{
`endif    
      bit [ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]	I;
      bit [DCACHEINDEXMSB_MEM:DCACHEINDEXLSB_MEM]	D;
    }ret_index;		             //write back block index;	

    bit			valid;		            //valid input
    bit			we;		               //write = 1
}mem_ctrl_in_s1_type;

typedef struct {
  	mem_ctrl_addr_prefix_type addr_prefix;			          //cache tag as address prefix, (tag : index)
  	cache_data_type		         data;
}mem_ctrl_in_s2_type;

typedef struct {
 bit                  cmdfifo_empty;
 mem_ctrl_in_s1_type  s1;     //valid since first half 
 mem_ctrl_in_s2_type  s2;     //valid since second half, because of BRAM
}mem_ctrl_in_type;

typedef struct {
 mem_ctrl_in_s1_type  s1;     //valid since first half
 
 struct {
    mem_ctrl_addr_prefix_type addr_prefix;			          //cache tag as address prefix, (tag : index)
    cache_data_wide_type		    data;
  }s2;        //valid since second half, because of BRAM
}mem_ctrl_wide_in_type;

//output from memory controller
typedef struct {
	//controls
	struct {
		bit	[MAXMEMCREDITMSB:0]		cmd_re;		//read next cmd
	}ctrl;	
	
	//output result
	struct {
		bit [NTHREADIDMSB:0]	tid;		

`ifdef SYNP94
		struct packed{
`else	
		union packed{
`endif		
			bit [ICACHEINDEXMSB_IU:ICACHEINDEXLSB_IU]	I;
			bit [DCACHEINDEXMSB_IU:DCACHEINDEXLSB_IU]	D;
		}ret_index;		//write back block index;	

		bit			valid;		          //result is done
		bit   done;             //mem access is done
		cache_data_type		data;		//cache data
	}res;
}mem_ctrl_out_type;

//output from memory controller
typedef struct {
  //controls
  struct {
    bit	[MAXMEMCREDITMSB:0]		cmd_re;		//read next cmd
  }ctrl;	
  
  //output result
  struct {
    bit [NTHREADIDMSB:0]	tid;		

`ifdef SYNP94
    struct packed{
`else	
    union packed{
`endif		
      bit [ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]	I;
      bit [DCACHEINDEXMSB_MEM:DCACHEINDEXLSB_MEM]	D;
    }ret_index;		//write back block index;	

    bit			valid;		          //result is done
    bit   done;             //mem access is done
    cache_data_wide_type		data;		//cache data
  }res;
}mem_ctrl_wide_out_type;

typedef struct {
		bit	[MAXMEMCREDITMSB:0]	ccnt;		  //credit count
		bit			               fifo_re;	//incremented every 2 cycles
		bit                  valid;   //valid output (fifo do_reg)
}memif_flow_control_type;

//-----------------------------memory network definition-----------------------------

//memory network buffers data types
typedef struct packed {
  bit                            we;      //write request (must be the MSB)
  bit [NTHREADIDMSB:0]           tid;     //thread id
  bit [31:ICACHEINDEXLSB_MEM]    addr;    //request addr (32-byte aligned/burst aligned)
  bit                            parity;  //parity bit
}imem_req_addr_buf_type;

typedef imem_req_addr_buf_type dmem_req_addr_buf_type;

typedef struct packed {
  bit [ICACHELINEMSB_IU:0]	   data;
  bit [ICACHELINESIZE_IU-1:0]	ecc_parity; //ECC parity bits 
}imem_req_data_buf_type;

typedef imem_req_data_buf_type dmem_req_data_buf_type;

//DMA support ?
typedef struct packed {
  bit [log2x(NMEMCTRLPORT*2)-1:0]           rid;       //requestor ID
  bit [NTHREADIDMSB:0]                      tid;
  bit [ICACHEINDEXMSB_IU:ICACHEINDEXLSB_MEM] ret_index;
  bit                                       write;
  bit                                       parity;
}mem_ret_buf_type;


`ifndef SYNP94
endpackage
`endif