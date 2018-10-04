//---------------------------------------------------------------------------   
// File:        libio.v
// Author:      Zhangxi Tan
// Description: IO interface definition
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps

// **************************************$ I/O timing ***********************************************
// pipeline stages           
//
//        |<-------------M1------------>|<-------------M2------------>|<------------XC------------->|
//
// clk     ______________                ______________                ______________
//        |              |              |              |              |              |
//                       ----------------              ----------------              ----------------
//         _______        _______        _______        _______        _______        _______
// clk2x  |       |      |       |      |       |      |       |      |       |      |       |
//                --------       --------       --------       --------       --------       --------
//
// CPU -> IO Bus
//   tid(M1) <-------------tid------------>
//             ^-------------------------------------------------sampled by I/O device immediately for IRL (combinatorial)
// 
//   addr(M2)<-------------addr----------->
//                                       ^-----------------------sampled by I/O device at posedge of clk in M2 for read/write data
//                                       
//   wdata, rw, en, we (M2)                <-------------xxxx----------->
//                                                                    ^------------------sampled by I/O device for write at posedge of clk in XC
//   irqack                                                              <-------------xxxx----------->
//                                                                                                   ^------------------sampled by the IRQ controller
// IO Bus -> CPU                          
// IRL       <-------------IRL------------>
//                                       ^ ----------------------------------------------sampled by CPU at posedge of clk in M1
//
// retry, rdata(ready before XC)            .....-------xxxx------------>
//                                                                    ^------------------sampled by CPU at posedge of clk in XC
//



`ifndef SYNP94
package libio;
import libconf::*;
`endif

parameter IO_AWIDTH = 20;			//support up to 1M I/O registers 
parameter IO_DWIDTH = 32;			//32-bit I/O data bus

//CPU->IO
typedef struct {
  //ready before the 1st memory stage
	bit [NTHREADIDMSB:0]  tid;		  //thread id
  //ready at the end of the 1st memory stage 
	bit [IO_AWIDTH-1:0]   addr;		  //request address
  //signals valid at the end of 2nd memory stage
	bit [IO_DWIDTH-1:0]   wdata;	          //write data
	bit                   rw;		  //read/write: read = 0, write = 1
	bit                   en;                 //enable (request is valid)
	bit                   replay;		  //this is a replayed instruction
	bit [IO_DWIDTH/8-1:0] we;		  //write byte enable
	bit                   wtid_valid; 	  //The run bit in ts
}io_bus_in_type;

//IO->CPU
typedef struct {
  //to 2n half of 1st memory stage
  bit [3:0]	            irl;		     //interrupt level 1-15 
  //to 2nd half of 2nd memory stage
	bit [IO_DWIDTH-1:0]   rdata;		   //read data
	//to exception stage
	bit		                 retry;		   //tell CPU to replay the I/O command, target is not responding
}io_bus_out_type;

`ifndef SYNP94
endpackage
`endif
