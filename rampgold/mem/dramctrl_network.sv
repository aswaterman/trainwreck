//---------------------------------------------------------------------------   
// File:        dramctrl_network.sv
// Author:      Zhangxi Tan
// Description: DRAM network buffers, arbiters and etc.
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libconf::*;
import libstd::*;
import libiu::*;
import libmemif::*;
import libcache::*;
import libtech::*;
`else
`include "../cpu/libiu.sv"
`include "../cpu/libmmu.sv"
`include "../cpu/libcache.sv"
`include "libmemif.sv"
`endif

// imem/dmem network timing
//         ______________                ______________ 
// clk    |              |              |              |                |
//                        --------------                ----------------                                      
//         _______        _______        _______        _______
// clk2x  |       |      |       |      |       |      |       |
//                --------       --------       --------       --------
//
//          <-------mux bus en(re)------->
//                  port mask
//
//                                         <--------------Addr------------->
//
// One dout reg            <-----data1----><-----data2----->                   
// two dout reg                            <-----data1-----><-----data2---->                   
//               
//          <------------ahead------------><-----------ahead+1------------->

//single port memory for address, read at clk1x (posedge), write at clk1x (negedge)
//dual port memory, read at clk2x, write at clk1x (posedge)
module imem_network_buf #(parameter bufdepth=32)   //default depth (maximum of 32) must be power of 2
      (input  iu_clk_type gclk, input rst, 
       input  mem_ctrl_in_type       reqin,
       input  bit                    re,               //read enable
       output imem_req_addr_buf_type aout,
       output imem_req_data_buf_type dout,
       output bit                    valid,            //output is valid
       output bit                    nonempty          //never need full flag, because credit based flow control
       );

  (* syn_ramstyle = "select_ram" *)	imem_req_addr_buf_type	 addrbuf[0:bufdepth-1];
  imem_req_addr_buf_type    abuf_out, abuf_in;
       
  bit [log2x(bufdepth)-1:0] ahead, atail;                                //head/tail counters
  (* syn_maxfan = 20 *)     bit [log2x(bufdepth)-1:0] a_addr;            //TDM address buffer address
  bit                       d_read, last_read;                          //signals for flag generator
  
  bit                       abuf_we;           //address buffer we
  bit                       abuf_re;           //address buffer re
  
//  bit                       dbuf_re;           //data buffer re
  
  (* syn_ramstyle = "select_ram" *)	imem_req_data_buf_type	 databuf[0:bufdepth*2-1];
  imem_req_data_buf_type            dbuf_out, dbuf_in; 

  bit [log2x(bufdepth):0] dhead, dtail;        //data fifo counters

  bit                    r_nonempty;
  
  //flag generation
  always_ff @(posedge gclk.clk) begin
    if (rst) d_read <= '0; else d_read <= re;
  end

  always_ff @(negedge gclk.clk) begin
    if (rst)
        r_nonempty <= '0;
//      last_read <= '1;
    else begin
      if (abuf_we)
//        last_read <= '0;
        r_nonempty <= '1;
      else if (d_read) 
//        last_read <= '1;
        r_nonempty <= (ahead == atail) ? '0 : '1;
      else
//        last_read <= last_read;
        r_nonempty <= r_nonempty;
    end
  end
  
  //synthesis translate_off
  property abuf_we_prop;
    disable iff (rst)
      @(posedge gclk.clk)
        ((abuf_we == 1'b1) |-> (reqin.s1.valid == 1'b1) ) and ((abuf_we == 1'b1) |=> (abuf_we == 1'b0));   
  endproperty
  
  //make sure abuf_we is high only for 1 cycle and we=1 only when data is valid
  assert property(abuf_we_prop) else $error("memory network address buffer we error");
  //synthesis translate_on
  
  
  //address buffer we control
  always_ff @(posedge gclk.clk) begin
    if (rst) 
      abuf_we <= '0;
    else 
      abuf_we <= (reqin.s1.valid) ? ~abuf_we : abuf_we;
  end

  //address buffer pointer control
  always_ff @(negedge gclk.clk) begin		//tail pointer written by mem network	
		if (rst)
			atail <= '0;
		else begin
			//cross clk domain, complete at clk2x
			atail <= (abuf_we) ? atail+1 : atail;
		end
	end 

	always_ff @(posedge gclk.clk) begin		//head pointer read by mem control
		if (rst)
			ahead <= '0;
		else
			ahead <= (re) ? ahead + 1 : ahead;
	end
	
  //data buffer pointer control
  always_ff @(posedge gclk.clk) begin
    if (rst)
      dtail <= '0;
    else
      dtail <= (reqin.s1.valid) ? dtail + 1 : dtail;
  end
  
  always_ff @(posedge gclk.clk2x) begin
    if (rst)
        dhead <= '0;
    else
