//---------------------------------------------------------------------------   
// File:        libxalu.v
// Author:      Zhangxi Tan
// Description: complex alu library data structure 
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps

`ifndef SYNP94
package libxalu;

import libiu::*;
import libconf::*;
`endif

typedef struct packed{
	logic [NTHREADIDMSB:0]	tid;				    //thread id
	logic [31:0]		         op1, op2;			//op1, op2	
//	mul_ctrl_type		      mode;				   //mode
// logic [$bits(mul_ctrl_type)-1:0] mode;
 logic [2:0]            mode;        //mode
  
	//parity bits
	logic			op1_parity, op2_parity;		  //parity bits for op
	logic			misc_parity;			            //parity bit for everything else
}xalu_in_fifo_type;				//input FIFO

typedef struct {						
  xalu_in_fifo_type    ififo_data;
  y_reg_type           y;        
  bit			               valid;				  //input is valid
  bit						op2zero;			 //used for divide by 0
  bit		               	replay;				 //replay bit
}xalu_dsp_in_type;				             //complex ALU input from IU

//const xalu_in_fifo_type xalu_in_fifo_none = '{0, 0, 0, 0, 0, 0, 0, 0};		//precision doesn't like this
`ifndef SYNP94
const xalu_in_fifo_type xalu_in_fifo_none = {'0, '0, '0, c_NOP, '0, '0, '0};
`else
const xalu_in_fifo_type xalu_in_fifo_none = {6'd0, 32'd0, 32'd0, c_NOP, 1'b0, 1'b0, 1'b0};
`endif

typedef struct packed{	
  logic [31:0]  res;
	logic			      N;
	logic			      Z;
	logic			      V;		                //carry is always 0 for complex ALU instructions
	logic			      parity;		           //parity bit, not including y
	y_reg_type  y;                  //y register
}xalu_obuf_type;				//output buffer data structure (not a FIFO)

const xalu_obuf_type init_obuf_data = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, init_y};

typedef struct packed {
  xalu_obuf_type       data;
  bit [NTHREADIDMSB:0]	tid;				    //thread id
  bit                  valid;      //output valid
}xalu_fu_out_type;    //functional unit output type (MUL, DIV, output to xalu_obuffer)

typedef struct {	
	bit [NTHREADIDMSB:0]	head;		
	bit [NTHREADIDMSB:0]	tail;	
} xalu_fifo_pt_type;		//FIFO pointers

typedef struct packed{
	bit			valid;
	bit			parity;		    //protecting single bit is costy!
}xalu_valid_type;

//------------------------------interface data structures------------------------------
//---------Y REG interfaces---------
typedef struct {
    bit [NTHREADIDMSB:0]  addr;
}xalu_y_in_read_type;

typedef struct {
    bit [NTHREADIDMSB:0]  addr;
    bit                   we;
    y_reg_type		          data;	 //write data;
}xalu_y_in_write_type;

typedef struct {
	struct {
      xalu_y_in_read_type  read;
      xalu_y_in_write_type write;
	}iu;				         //from IU
	struct {
      xalu_y_in_read_type  read;
	}div;            //from div unit
}xalu_y_in_type;			//Y input type

typedef struct {
	y_reg_type	iu;
	y_reg_type	div;
}xalu_y_out_type;		//Y output type

//---------xalu_valid_buf interfaces---------
typedef struct {
    bit [NTHREADIDMSB:0]  addr;
    bit                   we;
    xalu_valid_type		     data;	 //write data;
}xalu_valid_in_type;

`ifndef SYNP94
endpackage
`endif