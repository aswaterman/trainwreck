//---------------------------------------------------------------------------   
// File:        memif.v
// Author:      Zhangxi Tan
// Description: iu memory interface: mem command queue
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libconf::*;
import libmemif::*;
import libiu::*;
import libcache::*;
import libstd::*;
`else
`include "../cpu/libiu.sv"
`include "../cpu/libmmu.sv"
`include "../cpu/libcache.sv"
`include "libmemif.sv"
`endif

//inst memory command fifo: input register (IU) is in module imem_if 
module imem_cmd_fifo(input iu_clk_type gclk, input rst,
		     input bit			we,
		     input bit			re,
//		     input bit			new_req,
		     input  imem_cmd_fifo_type	din,
		     output imem_cmd_fifo_type	dout,
		     output bit			empty,
		     output cache_ram_read_in_type	bram_addr);
	mem_cmd_fifo_pt_type		pt;		      //fifo pointer
	bit [NTHREADIDMSB:0]		addr;		    //TDM fifo addr
	bit							        d_read;		  //just read
	bit							        last_read;	//latest operation is read
	//memory content
  (* syn_ramstyle = "select_ram" *)	imem_cmd_fifo_type	 cmdfifo[0:NTHREAD-1];

	imem_cmd_fifo_type		fifo_out;	//wires
	

	always_ff @(posedge gclk.clk) begin
		//d_read <= (rst) ? '0 : re;		
		if (rst) d_read <= '0; else d_read <= re;
	end

	always_ff @(negedge gclk.clk) begin
		if (rst)
			last_read <= '1;
		else begin
			if (we)
				last_read <= '0;
			else if (d_read) 
				last_read <= '1;
			else
				last_read <= last_read;
		end
	end

	always_ff @(negedge gclk.clk) begin		//tail pointer written from IU	
		if (rst)
			pt.tail <= '0;
		else begin
			//cross clk domain, complete at ~400 MHz
			//pt.tail <= (we == 1'b1 && (pt.head != ntail)) ? ntail : pt.tail;
			pt.tail <= (we) ? pt.tail+1 : pt.tail;
		end
	end 

	always_ff @(posedge gclk.clk) begin		//head pointer read by mem control
		if (rst)
			pt.head <= '0;
		else
			//pt.head <= (re == 1'b1 && empty == 1'b0) ? pt.head + 1 : pt.head;
			pt.head <= (re) ? pt.head + 1 : pt.head;
	end

	//complete at ~400 MHz
	assign addr = (gclk.ce)? pt.head : pt.tail;	//ram address
	assign empty = (pt.head == pt.tail) ? last_read : '0;
	assign fifo_out = cmdfifo[addr]; 
	
	//RAMs
	always_ff @(negedge gclk.clk) begin		//write at negedge
		//RAMs
		if (we) cmdfifo[addr] <= din;
	end
	
	always_ff @(posedge gclk.clk) begin  //output register
		//empty flag
		//empty <= (pt.head == pt.tail) ? last_read : '0;

		//balance output reg in cache BRAM 	
		//dout_reg <= fifo_out;
		//dout     <= dout_reg;
		dout <= fifo_out;
		
		//read out bram addr
		bram_addr.tid     <= fifo_out.tid;
   	bram_addr.index.I <= {fifo_out.ret_index, 1'b0};    //only read cache tag		
	end
endmodule

//dual port ram version of imem_cmd_fifo
module imem_cmd_fifo_sdr(input iu_clk_type gclk, input rst,
		     input bit			we,
		     input bit			re,
//		     input bit			new_req,
		     input  imem_cmd_fifo_type	din,
		     output imem_cmd_fifo_type	dout,
		     output bit			empty,
		     output cache_ram_read_in_type	bram_addr);
	mem_cmd_fifo_pt_type		pt;		      //fifo pointer  
	bit [NTHREADIDMSB:0]  nhead;

	//memory content
  (* syn_ramstyle = "select_ram" *)	imem_cmd_fifo_type	 cmdfifo[0:NTHREAD-1];

	imem_cmd_fifo_type		fifo_out;	//wires


  assign nhead = pt.head + 1;
	always_ff @(posedge gclk.clk) begin		
		if (rst) begin
			pt.tail <= '0;
			pt.head <= '0;
		end
		else begin
			pt.tail <= (we) ? pt.tail+1 : pt.tail;
			pt.head <= (re) ? nhead : pt.head;
		end
	end 

	assign fifo_out = cmdfifo[pt.head]; 

	//RAMs
	always_ff @(posedge gclk.clk) begin		//write at negedge
		//RAMs
		if (we) cmdfifo[pt.tail] <= din;
	end
	
	always_ff @(posedge gclk.clk) begin  //output register		
		if (rst) 
		  empty <= '1;
		else begin
		  unique case({we, re})
		  2'b10 : empty <= '0;
		  2'b01 : empty <= (nhead == pt.tail);
		  default : empty <= empty;
		  endcase
		end  		  

		dout <= fifo_out;
		
		//read out bram addr
		bram_addr.tid     <= fifo_out.tid;
   	bram_addr.index.I <= {fifo_out.ret_index, 1'b0};    //only read cache tag		
	end
endmodule


//data memory command fifo : input register (IU) is in module dmem_if
module dmem_cmd_fifo(input iu_clk_type gclk, input rst,
		     input  bit				             we,
		     input  bit				             re,
		     input  bit 				            odd_addr,		//used to gen bram_addr
		     input  dmem_cmd_fifo_type		din,
		     output dmem_cmd_fifo_type		dout,
		     output bit 			empty,
		     output cache_ram_read_in_type	bram_addr);
	mem_cmd_fifo_pt_type		pt;		//fifo pointer
	bit [NTHREADIDMSB:0]		addr;		//TDM fifo addr
	//bit [NTHREADIDMSB:0]		ntail;		//wire: tail+1
	bit							d_read;		//just read
	bit							last_read;	//latest operation is read

	dmem_cmd_fifo_type		fifo_out;
	//memory content
  (* syn_ramstyle = "select_ram" *)	dmem_cmd_fifo_type	cmdfifo[0:NTHREAD-1];
	//dmem_cmd_fifo_type  dout_reg;  //registers to balance BRAM access pipeline
	
	//assign 	ntail = pt.tail + 1;
	always_ff @(posedge gclk.clk) begin
		//d_read <= (rst) ? '0 : re;		
		if (rst) d_read <= '0; else d_read <= re;
	end

	always_ff @(negedge gclk.clk) begin
		if (rst)
			last_read <= '1;
		else begin
			if (we) 
				last_read <= '0;
			else if (d_read) 
				last_read <= '1;
     	else 
				last_read <= last_read;
		end
	end

	always_ff @(negedge gclk.clk) begin		//tail pointer written from IU	
		if (rst)
			pt.tail <= '0;
		else begin
			//cross clk domain, complete at ~400 MHz
			//pt.tail <= (we == 1'b1 && (pt.head != ntail)) ? ntail : pt.tail;
			pt.tail <= (we) ? pt.tail+1 : pt.tail;
		end
	end 

	always_ff @(posedge gclk.clk) begin		//head pointer read by mem control
		if (rst)
			pt.head <= '0;
		else
			//pt.head <= (re == 1'b1 && empty == 1'b0) ? pt.head + 1 : pt.head;
			pt.head <= (re) ? pt.head + 1 : pt.head;
	end

	//complete at ~400 MHz
	assign addr = (gclk.ce)? pt.head : pt.tail;	//ram address
	assign fifo_out = cmdfifo[addr]; 
  assign empty = (pt.head == pt.tail) ? last_read : '0;  //is head = tail
                 	
	//RAMs & cacheram addr
	always_ff @(negedge gclk.clk) begin		//write at negedge
		//RAMs
		if (we) cmdfifo[addr] <= din;		
	end
	
	always_ff @(posedge gclk.clk) begin //output register
		//balance output reg in cache BRAM 		
		//dout_reg <= fifo_out;			
		//dout     <= dout_reg;
		dout <= fifo_out;

    //read out bram addr
		bram_addr.tid     <= fifo_out.tid;
    bram_addr.index.D <= {fifo_out.ret_index, odd_addr}; 
	end

endmodule

module dmem_cmd_fifo_sdr(input iu_clk_type gclk, input rst,
		     input  bit				             we,
		     input  bit				             re,
		     input  bit 				            odd_addr,		//used to gen bram_addr
		     input  dmem_cmd_fifo_type		din,
		     output dmem_cmd_fifo_type		dout,
		     output bit 			empty,
		     output cache_ram_read_in_type	bram_addr);
	mem_cmd_fifo_pt_type		pt;		//fifo pointer

	dmem_cmd_fifo_type		fifo_out;
	//memory content
  (* syn_ramstyle = "select_ram" *)	dmem_cmd_fifo_type	cmdfifo[0:NTHREAD-1];
	bit [NTHREADIDMSB:0]              nhead;

	assign nhead = pt.head + 1;
	always_ff @(posedge gclk.clk) begin		//tail pointer written from IU	
		if (rst) begin
			pt.tail <= '0;
			pt.head <= '0;
		end
		else begin
			pt.tail <= (we) ? pt.tail+1 : pt.tail;
			pt.head <= (re) ? nhead : pt.head;
		end
	end 


	assign fifo_out = cmdfifo[pt.head]; 
                 	
	//RAMs & cacheram addr
	always_ff @(posedge gclk.clk) begin		//write at negedge
		//RAMs
		if (we) cmdfifo[pt.tail] <= din;		
	end
	
	always_ff @(posedge gclk.clk) begin //output register
		dout <= fifo_out;

		if (rst) 
		  empty <= '1;
		else begin
		  unique case({we, re})
		  2'b10 : empty <= '0;
		  2'b01 : empty <= (nhead == pt.tail);
		  default : empty <= empty;
		  endcase
		end  		  


    //read out bram addr
		bram_addr.tid     <= fifo_out.tid;
    bram_addr.index.D <= {fifo_out.ret_index, odd_addr}; 
	end

endmodule


//dual port memory ctrl status buffer
module mem_stat_buf (input iu_clk_type gclk, input bit rst,
		      input  mem_stat_buf_in_type	 statin,			//input from IU & memctrl
		      output mem_stat_out_type		   statout);	//output to IU	
	bit [NTHREADIDMSB:0]				waddr;			//TDM write addr
	bit						we;			//TDM we	
	mem_stat_out_type				wdin;			//write data

 (* syn_ramstyle = "select_ram" *)	mem_stat_out_type	stat_buf[0:NTHREAD-1];	//RAM
	
	assign waddr = (gclk.ce) ? statin.iu.wtid : statin.mem.wtid;		//TDM write addr
	assign we    = (gclk.ce) ? statin.iu.we | rst  : statin.mem.we;			 //TDM we
	assign wdin  = (gclk.ce) ? statin.iu.wdin : statin.mem.wdin;		//TDM write data
		
	//read port
	assign statout = stat_buf[statin.iu.rtid];
	
	always_ff @(posedge gclk.clk2x) begin
		if (we) stat_buf[waddr] <= wdin;
	end
endmodule

//inst memory if
module  imem_if #(parameter INITCREDIT=2, parameter read2x=0, parameter write2x=0)
        (input iu_clk_type gclk, input rst,
	       //memory<->IU
	       input bit [NTHREADIDMSB:0]	iu2mem_tid,	//request busy bit read back
	       input  mem_cmd_in_type		   iu2mem_cmd,	//memory command
	       output mem_stat_out_type		 mem2iu_stat,	//output busy bit
	       //memory<->cache
	       input  cache_ram_out_type		cacheram2mem,
	       output cache_ram_in_type		 mem2cacheram,
	       //memctrl if <-> mem ctrl
	       input  mem_ctrl_out_type		 from_mem,	//mem->I
	       output mem_ctrl_in_type		  to_mem,
	       //parity or ecc errors
	       output bit			luterr
		);
	
	mem_cmd_in_type		rmem_cmd;			//input register for mem_cmd
	//bit			icmd_fifo_we;			//i-cmd fifo we
	//bit			icmd_fifo_re;			//i-cmd fifo re
	bit			               icmd_fifo_empty;		//i-cmd fifo empty
	imem_cmd_fifo_type	  icmd_fifo_din;			 //i-cmd fifo input
	imem_cmd_fifo_type	  icmd_fifo_dout;			//i-cmd fifo output
	
	mem_stat_buf_in_type	mem_stat_in;			 //status buffer input
	mem_stat_out_type	   mem_stat_out;			//status buffer output

	//mem_ctrl_in_type	    mem_out_reg, mem_out_v;		//mem output register
	mem_ctrl_in_type	          mem_out_v;		    //mem output register

  mem_ctrl_addr_prefix_type  mem_out_addr_prefix;

	
	cache_ram_read_in_type	cache_read_addr;		//bram read addr

	//credit based flow control
	memif_flow_control_type		xfer_ctrl_v, xfer_ctrl_r; 
	bit [MAXMEMCREDITMSB:0]  dec_xfer_ccnt;
	
	bit                      icmd_fifo_re;
	
  //delayed status update for write1x and write2x
  (* syn_preserve=1 *) bit [NTHREADIDMSB:0]    r_stat_tid, d_stat_tid;
  bit                     r_stat_we, d_stat_we;
		
	//-----------------------memory if<-> IU-----------------------
	//always_comb begin
	always_comb begin
		icmd_fifo_din.tid        = rmem_cmd.tid;
		icmd_fifo_din.cmd        = rmem_cmd.cmd.I;
		icmd_fifo_din.ret_index  = rmem_cmd.ret_index.I;
		icmd_fifo_din.parity     = (LUTRAMPROT)? ^{rmem_cmd.tid_parity, rmem_cmd.cmd.I, rmem_cmd.ret_index.I} : '0;  

		mem_stat_in.iu.rtid        = iu2mem_tid;
		mem_stat_in.iu.wtid        = rmem_cmd.tid;				
		mem_stat_in.iu.we          = rmem_cmd.valid;
		mem_stat_in.iu.wdin.busy   = ~rst; 	//busy
		mem_stat_in.iu.wdin.parity = (LUTRAMPROT)? ~rst : '0;
	end
	
	//-----------------------To memory-----------------------
	//always_comb begin		
	
	always_comb begin		//flow control
      //default value
      if (read2x == 0) begin
        xfer_ctrl_v.ccnt    = xfer_ctrl_r.ccnt;        
        xfer_ctrl_v.fifo_re = xfer_ctrl_r.fifo_re;
        xfer_ctrl_v.valid   = '0;
      
        dec_xfer_ccnt       =  '0;
      
    			unique case (xfer_ctrl_r.fifo_re)
        0: begin 
             if (!icmd_fifo_empty && (xfer_ctrl_r.ccnt > 0 || from_mem.ctrl.cmd_re > 0 )) begin
              xfer_ctrl_v.fifo_re = '1;
              xfer_ctrl_v.valid   = '1;
              dec_xfer_ccnt = 1;
            end 
/*              if (!from_mem.ctrl.cmd_re)
                 xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt - 1;                  
            end
            else begin          
              if (from_mem.ctrl.cmd_re)
                xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt + 1;
            end */                     
        end
        1: begin
          xfer_ctrl_v.valid   = '1;
          xfer_ctrl_v.fifo_re = '0;  
          
          dec_xfer_ccnt = 1;
//          if (!from_mem.ctrl.cmd_re)
//              xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt - 1;      
         end         
			 endcase
			
			 xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt - dec_xfer_ccnt + from_mem.ctrl.cmd_re; 
			 
			 icmd_fifo_re     = xfer_ctrl_r.fifo_re;
		  end
		  else begin
		    xfer_ctrl_v.ccnt    = INITCREDIT;        //no use
		    xfer_ctrl_v.fifo_re = '0;                //no use
		    
		    xfer_ctrl_v.valid   = ~icmd_fifo_empty & from_mem.ctrl.cmd_re[0];
		    icmd_fifo_re        = xfer_ctrl_v.valid;
		  end
	end

	always_ff @(posedge gclk.clk) begin
		if (rst) begin
			xfer_ctrl_r.ccnt    <= INITCREDIT;		  //has 2 credits
      xfer_ctrl_r.fifo_re <= '0;
			xfer_ctrl_r.valid   <= '0;
		end
		else 
      xfer_ctrl_r <= xfer_ctrl_v;    
	end
 
  always_comb begin
		//mem 1st half
		mem_out_v.s1.tid              = icmd_fifo_dout.tid;
		mem_out_v.s1.tid_index_parity = (LUTRAMPROT)?icmd_fifo_dout.parity ^ (^icmd_fifo_dout.cmd) : '0;
		mem_out_v.s1.ret_index.I      = icmd_fifo_dout.ret_index;
    mem_out_v.s1.valid            = xfer_ctrl_r.valid; 
		
		//mem 2nd half
		mem_out_v.s2.addr_prefix.I = cacheram2mem.tag.tag.I; 
    mem_out_v.s2.data          = cache_data_none;    //no use for i-cache, because never write back
    
    
		mem2cacheram.read          = cache_read_addr;

		if (icmd_fifo_dout.cmd == ITLB_WRITE) 
			mem_out_v.s1.we = xfer_ctrl_r.valid; 
		else
			mem_out_v.s1.we = '0;
	end

	//-----------------------From memory-----------------------
  //delayed status buffer we controls
  always_ff @(posedge gclk.clk) begin
    r_stat_tid <= from_mem.res.tid;
    r_stat_we  <= from_mem.res.done;
    
    if (write2x) begin
      d_stat_tid <= r_stat_tid;
      d_stat_we  <= r_stat_we;
    end
  end

	always_comb begin
		mem2cacheram.write.tid     = from_mem.res.tid;
		mem2cacheram.write.index.I = from_mem.res.ret_index.I;
		mem2cacheram.write.data    = from_mem.res.data;

		if (write2x == 0) begin
    		mem2cacheram.write.we_data.I[ICSIZE/2-1:0]      = {ICSIZE/2{from_mem.res.valid & ~from_mem.res.ret_index.I[ICACHEINDEXLSB_IU]}};
    		mem2cacheram.write.we_data.I[ICSIZE-1:ICSIZE/2] = {ICSIZE/2{from_mem.res.valid & from_mem.res.ret_index.I[ICACHEINDEXLSB_IU]}};
//    		mem_stat_in.mem.wtid = from_mem.res.tid;
//      mem_stat_in.mem.we   = from_mem.res.done;    
    		mem_stat_in.mem.wtid = r_stat_tid;
      mem_stat_in.mem.we   = r_stat_we;    
		end
		else begin //double clocked write
		  mem2cacheram.write.we_data.I = {ICSIZE{from_mem.res.valid}};
		  mem_stat_in.mem.wtid = d_stat_tid;
      mem_stat_in.mem.we   = d_stat_we;
  		end
		 
		mem_stat_in.mem.wdin = '{0, 0};			//memory is ready

		mem2cacheram.write.tag    = cache_tag_none;
		mem2cacheram.write.we_tag = '0;		
	end

  //synthesis translate_off
  property guard_credit;
    @(posedge(gclk.clk))
       disable iff (rst)
        xfer_ctrl_r.ccnt <= INITCREDIT;
  endproperty

  assert property (guard_credit) else $display ("Error: %t more credits returned to imem_if!", $time);
  //synthesis translate_on

/*  assign to_mem = mem_out_reg;


	always @(posedge gclk.clk) begin
		
		rmem_cmd    <= iu2mem_cmd;				//cmd fifo input register
		
		mem2iu_stat <= mem_stat_out;			//stat buffer output register

		mem_out_reg.s1 = mem_out_v.s1;			//output register		
		
	
		if (rst) begin
			mem_out_reg.s1.valid = '0;			
		end
				
		luterr <= (LUTRAMPROT)? ^icmd_fifo_dout : '0;		 
	end
	
	//latch result from cacheram, also help routing
  always_ff @(negedge gclk.clk) begin
     mem_out_reg.s2 <= mem_out_v.s2;    
  end

*/

  function automatic mem_ctrl_in_s1_type get_mem_out_reg_s1();
    //posedge function
`ifndef SYNP94    
    mem_ctrl_in_s1_type s1 = mem_out_v.s1;			//output register		
`else
    mem_ctrl_in_s1_type s1;			//output register		
    s1 = mem_out_v.s1;			//output register		
`endif    
    
    if (rst) s1.valid = '0;			
      
    return s1;
  endfunction
   

	always_ff @(posedge gclk.clk) begin		
		rmem_cmd    <= iu2mem_cmd;				 //cmd fifo input register
		mem2iu_stat <= mem_stat_out;			//stat buffer output register

	  to_mem.s1 <= get_mem_out_reg_s1();	  			

		luterr <= (LUTRAMPROT)? ^icmd_fifo_dout : '0;		 
	end

  //latch result from cacheram, also help routing
  generate 
    if (read2x==0) begin
      always_ff @(negedge gclk.clk) begin
        to_mem.s2 <= mem_out_v.s2;    
      end
    end
    else begin
      always_comb begin
        to_mem.s2.data        = mem_out_v.s2.data;
        to_mem.s2.addr_prefix = mem_out_addr_prefix;
        to_mem.cmdfifo_empty  = icmd_fifo_empty;
      end
//      always_latch begin 
//        if (gclk.clk)
//          mem_out_addr_prefix <= mem_out_v.s2.addr_prefix;
//      end
	   always_ff @(negedge gclk.clk)  mem_out_addr_prefix <= mem_out_v.s2.addr_prefix;
    end
  endgenerate

	imem_cmd_fifo_sdr	icmd_fifo(.gclk, .rst,
				.we(rmem_cmd.valid),
//		     		.re(xfer_ctrl_r.fifo_re),
           .re(icmd_fifo_re),
		     		.din(icmd_fifo_din),
		     		.dout(icmd_fifo_dout),
		     		.empty(icmd_fifo_empty),
				.bram_addr(cache_read_addr));

	mem_stat_buf	imem_stat(.gclk, .rst,
				  .statin(mem_stat_in),
				  .statout(mem_stat_out));
endmodule



//data memory if
module dmem_if #(parameter INITCREDIT=2, parameter read2x=0, parameter write2x=0, parameter nonblocking=0)
    (input iu_clk_type gclk, input rst,
	       //memory if <->IU
	       input bit [NTHREADIDMSB:0]	iu2mem_tid,	 //request busy bit read back
	       input  mem_cmd_in_type		   iu2mem_cmd,	 //memory command
	       output mem_stat_out_type		 mem2iu_stat,	//output busy bit
	       //memory if <->cache
	       input cache_ram_out_type		 cacheram2mem,
	       output cache_ram_in_type		 mem2cacheram,
	       //memctrl if <-> mem ctrl
	       input mem_ctrl_out_type		  from_mem,		//mem->d
	       output mem_ctrl_in_type		  to_mem,
	       //parity or ecc errors
	       output bit			luterr
		);
	
	(* syn_preserve=1*) mem_cmd_in_type		  rmem_cmd;			//input register for mem_cmd
	bit			             dcmd_fifo_empty;		//d-cmd fifo empty
	dmem_cmd_fifo_type	dcmd_fifo_din;			 //d-cmd fifo input
	dmem_cmd_fifo_type	dcmd_fifo_dout;			//d-cmd fifo output
	
	mem_stat_buf_in_type	mem_stat_in;			 //status buffer input
	mem_stat_out_type	   mem_stat_out;			//status buffer output
	
	//mem_ctrl_in_type	mem_out_reg, mem_out_v;		//mem output register
	mem_ctrl_in_type	    mem_out_v;		    //mem output register
	
	cache_ram_read_in_type	cache_read_addr;		//bram read addr


	//credit based flow control
	memif_flow_control_type		xfer_ctrl_v, xfer_ctrl_r; 
	bit [MAXMEMCREDITMSB:0]  dec_xfer_ccnt;

  //status update signals for write 1x and write 2x
  (* syn_preserve=1 *) bit [NTHREADIDMSB:0]    r_stat_tid, d_stat_tid;
  bit                     r_stat_we, d_stat_we;

  mem_ctrl_addr_prefix_type  mem_out_addr_prefix;
  bit                        dcmd_fifo_re;
   
	//-----------------------memory <-> IU-----------------------
	always_comb begin
		dcmd_fifo_din.tid        = rmem_cmd.tid;
		dcmd_fifo_din.cmd        = rmem_cmd.cmd.D;
		dcmd_fifo_din.ret_index  = rmem_cmd.ret_index.D;
		dcmd_fifo_din.parity     = (LUTRAMPROT)? ^{rmem_cmd.tid_parity, rmem_cmd.cmd.D, rmem_cmd.ret_index.D} : '0;  

		mem_stat_in.iu.rtid      = iu2mem_tid;
	
		mem_stat_in.iu.wtid      = (nonblocking)? {rmem_cmd.tid[0 +: log2x(NTHREAD) - log2x(NDCACHEBLOCK_MEM)] ,rmem_cmd.ret_index.D} :rmem_cmd.tid;				
		
		mem_stat_in.iu.we        = rmem_cmd.valid;
		mem_stat_in.iu.wdin.busy = ~rst; 	//busy
		mem_stat_in.iu.wdin.parity = (LUTRAMPROT)? ~rst : '0;
	end
	
	//-----------------------To memory-----------------------
  always_comb begin		//flow control
    if (read2x == 0) begin
      //default value
      xfer_ctrl_v.ccnt    = xfer_ctrl_r.ccnt;        
      xfer_ctrl_v.fifo_re = xfer_ctrl_r.fifo_re;
      xfer_ctrl_v.valid   = '0;

      dec_xfer_ccnt       = '0;
 
     unique case (xfer_ctrl_r.fifo_re)
       0: begin 
            if (!dcmd_fifo_empty && (xfer_ctrl_r.ccnt > 0 || from_mem.ctrl.cmd_re > 0 )) begin
             xfer_ctrl_v.fifo_re = '1;
             xfer_ctrl_v.valid   = '1;
             dec_xfer_ccnt = 1;
           end 
         end
       1: begin
         xfer_ctrl_v.valid   = '1;
         xfer_ctrl_v.fifo_re = '0;  
     
         dec_xfer_ccnt = 1;
         end         
        endcase
 
       xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt - dec_xfer_ccnt + from_mem.ctrl.cmd_re;      
       
       dcmd_fifo_re     = xfer_ctrl_r.fifo_re;
    end
    else begin
      	xfer_ctrl_v.ccnt    = INITCREDIT;        //no use
		   xfer_ctrl_v.fifo_re = '0;                //no use
		    
		   xfer_ctrl_v.valid   = ~dcmd_fifo_empty & from_mem.ctrl.cmd_re[0];
		   dcmd_fifo_re        = xfer_ctrl_v.valid;
    end
      /*
		  unique case (xfer_ctrl_r.fifo_re)
      0: begin 
           if (!dcmd_fifo_empty && (xfer_ctrl_r.ccnt > 0 || from_mem.ctrl.cmd_re == 1'b1)) begin
              xfer_ctrl_v.fifo_re = '1;
              xfer_ctrl_v.valid   = '1;
        
              if (!from_mem.ctrl.cmd_re)
                xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt - 1;
            end
            else begin
             if (from_mem.ctrl.cmd_re)
              xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt + 1;
            end
        end
      1: begin
          xfer_ctrl_v.valid   = '1;
          xfer_ctrl_v.fifo_re = '0;  
          
          if (!from_mem.ctrl.cmd_re)
              xfer_ctrl_v.ccnt = xfer_ctrl_r.ccnt - 1;      
         end
		  endcase */
  end

  always_ff @(posedge gclk.clk) begin
	  if (rst) begin
		  xfer_ctrl_r.ccnt    <= INITCREDIT;		  //has 2 credits
      xfer_ctrl_r.fifo_re <= '0;
		  xfer_ctrl_r.valid   <= '0;
	  end
	  else 
      xfer_ctrl_r <= xfer_ctrl_v;    
  end

	always_comb begin		
		mem_out_v.s1.tid               = dcmd_fifo_dout.tid;
		mem_out_v.s1.tid_index_parity  = (LUTRAMPROT)? dcmd_fifo_dout.parity ^ (^dcmd_fifo_dout.cmd) : '0;
		mem_out_v.s1.ret_index.D       = dcmd_fifo_dout.ret_index;
    mem_out_v.s1.valid             = xfer_ctrl_r.valid; 

		mem_out_v.s2.addr_prefix.D     = cacheram2mem.tag.tag.D; 
		mem_out_v.s2.data              = cacheram2mem.data;		


		mem2cacheram.read = cache_read_addr;

		if (dcmd_fifo_dout.cmd == DCACHE_WB || dcmd_fifo_dout.cmd == DTLB_WRITE) 
			mem_out_v.s1.we = xfer_ctrl_r.valid; 
		else
			mem_out_v.s1.we = '0;
	end

	//-----------------------From memory-----------------------
  //delayed status buffer we controls
  always_ff @(posedge gclk.clk) begin      
    r_stat_tid <= (nonblocking) ? {from_mem.res.tid[0 +: log2x(NTHREAD) - log2x(NDCACHEBLOCK_MEM)] ,from_mem.res.ret_index.D[DCACHEINDEXMSB_MEM:DCACHEINDEXLSB_MEM]} : from_mem.res.tid;
    r_stat_we  <= from_mem.res.done;
    
    if (write2x) begin
      d_stat_tid <= r_stat_tid;
      d_stat_we  <= r_stat_we;
    end
  end


	always_comb begin
		mem2cacheram.write.tid                          = from_mem.res.tid;
		mem2cacheram.write.index.D                      = from_mem.res.ret_index.D;
		mem2cacheram.write.data                         = from_mem.res.data;
		
		if (write2x == 0) begin
    		mem2cacheram.write.we_data.D[DCSIZE/2-1:0]      = {DCSIZE/2{from_mem.res.valid & ~from_mem.res.ret_index.D[DCACHEINDEXLSB_IU]}};
		  mem2cacheram.write.we_data.D[DCSIZE-1:DCSIZE/2] = {DCSIZE/2{from_mem.res.valid & from_mem.res.ret_index.D[DCACHEINDEXLSB_IU]}};

    	//	mem_stat_in.mem.wtid = from_mem.res.tid;      //this is a potential race
    	//	mem_stat_in.mem.we   = from_mem.res.done;
    	mem_stat_in.mem.wtid = r_stat_tid;
    	mem_stat_in.mem.we   = r_stat_we;
		end		
		else begin
		  mem2cacheram.write.we_data.D = {DCSIZE{from_mem.res.valid}};
		  mem_stat_in.mem.wtid = d_stat_tid;
		  mem_stat_in.mem.we   = d_stat_we;
		end
		
		mem_stat_in.mem.wdin = '{0, 0};			//memory is ready

		mem2cacheram.write.tag    = cache_tag_none;
		mem2cacheram.write.we_tag = '0;		//TODO: support flush
	end

  //synthesis translate_off
  property guard_credit;
    @(posedge(gclk.clk))
       disable iff (rst)
        xfer_ctrl_r.ccnt <= INITCREDIT;
  endproperty

  assert property (guard_credit) else $display ("Error: %t more credits returned to dmem_if!", $time);
  //synthesis translate_on

  function automatic mem_ctrl_in_s1_type get_mem_out_reg_s1();
    //posedge function
  `ifndef SYNP94
    mem_ctrl_in_s1_type s1 = mem_out_v.s1;			//output register		
  `else
      mem_ctrl_in_s1_type s1;				//output register		
      s1 = mem_out_v.s1;			//output register		
  `endif    
  
    if (rst) s1.valid = '0;			
      
    return s1;
  endfunction

	always_ff @(posedge gclk.clk) begin
		rmem_cmd    <= iu2mem_cmd;				  //cmd fifo input register
    mem2iu_stat <= mem_stat_out;			 //stat buffer output register
		to_mem.s1   <= get_mem_out_reg_s1();       			 //output register		
		
   	luterr <= (LUTRAMPROT)? ^dcmd_fifo_dout : '0;		 
	end

  generate 
   if (read2x==0) begin
  	//latch result from cacheram, also help routing
    always_ff @(negedge gclk.clk) begin
        to_mem.s2 <= mem_out_v.s2;    
    end
   end
   else begin
      always_comb begin
        to_mem.s2.data        = mem_out_v.s2.data;
        to_mem.s2.addr_prefix = mem_out_addr_prefix;
        to_mem.cmdfifo_empty  = dcmd_fifo_empty;
      end
      
//      always_latch begin 
//        if (gclk.clk)
		always_ff @(negedge gclk.clk)
          mem_out_addr_prefix <= mem_out_v.s2.addr_prefix;
//      end
   end
  endgenerate
  
	dmem_cmd_fifo_sdr	dcmd_fifo(.gclk, .rst,
				.we(rmem_cmd.valid),
        .re(dcmd_fifo_re),
  				.odd_addr(xfer_ctrl_r.fifo_re),		
		    .din(dcmd_fifo_din),
		    .dout(dcmd_fifo_dout),
		    .empty(dcmd_fifo_empty),
				.bram_addr(cache_read_addr));

	mem_stat_buf	dmem_stat(.gclk, .rst,
				  .statin(mem_stat_in),
				  .statout(mem_stat_out));
endmodule