//        dhead <= (dbuf_re) ? dhead + 1 : dhead;
          dhead <= (d_read) ? dhead + 1 : dhead;
  end
  
  always_comb begin
   //complete at ~266 MHz
   a_addr = (gclk.ce)? ahead : atail;	//ram address
//   empty =  (ahead == atail) ? last_read : '0;

//   dbuf_re = (gclk.ce)? re : d_read & re;
    
   //prepare data
   abuf_in.tid  = reqin.s1.tid;
   abuf_in.addr = {reqin.s2.addr_prefix.I, reqin.s1.ret_index.I};    
   abuf_in.we   = reqin.s1.we;      
   abuf_in.parity = (LUTRAMPROT) ? ^{reqin.s1.tid_index_parity, abuf_in.addr, abuf_in.we} : '0;   //parity bit
   
   dbuf_in.data       = reqin.s2.data.data.I;
   dbuf_in.ecc_parity = reqin.s2.data.ecc_parity.I;
  end

  assign  abuf_out = addrbuf[a_addr];   
  //assign  dbuf_out = databuf[dhead];
  assign dout = databuf[dhead];
  //RAMs
  always_ff @(negedge gclk.clk) begin		//write at negedge
    if (abuf_we) addrbuf[a_addr] <= abuf_in;          
    if (reqin.s1.valid) databuf[dtail] <= dbuf_in;
  end
  
//  assign nonempty = (ahead == atail) ? ~last_read : '1;
  assign nonempty = r_nonempty;

  always_ff @(posedge gclk.clk) begin  //output register
    aout  <= abuf_out;
    valid <= r_nonempty & re;           
  end
  
//  always_ff @(posedge gclk.clk2x)
//    dout <= dbuf_out;
  
endmodule


//single port memory for address, read at clk1x (posedge), write at clk1x (negedge)
//dual port memory, read at clk2x, write at clk1x (posedge)
module dmem_network_buf #(parameter bufdepth=32)   //default depth (maximum of 32) must be power of 2
      (input  iu_clk_type gclk, input rst, 
       input  mem_ctrl_in_type       reqin,
       input  bit                    re,               //read enable
       output dmem_req_addr_buf_type aout,
       output dmem_req_data_buf_type dout,
       output bit                    valid,
       output bit                    nonempty          //never need full flag, because credit based flow control
       );

  (* syn_ramstyle = "select_ram" *)	dmem_req_addr_buf_type	 addrbuf[0:bufdepth-1];
  dmem_req_addr_buf_type    abuf_out, abuf_in;
       
  bit [log2x(bufdepth)-1:0] ahead, atail;                                //head/tail counters
  (* syn_maxfan = 20 *)     bit [log2x(bufdepth)-1:0] a_addr;            //TDM address buffer address
  bit                       d_read, last_read;                          //signals for flag generator
  
  (* syn_ramstyle = "select_ram" *)	dmem_req_data_buf_type	 databuf[0:bufdepth*2-1];
  dmem_req_data_buf_type            dbuf_out, dbuf_in;

  bit [log2x(bufdepth):0] dhead, dtail;        //data fifo counters

  bit                    abuf_we;              //address buffer we
