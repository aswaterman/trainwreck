//---------------------------------------------------------------------------   
// File:        ddr2memctrl.sv
// Author:      Zhangxi Tan
// Description: DDR2 memory controller, support MIG, BEE3
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

                            
module dramctrl(input iu_clk_type gclk, input rst,
                input mem_ctrl_in_type                imem_in[0:NMEMCTRLPORT-1],
                input mem_ctrl_in_type                dmem_in[0:NMEMCTRLPORT-1],
                output mem_ctrl_out_type              imem_out[0:NMEMCTRLPORT-1],
                output mem_ctrl_out_type              dmem_out[0:NMEMCTRLPORT-1],
                mem_controller_interface.cpu          mcif,
		            output bit                            luterr);      
       
       bit [2*NMEMCTRLPORT-1:0]  port_nonempty;                    //request port has valid data
       bit [2*NMEMCTRLPORT-1:0]  port_valid;                       //output port data is valid

       (* syn_maxfan = 16 *) bit [2*NMEMCTRLPORT-1:0]  port_mask;    
       bit [2*NMEMCTRLPORT-1:0]                        d_port_mask;//used for data muxing
       
       
       bit  retbuf_full;                                           //ret buffer is (almost) full
      
       //input register signals
       mem_ctrl_in_type  r_imem_in[0:NMEMCTRLPORT-1];
       mem_ctrl_in_type  r_dmem_in[0:NMEMCTRLPORT-1]; 
      
       //mem network fifo output
       imem_req_addr_buf_type  imem_aout[0:NMEMCTRLPORT-1];
       dmem_req_addr_buf_type  dmem_aout[0:NMEMCTRLPORT-1];
       imem_req_data_buf_type  imem_dout[0:NMEMCTRLPORT-1];
       dmem_req_data_buf_type  dmem_dout[0:NMEMCTRLPORT-1];
       
       //retbuf signals
       mem_ret_buf_type                      retbuf_din;
       bit [log2x(NMEMCTRLPORT*2)-1:0]       retbuf_din_rid;       //requestor ID

       mem_ret_buf_type                      retbuf_dout;          //wire
       bit                                   retbuf_valid;         //wire
              

       (* syn_maxfan = 8 *)mem_ret_buf_type  r_retbuf_dout;        //pipeline register
       bit                                   r_retbuf_valid;       //piepline register
       
       bit                                   r_rb_valid;

       //instantiate memory controller interface 
       //mem_controller_interface mcif(gclk);
              
       //one-hot mux signals and registers
       imem_req_addr_buf_type   af_in;      //memory controller address fifo data input
       imem_req_data_buf_type   df_in;      //memory controller data fifo data input
       bit                      af_valid;   //address fifo is valid       
       
       //memory controller user logic control signals
       bit                         wb_we;        //write buffer we
       (* syn_maxfan = 16 *) bit   af_we;        //address fifo we       
       (* syn_maxfan = 16 *) bit   mem_bus_en;   //memory bus enable (can write to fifo)
             
       bit [2*NMEMCTRLPORT-1:0]   hasret;

       //signals for mem network buffer control signals
       bit [2*NMEMCTRLPORT-1:0]   mem_buf_re;

       //synthesis translate_off
       longint  read_issued, read_completed;
       //synthesis translate_on

            
       //input registers
       always_ff @(posedge gclk.clk) begin
        r_imem_in <= imem_in;
        r_dmem_in <= dmem_in;
       end
       
       //mem network buffer control
       always_ff @(posedge gclk.clk) begin
          mem_bus_en    <=  ~mcif.af_full & ~mcif.wb_full & ~retbuf_full;
       end
       
       always_comb begin
         af_we = af_valid;    //rely on flow control and several extra buffer spaces in mem controller interface 
                          
         for (int i=0;i<2*NMEMCTRLPORT;i++) begin
            mem_buf_re[i] = port_nonempty[i] & port_mask[i] & mem_bus_en;
         end         
         
         wb_we = af_valid & af_in.we;
         
         mcif.af_we = af_we;
         mcif.wb_we = wb_we;       
         
         mcif.af_in = af_in;
         mcif.df_in = df_in;
       end

       //retbuf data input
       always_comb begin
        retbuf_din.tid       = af_in.tid;
        retbuf_din.ret_index = af_in.addr[ICACHEINDEXMSB_IU:ICACHEINDEXLSB_MEM];
        retbuf_din.write     = af_in.we;
        retbuf_din.parity    = (LUTRAMPROT) ? retbuf_din.write ^ retbuf_din.tid ^ retbuf_din.rid ^ retbuf_din.ret_index : '0;          
        
        retbuf_din.rid       = retbuf_din_rid;
       end
       
       //return result
       always_ff @(posedge gclk.clk2x) begin     
         for (int i=0;i<NMEMCTRLPORT;i++) begin
           imem_out[i].res.data.data.I <= mcif.rb_data;       
           dmem_out[i].res.data.data.D <= mcif.rb_data;
         
           //Todo: if we will support ECC
           imem_out[i].res.data.ecc_parity.I <= '0;
           imem_out[i].res.data.ecc_parity.D <= '0;
           dmem_out[i].res.data.ecc_parity.I <= '0;
           dmem_out[i].res.data.ecc_parity.D <= '0;
         
                  
           imem_out[i].res.data.ecc_error <= cache_data_error_none;
           dmem_out[i].res.data.ecc_error <= cache_data_error_none;
        end
       end
       
       //output pipeline
       always_comb begin
        if (NMEMCTRLPORT > 1) begin
          for (int i=0;i<NMEMCTRLPORT;i++) begin          
            hasret[2*i]   = (r_retbuf_dout.rid[0] == 1'b0 && r_retbuf_dout.rid[1 +: log2x(NMEMCTRLPORT)] == i) ? r_retbuf_valid : '0;
            hasret[2*i+1] = (r_retbuf_dout.rid[0] == 1'b1 && r_retbuf_dout.rid[1 +: log2x(NMEMCTRLPORT)] == i) ? r_retbuf_valid : '0;          
          end
        end
        else begin
            hasret[0] = (r_retbuf_dout.rid[0] == 1'b0) ? r_retbuf_valid : '0;
            hasret[1] = (r_retbuf_dout.rid[0] == 1'b1) ? r_retbuf_valid : '0;                   
        end          
       end
       
       always_ff @(posedge gclk.clk) begin
         r_retbuf_dout  <= retbuf_dout;
         r_retbuf_valid <= retbuf_valid;      
         
         mcif.rb_re <= retbuf_valid & ~retbuf_dout.write & ~mcif.rb_empty;                                   
       end
       
       always_ff @(negedge gclk.clk)
        r_rb_valid <= ~mcif.rb_empty;
       
       always_ff @(posedge gclk.clk) begin  
        for (int i=0;i<NMEMCTRLPORT;i++) begin
          imem_out[i].res.tid         <= r_retbuf_dout.tid;
          imem_out[i].res.ret_index.I <= {r_retbuf_dout.ret_index, 1'b0};
          dmem_out[i].res.tid         <= r_retbuf_dout.tid;
          dmem_out[i].res.ret_index.D <= {r_retbuf_dout.ret_index, 1'b0};					
          
          
          imem_out[i].res.valid   <= hasret[2*i] ? r_rb_valid & mcif.rb_re : '0;     //fine to use mcif.rb_empty, because of 1 cycle delay
          imem_out[i].res.done    <= hasret[2*i] ? r_rb_valid & mcif.rb_re : '0;     //no write back at instruction
           
          dmem_out[i].res.valid   <= hasret[2*i+1] ? r_rb_valid & mcif.rb_re : '0;
          dmem_out[i].res.done    <= hasret[2*i+1] ? (r_rb_valid & mcif.rb_re) | r_retbuf_dout.write : '0;
          
   
           //command fifo RE control
           imem_out[i].ctrl.cmd_re <= unsigned'({mem_buf_re[2*i], 1'b0});
           dmem_out[i].ctrl.cmd_re <= unsigned'({mem_buf_re[2*i+1], 1'b0});          
        end        
       end
       
       //memory controller interface assertion
       //synthesis translate_off
        always_ff @(posedge gclk.clk) begin
          if (rst) 
              read_issued <= 0; 
          else if (af_valid && !wb_we)
              read_issued <= read_issued + 1;
        end
        
        always_ff @(posedge gclk.clk2x) begin
           if (rst)
            read_completed <= 0;
           else if (mcif.rb_re & ~mcif.rb_empty)
            read_completed <= read_completed + 1 ;
        end

                
 //     assert (read_completed <= 2*read_issued) else $display ("%t more reads completed near the memory controller than expected", $time);
        property guard_mem_read;
         @(posedge(gclk.clk2x))
          disable iff (rst)
            read_completed <= 2*read_issued;
        endproperty

        assert property (guard_mem_read) else $display ("%t more reads completed near the memory controller than expected", $time);
       //synthesis translate_on

       
		   //generate address & data buffer           
		   generate 		    
		    genvar i;
		    
		    for (i=0;i<NMEMCTRLPORT;i++) begin
          imem_network_buf imembuf(.gclk,
                                   .rst,
                                   .reqin(r_imem_in[i]),
                                   .re(mem_buf_re[2*i]),
                                   .aout(imem_aout[i]),       //address out
                                   .dout(imem_dout[i]),       //data out
                                   .valid(port_valid[2*i]),
                                   .nonempty(port_nonempty[2*i])
                                   );
                                 
          dmem_network_buf dmembuf(.gclk,
                                   .rst,
                                   .reqin(r_dmem_in[i]),
                                   .re(mem_buf_re[2*i+1]),
                                   .aout(dmem_aout[i]),       //address out
                                   .dout(dmem_dout[i]),       //data out
                                   .valid(port_valid[2*i+1]),
                                   .nonempty(port_nonempty[2*i+1])
                                   );                      
		    end    		    		    
		    
		   endgenerate
		   
		   //instantiate return info fifo
       retinfo_buf retfifo(
             .gclk, 
             .rst, 
             .din(retbuf_din),
             .we(af_we),          
             .re(~mcif.rb_empty & mcif.rb_re),          
             .dout(retbuf_dout),
             .valid(retbuf_valid),
             .almost_full(retbuf_full)
              );
       
       always_ff @(posedge gclk.clk) 
        d_port_mask <= port_mask; 

       //instantiate arbiter
       mem_bus_arbiter bus_arbiter(.gclk, 
                               .rst,
                               .en(mem_bus_en),     
                               .port_valid(port_nonempty),
                               .port_mask,                //request mask
                               .rid(retbuf_din_rid));		   //request id
                               
      //instantiate data path mux
      mem_bus_mux   bus_mux(.*, 
                            .en(mem_bus_en),
                            .port_mask(d_port_mask));      
endmodule		         		              
  