//  bit                    dbuf_re;              //data buffer re
  
  bit                    r_nonempty;
  //flag generation
  always_ff @(posedge gclk.clk) begin
    if (rst) d_read <= '0; else d_read <= re;
  end

  always_ff @(negedge gclk.clk) begin
    if (rst) begin
//      last_read <= '1;
      r_nonempty  <= '0;
    end
    else begin
      if (abuf_we) begin
//        last_read <= '0;
        r_nonempty <= '1;
      end
      else if (d_read) begin
//        last_read <= '1;
        r_nonempty <= (ahead == atail) ? '0 : '1;
      end
      else begin
//        last_read <= last_read;
        r_nonempty <= r_nonempty;
      end
    end
  end
  assign nonempty = r_nonempty;

  //synthesis translate_off  
  property abuf_we_prop;
    disable iff (rst)
      @(posedge gclk.clk)
        ((abuf_we == 1'b1) |-> (reqin.s1.valid == 1'b1) ) and ((abuf_we == 1'b1) |=> (abuf_we == 1'b0));   
  endproperty
  
  //make sure abuf_we is high only for 1 cycle and we=1 only when data is valid
  assert property(abuf_we_prop) else $error("memory network address buffer we error");
  //synthesis translate_on
  
  //address buffer we control
  always_ff @(posedge gclk.clk) begin
    if (rst)
      abuf_we <= '0;
    else 
      abuf_we <= (reqin.s1.valid) ? ~abuf_we : abuf_we;
  end
  

  //address buffer pointer control
  always_ff @(negedge gclk.clk) begin		//tail pointer written by mem network	
    if (rst)
      atail <= '0;
    else begin
      //cross clk domain, complete at clk2x
      atail <= (abuf_we) ? atail+1 : atail;
    end
  end 

  always_ff @(posedge gclk.clk) begin		//head pointer read by mem control
    if (rst)
      ahead <= '0;
    else
      ahead <= (re) ? ahead + 1 : ahead;
  end
  
  //data buffer pointer control--
  always_ff @(posedge gclk.clk) begin
    if (rst)
      dtail <= '0;
    else
      dtail <= (reqin.s1.valid) ? dtail + 1 : dtail;
  end
  
  always_ff @(posedge gclk.clk2x) begin
    if (rst)
        dhead <= '0;
    else
  //      dhead <= (dbuf_re) ? dhead + 1 : dhead;
          dhead <= (d_read) ? dhead + 1 : dhead;
  end
  
  always_comb begin
   //complete at ~266 MHz
   a_addr = (gclk.ce)? ahead : atail;	//ram address
// empty  = (ahead == atail) ? last_read : '0;    
//   dbuf_re = (gclk.ce)? re : d_read & re;       //align the first read to posedge of clk
    
   //prepare data
   abuf_in.tid  = reqin.s1.tid;
   abuf_in.addr = {reqin.s2.addr_prefix.D, reqin.s1.ret_index.D};    
   abuf_in.we   = reqin.s1.we;      
   abuf_in.parity = (LUTRAMPROT) ? ^{reqin.s1.tid_index_parity, abuf_in.addr, abuf_in.we} : '0;   //parity bit
   
   dbuf_in.data       = reqin.s2.data.data.D;
   dbuf_in.ecc_parity = reqin.s2.data.ecc_parity.D;
  end

  assign  abuf_out = addrbuf[a_addr];   
  //assign  dbuf_out = databuf[dhead];
  assign dout = databuf[dhead];
  //RAMs
  always_ff @(negedge gclk.clk) begin		//write at negedge
    if (abuf_we) addrbuf[a_addr] <= abuf_in;          
    if (reqin.s1.valid) databuf[dtail] <= dbuf_in;
  end
  
//  assign nonempty = (ahead == atail) ? ~last_read : '1;      
  always_ff @(posedge gclk.clk) begin  //output register
    aout  <= abuf_out;
    valid <= r_nonempty & re;           
  end
  
//  always_ff @(posedge gclk.clk2x)
//    dout <= dbuf_out;
  
endmodule

//tracking return information, write in clk1x (posedge), read at negedge
module retinfo_buf #(parameter bufdepth=64, parameter fullcount=58, parameter nofullflag=0)   //default depth = 64, maximum 64 references in flight
      (input  iu_clk_type gclk, input rst, 
       input  mem_ret_buf_type       din,
       input  bit                    we,          //address buffer we
       input  bit                    re,          //external read enable
       output mem_ret_buf_type       dout,
       output bit                    valid,
       output bit                    almost_full
       );
  (* syn_ramstyle = "select_ram" *)	mem_ret_buf_type	 retbuf[0:bufdepth-1];
  mem_ret_buf_type	 buf_out;  //wires

  //synthesis translate_off
  bit last_read;
  //synthesis translate_on
  
  bit [log2x(bufdepth)-1:0] head, tail;               //head/tail counters
  bit [log2x(bufdepth):0]   qcnt, qadd, next_qcnt;    //queue counter used for almost full flag generation

  bit                       r_nonempty;
  
  bit [log2x(bufdepth)-1:0] addr;               //TDM address buffer address  
  bit                       d_read;             //signals for flag generator
  
  typedef struct {
    bit                     valid;
    mem_ret_buf_type	       data;
  }retbuf_pipe_reg_type;
  
  retbuf_pipe_reg_type      rdo;             //pipeline register

  bit                       re1;
  (* syn_maxfan=4 *) bit 	re2;        //re controls for the first two stages


  always_comb begin
    //these can be mapped to a LUT6_2
    re2 = ~rdo.valid | re | (rdo.valid & rdo.data.write);
    re1 = re2 & r_nonempty; 
  end 
  
  //flag generation
  always_comb begin
    qadd = 0;
    unique case ({d_read, we})    
	//    unique case ({re1, we})
   	2'b10   : qadd = '1;    //-1
    2'b01   : qadd = 1;     //+1
   	default : ;
    endcase    
    
    //adder
   	next_qcnt = qcnt + qadd;
  end

  
  always_ff @(negedge gclk.clk) begin
    if (rst) 
      d_read <= '0; 
    else  
      d_read <= re1;          
  end
  
/*  
  always_ff @(posedge gclk.clk) begin
    if (rst) 
      r_nonempty <= '0;
    else begin
      if (we) 
        r_nonempty <= '1;
      else if (d_read) 
        r_nonempty <= (head == tail)? '0 : '1;
      else
        r_nonempty <= r_nonempty; 
    end
  end
*/  
  always_ff @(posedge gclk.clk) begin
    if (rst) begin
        qcnt <= '1;                   //-1
        almost_full <= '0;
        r_nonempty  <= '0;
    end
    else begin
		
        qcnt        <= next_qcnt;	
		almost_full <= (nofullflag==0) ? ((next_qcnt[log2x(bufdepth)-1:0] > fullcount-1 && !next_qcnt[log2x(bufdepth)]) ? '1 : '0) : '0;  

        r_nonempty  <= (&next_qcnt ==  0) ? '1 : '0;        
    end
  end
  
  //synthesis translate_off
  always_ff @(posedge gclk.clk2x) begin
    if (rst) 
      last_read <= '1;
    else begin
        if (gclk.ce && we) 
          last_read <= '0;
        else if (!gclk.ce && re1)
          last_read <= '1;
        else
          last_read <= last_read;
    end
  end
  
  property retbuf_write_chk;
    @(posedge gclk.clk) disable iff (rst)
      ((head == tail) && we |-> last_read) and (signed'(qcnt) >= -1);       
  endproperty

  property retbuf_read_chk;
    @(negedge gclk.clk) disable iff (rst)
      ((head == tail) && re1 |-> !last_read);       
  endproperty
  
  assert property(retbuf_write_chk) else $display("@%t ddr2memctrl retbuf write check failed!", $time);
  assert property(retbuf_read_chk) else $display("@%t ddr2memctrl retbuf read check failed!", $time);
  //synthesis translate_on
  
  // buffer pointer control
  always_ff @(posedge gclk.clk) begin		//tail pointer written by mem network	
    if (rst)
      tail <= '0;
    else begin
      tail <= (we) ? tail+1 : tail;
    end
  end 

  always_ff @(negedge gclk.clk) begin		//head pointer read when mem op is done
    if (rst)
      head <= '0;
    else
      head <= (re1) ? head + 1 : head;
  end
  
  //complete at ~266 MHz
  assign addr = (!gclk.ce)? head : tail;	//ram address

  
  //RAMs & 1st pipeline stage
  assign buf_out = retbuf[addr];
  always_ff @(posedge gclk.clk) begin		//write at posedge
    if (we) retbuf[addr] <= din;  
  end        

  //2nd pipeline stage
  always_ff @(negedge gclk.clk) begin  
    if (rst) 
        rdo.valid <= '0;
    else if (re2)
        rdo.valid <= r_nonempty;
    else
        rdo.valid <= rdo.valid;
      
    if (re2) 
      rdo.data <= buf_out;  
    else  
      rdo.data <= rdo.data;
  end       
  
  assign dout  = rdo.data;
  assign valid = rdo.valid;
endmodule

//one-hot arbiter, return a one hot vector
module mem_bus_arbiter #(parameter int NMEMCTRLPORT=1)(input iu_clk_type gclk, input rst, input bit en, input [(NMEMCTRLPORT*2)-1:0] port_valid, output bit [(NMEMCTRLPORT*2)-1:0] port_mask, output bit [log2x(NMEMCTRLPORT*2)-1:0] rid);
  bit [log2x(NMEMCTRLPORT*2)-1:0]  r_cur_port, v_cur_port;

  bit [log2x(NMEMCTRLPORT*2)-1:0]		ilo, ihi;	//temp result
	bit has_lo, has_hi;	

  bit [log2x(NMEMCTRLPORT*2)-1:0]   r_rid[0:2];   
 
  bit [(NMEMCTRLPORT*2)-1:0] mask;
  
  always_comb begin

  	has_lo = '0; has_hi = '0;
	 ilo = '0; ihi = '0;

	 for (int i=0;i<NMEMCTRLPORT*2;i++) begin
		//search for low		
		if (i <= r_cur_port && port_valid[i] == 1'b1 && has_lo == 1'b0) begin
			has_lo = 1'b1;
			ilo = i;
		end
		
		//search for hi
		if (i > r_cur_port && port_valid[i] == 1'b1 && has_hi == 1'b0) begin
			has_hi = 1'b1;
			ihi = i;
		end
	 end
	 
   //find next available port
	 if (has_hi) 
     v_cur_port = ihi;
   else if (has_lo)
     v_cur_port = ilo;
   else
//     v_cur_port = (r_cur_port + 1) % (NMEMCTRLPORT*2);       //RR with skip
     v_cur_port = r_cur_port;                                  //park
 
   //generate port mask
   mask = '0;   
   mask[v_cur_port] = en;   
  end  
  
  always_ff @(posedge gclk.clk) begin
    if (rst) begin 
      r_cur_port <= '0; 
      port_mask <= '0;
    end
    else begin
        if (en) r_cur_port <= v_cur_port; else r_cur_port <= r_cur_port;
        //if (en) port_mask <= mask; else port_mask <= port_mask;
        port_mask <= mask;
    end
    
    r_rid[0] <= r_cur_port;
    r_rid[1] <= r_rid[0];
    r_rid[2] <= r_rid[1];
    rid   <= r_rid[2];

  end  
endmodule

//memory bus one-hot muxes
module mem_bus_mux #(parameter addr2x =0, parameter int NMEMCTRLPORT=1) (input iu_clk_type gclk, input rst,
                   input imem_req_addr_buf_type   imem_aout[0:NMEMCTRLPORT-1],
                   input dmem_req_addr_buf_type   dmem_aout[0:NMEMCTRLPORT-1],
                   input imem_req_data_buf_type   imem_dout[0:NMEMCTRLPORT-1],
                   input dmem_req_data_buf_type   dmem_dout[0:NMEMCTRLPORT-1],
                   input  bit                     en,
                   input bit [2*NMEMCTRLPORT-1:0] port_valid,
                   input bit [2*NMEMCTRLPORT-1:0] port_mask,
                   output imem_req_addr_buf_type af_in,       //address fifo input data
                   output imem_req_data_buf_type df_in,       //data fifo input data
                   output bit                    af_valid,    //address fifo is valid
                   output bit                    luterr       //lutram error
);
       localparam int halfaddr2x = halfbits($bits(imem_req_addr_buf_type)-1);
       //one-hot mux signals and registers, data
       imem_req_addr_buf_type   v_addr_mux_output, r_addr_mux_output;
       imem_req_data_buf_type   v_data_mux_output, r_data_mux_output;
       bit v_valid, r_valid;
       
       bit v_we, r_we;      //signals for addr2x mode
       
    //   bit r_en;
       
       bit [halfaddr2x-1:0]  v_addr_mux_2x, r_addr_mux_2x, r_imem_aout[0:NMEMCTRLPORT-1], r_dmem_aout[0:NMEMCTRLPORT-1], l_addr_mux_2x;
       
       //synplify compiler bug work around
       `ifdef STRUCTBUGWKRD
       typedef bit [$bits(imem_req_addr_buf_type)-1:0] 	 imem_aout_dt[0:NMEMCTRLPORT-1];
       typedef bit [$bits(dmem_req_addr_buf_type)-1:0] 	 dmem_aout_dt[0:NMEMCTRLPORT-1];
       typedef bit [$bits(imem_req_data_buf_type)-1:0]   imem_dout_dt[0:NMEMCTRLPORT-1];
       typedef bit [$bits(dmem_req_data_buf_type)-1:0]   dmem_dout_dt[0:NMEMCTRLPORT-1];
	   bit  [$bits(imem_req_addr_buf_type)-1:0]   		imem_aout_1D[0:NMEMCTRLPORT-1];       
	   bit 	[$bits(dmem_req_addr_buf_type)-1:0]			dmem_aout_1D[0:NMEMCTRLPORT-1];
	   bit  [$bits(imem_req_data_buf_type)-1:0]   		imem_dout_1D[0:NMEMCTRLPORT-1];       
	   bit 	[$bits(dmem_req_data_buf_type)-1:0]			dmem_dout_1D[0:NMEMCTRLPORT-1];
	   assign imem_aout_1D = imem_aout_dt'(imem_aout);
	   assign dmem_aout_1D = dmem_aout_dt'(dmem_aout);
	   assign imem_dout_1D = imem_dout_dt'(imem_dout);
	   assign dmem_dout_1D = dmem_dout_dt'(dmem_dout);
	   `endif
       
       //one-hot muxes
       always_comb begin
         //address muxes @ clk
         if (addr2x == 0) begin
           for (int i=0;i<$bits(imem_req_addr_buf_type);i++) begin
            v_addr_mux_output[i] = '0;
          
            for (int j=0;j<NMEMCTRLPORT;j++) begin
            `ifndef STRUCTBUGWKRD
               v_addr_mux_output[i]= v_addr_mux_output[i] | (imem_aout[j][i] & port_mask[2*j]) | (dmem_aout[j][i] & port_mask[2*j+1]);
            `else
               v_addr_mux_output[i]= v_addr_mux_output[i] | (imem_aout_1D[j][i] & port_mask[2*j]) | (dmem_aout_1D[j][i] & port_mask[2*j+1]);
            `endif
            end
           end
         end
         else begin                      
            v_addr_mux_2x = '0;
            v_we    = '0;
            for (int j=0; j<NMEMCTRLPORT;j++) begin
              v_we = v_we | (imem_aout[j].we & port_mask[2*j]) | (dmem_aout[j].we & port_mask[2*j+1]);
              for (int i=0;i<halfaddr2x;i++) begin
                     v_addr_mux_2x[i]= v_addr_mux_2x[i] | (r_imem_aout[j][i] & port_mask[2*j]) | (r_dmem_aout[j][i] & port_mask[2*j+1]);                 
              end
            end
         end
         
         //data muxes @clk2x           
         for (int i=0;i<$bits(imem_req_data_buf_type);i++) begin
          v_data_mux_output[i] = '0;
          
          for (int j=0;j<NMEMCTRLPORT;j++) begin
			`ifndef STRUCTBUGWKRD	
             v_data_mux_output[i]= v_data_mux_output[i] | (imem_dout[j][i] & port_mask[2*j]) | (dmem_dout[j][i] & port_mask[2*j+1]);
            `else
            v_data_mux_output[i]= v_data_mux_output[i] | (imem_dout_1D[j][i] & port_mask[2*j]) | (dmem_dout_1D[j][i] & port_mask[2*j+1]);
            `endif
          end
         end

         //generate address fifo valid
         v_valid = 0; 
         for (int i=0;i<2*NMEMCTRLPORT;i++) begin
           v_valid = v_valid | (port_valid[i] & port_mask[i]);           
         end
       end
       
       //muxes @ clk
       always_ff @(posedge gclk.clk) begin
//		  r_en				<= en;
          r_valid           <= v_valid;           
           
          if (addr2x)
            r_we <= v_we;
            
          //if protect lutram, add another pipeline stage for parity checking
          luterr <= (LUTRAMPROT) ? ^r_addr_mux_output : '0;
       end
      
      generate 
        if (addr2x) begin
          always_latch begin
            if (gclk.clk)
              l_addr_mux_2x <= r_addr_mux_2x;
          end
  
//          always_ff @(negedge gclk.clk)
//            l_addr_mux_2x <= r_addr_mux_2x;
                
          always_comb begin
            for (int i=0;i<halfaddr2x;i++) begin
               r_addr_mux_output[2*i] = l_addr_mux_2x[i];
  
               if (i*2+1 < $bits(imem_req_addr_buf_type))
                 r_addr_mux_output[2*i+1] = r_addr_mux_2x[i];
            end
            
            //used by 
             r_addr_mux_output.we = r_we; 
          end
        end
        else begin
          always_ff @(posedge gclk.clk)
            r_addr_mux_output <= v_addr_mux_output;                 //address mux
        end
     endgenerate
     
       //clk2x data mux
       always_ff @(posedge gclk.clk2x) begin
         if (addr2x==1) begin
          for (int i=0;i<halfbits($bits(imem_req_addr_buf_type));i++) begin
            for (int j=0;j<NMEMCTRLPORT;j++) begin
                if (!gclk.ce) begin
                  r_imem_aout[j][i] <= imem_aout[j][2*i];           //reduce global wires
                  r_dmem_aout[j][i] <= dmem_aout[j][2*i];
                end
                else begin
                  r_imem_aout[j][i] <= (i*2+1 == $bits(imem_req_addr_buf_type)) ? '0 : imem_aout[j][2*i+1];
                  r_dmem_aout[j][i] <= (i*2+1 == $bits(imem_req_addr_buf_type)) ? '0 : dmem_aout[j][2*i+1];
                end
            end
          end

          r_addr_mux_2x <= v_addr_mux_2x;          
         end

         r_data_mux_output <= v_data_mux_output;
         df_in             <= r_data_mux_output;
       end
       
       assign af_in    = r_addr_mux_output;
       assign af_valid = r_valid;
endmodule



//tracking return information, write in clk1x (posedge), read at negedge
module retinfo_buf_sdr #(parameter bufdepth=64, parameter fullcount=58, parameter nofullflag=0)   //default depth = 64, maximum 64 references in flight
      (input  iu_clk_type gclk, input rst, 
       input  mem_ret_buf_type       din,
       input  bit                    we,          //address buffer we
       input  bit                    re,          //external read enable
       output mem_ret_buf_type       dout,
       output bit                    valid,
       output bit                    almost_full
       );
  (* syn_ramstyle = "select_ram" *)	mem_ret_buf_type	 retbuf[0:bufdepth-1];
  mem_ret_buf_type	 buf_out;  //wires

  //synthesis translate_off
  bit last_read;
  //synthesis translate_on
  
  bit [log2x(bufdepth)-1:0] head, tail;               //head/tail counters
  bit [log2x(bufdepth):0]   qcnt, qadd, next_qcnt;    //queue counter used for almost full flag generation

  bit                       r_nonempty;
  
  bit [log2x(bufdepth)-1:0] addr;               //TDM address buffer address  
  bit                       d_read;             //signals for flag generator
  
  typedef struct {
    bit                     valid;
    mem_ret_buf_type	       data;
  }retbuf_pipe_reg_type;
  
  retbuf_pipe_reg_type      rdo;             //pipeline register

  bit                       re1;
  (* syn_maxfan=4 *) bit 	re2;        //re controls for the first two stages


  always_comb begin
    //these can be mapped to a LUT6_2
    re2 = ~rdo.valid | re | (rdo.valid & rdo.data.write);
    re1 = re2 & r_nonempty; 
  end 
  
  //flag generation
  always_comb begin
    qadd = 0;
    unique case ({d_read, we})    
	//    unique case ({re1, we})
   	2'b10   : qadd = '1;    //-1
    2'b01   : qadd = 1;     //+1
   	default : ;
    endcase    
    
    //adder
   	next_qcnt = qcnt + qadd;
  end

    
  always_ff @(posedge gclk.clk) begin
    if (rst) begin
        qcnt <= '1;                   //-1
        almost_full <= '0;
        r_nonempty  <= '0;
    end
    else begin		
        qcnt        <= next_qcnt;	
		    almost_full <= (nofullflag==0) ? ((next_qcnt[log2x(bufdepth)-1:0] > fullcount-1 && !next_qcnt[log2x(bufdepth)]) ? '1 : '0) : '0;  

        r_nonempty  <= (&next_qcnt ==  0) ? '1 : '0;        
    end
  end
  
  //synthesis translate_off
  always_ff @(posedge gclk.clk2x) begin
    if (rst) 
      last_read <= '1;
    else begin
        if (gclk.ce && we) 
          last_read <= '0;
        else if (!gclk.ce && re1)
          last_read <= '1;
        else
          last_read <= last_read;
    end
  end
  
  property retbuf_write_chk;
    @(posedge gclk.clk) disable iff (rst)
      ((head == tail) && we |-> last_read) and (signed'(qcnt) >= -1);       
  endproperty

  property retbuf_read_chk;
    @(negedge gclk.clk) disable iff (rst)
      ((head == tail) && re1 |-> !last_read);       
  endproperty
  
  assert property(retbuf_write_chk) else $display("ddr2memctrl retbuf write check failed!");
  assert property(retbuf_read_chk) else $display("ddr2memctrl retbuf read check failed!");
  //synthesis translate_on
  
  // buffer pointer control
  always_ff @(posedge gclk.clk) begin		//
    if (rst) begin
      tail <= '0;
      head <= '0;      
    end
    else begin
      tail <= (we) ? tail+1 : tail;
      head <= (re1) ? head + 1 : head;
    end
  end 

  
  //RAMs & 1st pipeline stage
  assign buf_out = retbuf[head];
  always_ff @(posedge gclk.clk) begin		//write at posedge
    if (we) retbuf[tail] <= din;  
  end        

  //2nd pipeline stage
  always_ff @(posedge gclk.clk) begin  
    if (rst) 
        rdo.valid <= '0;
    else if (re2)
        rdo.valid <= r_nonempty;
    else
        rdo.valid <= rdo.valid;
      
    if (re2) 
      rdo.data <= buf_out;  
    else  
      rdo.data <= rdo.data;
  end       
  
  assign dout  = rdo.data;
  assign valid = rdo.valid;
endmodule
