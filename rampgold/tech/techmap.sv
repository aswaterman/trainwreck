//---------------------------------------------------------------------------   
// File:        techmap.v
// Author:      Zhangxi Tan
// Description: Technology dependent mapping and logic 		
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libiu::*;
import libfp::*;
import libcache::*;
import libconf::*;
import libtech::*;
import libxalu::*;
import libdebug::*;
import libmmu::*;
import libeth::*;
`else
`include "../cpu/libiu.sv"
`include "../cpu/libmmu.sv"
`include "../cpu/libcache.sv"
`include "../cpu/libxalu.sv"
`include "../eth/libeth.sv"
`endif

`ifdef	SYNPD200912
`define SYNP94
`endif

module clk_inb #(
`ifndef SYNP94
  parameter fpgatech_type fpgatech = xilinx_virtex5,
`else	
  parameter fpgatech = 1,
`endif	
  parameter differential=1) (input bit clk_n, input bit clk_p, output bit clk);

  generate
    case (fpgatech)
      default: begin 
           if (differential)
              IBUFGDS clkin_buf(.O(clk), .I(clk_p), .IB(clk_n));
           else 
              IBUFG clkin_buf(.O(clk), .I(clk_p));           
          end
    endcase
  endgenerate
  
endmodule

module gated_clkbuf #(
`ifndef SYNP94
  parameter fpgatech_type fpgatech = xilinx_virtex5,
`else	
  parameter fpgatech = 1,
`endif	
  parameter disablehigh=1) (input bit clk_in, input bit clk_ce, output bit clk_out);

  generate
    case (fpgatech)
      default: begin 
           if (disablehigh)
              BUFGCE_1 clkbuf_ce(.O(clk_out), .I(clk_in), .CE(clk_ce));
           else 
              BUFGCE clkbuf_ce(.O(clk_out), .I(clk_in), .CE(clk_ce));           
          end
    endcase
  endgenerate
  
endmodule


module cpu_clkgen #(
`ifndef SYNP94
	parameter fpgatech_type fpgatech = xilinx_virtex5,
`else	
	parameter fpgatech = 1,
`endif	
	parameter CLKMUL = 2.0,
	parameter CLKDIV = 2.0,
	parameter CLKIN_PERIOD = 10.0
	)
	(input bit clkin, input bit rstin, output bit clk, output bit clk2x, output bit ce, output bit locked);
	
	generate
		case (fpgatech)
		default: begin 
    		        xcv5_cpu_clkgen #(.CLKMUL(CLKMUL), .CLKDIV(CLKDIV), .CLKIN_PERIOD(CLKIN_PERIOD)) xcv5_gen_clk(.*);
		        end
		endcase
	endgenerate
endmodule 

module dram_clkgen #(
`ifndef SYNP94
  parameter fpgatech_type fpgatech = xilinx_virtex5,
`else	
  parameter fpgatech = 1,
`endif	
  parameter CLKMUL = 8.0,
  parameter CLKDIV = 3.0,
  parameter CLKIN_PERIOD = 10.0,
  parameter CLKDIV200 = 3.0,
  parameter BOARDSEL = 1            //select ML505
  )
  (input bit clkin, input bit rstin, input bit dramrst, input bit clk200, output dram_clk_type ram_clk);
  
  generate
    case (fpgatech)
    default: begin 
                case (BOARDSEL)
                0:  xcv5_dram_clkgen_bee3 #(.CLKMUL(CLKMUL), .CLKDIV(CLKDIV), .CLKIN_PERIOD(CLKIN_PERIOD), .PLLDIV(DRAM_PLLDIV), .BOARDSEL(BOARDSEL)) xcv5_gen_dram_clk_bee3(.*);
                default :  xcv5_dram_clkgen_mig #(.CLKMUL(CLKMUL), .CLKDIV(CLKDIV),.CLKDIV200(CLKDIV200),.CLKIN_PERIOD(CLKIN_PERIOD)) xcv5_gen_dram_clk_mig(.*);
                endcase
             end
    endcase
  endgenerate
endmodule 

module high_fanout_buf #(		
						`ifndef SYNP94
						parameter fpgatech_type fpgatech = xilinx_virtex5
						`else
						parameter fpgatech = 1
						`endif
	) 
	(input bit gin, output bit gout);
	generate
		case (fpgatech)
		default: BUFG xcv5_fanout_buf(.O(gout), .I(gin));
		endcase
	endgenerate	
endmodule

module alu_adder_logic #(
	`ifndef SYNP94
	parameter fpgatech_type fpgatech = xilinx_virtex5
	`else
	parameter fpgatech = 1
	`endif
) 				//SETHI will be handled by a ALU pass
(input iu_clk_type gclk, input bit rst, 
 input bit valid, 
 input alu_dsp_in_type alu_data, 
 output alu_dsp_out_type alu_res,
 output bit [31:0]  raw_alu_res);
	generate 
		case(fpgatech)
		default: xcv5_alu_adder_logic simple_alu(.*); 
		endcase
	endgenerate
endmodule

module alu_mul_shf #(
	`ifndef SYNP94
	parameter fpgatech_type fpgatech = xilinx_virtex5
	`else
	parameter fpgatech = 1
	`endif
	) 				    //multiplier and shifter
	
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type din,
 input  bit               en,     //input valid
 output xalu_fu_out_type  dout,
 output bit               re   
); 
	generate 
		case(fpgatech)
		default: xcv5_alu_mul_shf mul_shf(.*); 
		endcase
	endgenerate
endmodule

module alu_mul_shf_fast #(
  `ifndef SYNP94
  parameter fpgatech_type fpgatech = xilinx_virtex5
  `else
  parameter fpgatech = 1
  `endif
  ) 				    //multiplier and shifter
  
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type din,
 output xalu_fu_out_type  dout 
); 
  generate 
    case(fpgatech)
    default: xcv5_alu_mul_shf_fast mul_shf(.*); 
    endcase
  endgenerate
endmodule


module alu_div #(
				`ifndef SYNP94
				 parameter fpgatech_type fpgatech = xilinx_virtex5
				 `else
         parameter fpgatech = 1
         `endif
         )
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type  din,
 input  bit                en,     //input valid
 input  y_reg_type         yin,    //y input
 output xalu_fu_out_type   dout,
 output bit                re      //input fifo RE control   
); 
  generate
    case(fpgatech)
      default: xcv5_alu_div idiv(.*);
    endcase
  endgenerate
endmodule

module alu_div_2x #(
				 `ifndef SYNP94
				 parameter fpgatech_type fpgatech = xilinx_virtex5
				 `else
         parameter fpgatech = 1
         `endif
         )
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type  din,
 input  bit                en,     //input valid
 input  y_reg_type         yin,    //y input
 output xalu_fu_out_type   dout,
 output bit                re      //input fifo RE control   
); 
  generate
    case(fpgatech)
      default: xcv5_alu_div_2x idiv(.*);
    endcase
  endgenerate
endmodule


//double clocked main register file, by default protectin = software arity
`ifndef SYNP94
module regfile	#( 
		  parameter int protection = 1, 
		  parameter int nthread = 64,
		  parameter fpgatech_type fpgatech = xilinx_virtex5) 
`else		  
module regfile	#(parameter fpgatech = 1, 
		  parameter protection = 1, 
		  parameter nthread = 64) 		  
`endif		  
		(input iu_clk_type gclk, input bit rst, input regfile_read_in_type rfi, output regfile_read_out_type rfo, input regfile_commit_type rfc);
	generate 
		case(fpgatech)
		default: xcv5_regfile  mt_regfile(.*); 
		endcase
	endgenerate
endmodule

//double clocked fp register file, by default protectin = software arity
`ifndef SYNP94
module fpregfile	#(
		  parameter int protection = 1, 
		  parameter int nthread = 64,
		  parameter fpgatech_type fpgatech = xilinx_virtex5) 
`else		  
module fpregfile	#(parameter fpgatech = 1, 
		  parameter protection = 1, 
		  parameter nthread = 64) 		  
`endif		  
		(input iu_clk_type gclk, input bit rst, input fpregfile_read_in_type rfi, output fpregfile_read_out_type rfo, input fpregfile_commit_type rfc);
	generate 
		case(fpgatech)
		default: xcv5_fpregfile  mt_fpregfile(.*); 
		endcase
	endgenerate
endmodule

//icache ram
`ifndef SYNP94
module icache_ram #( 
		    parameter int tagprot  = 1,		//tags are protected with parity
		    parameter int dataprot = 2,		//data are protected with ecc		    		    
        parameter int read2x   = 0,  //double clocked write back
        parameter int write2x  = 0,  //double clocked refill		    
		    parameter NONECCDRAM = "TRUE",	//non-ECC dram
		    
		    parameter ECCSCRUB   = "FALSE",
		    parameter fpgatech_type fpgatech= xilinx_virtex5
		   )		//icache size in 36kb blocks
`else		   
module icache_ram #(parameter fpgatech= 1, 
		    parameter tagprot  = 1,		 //tags are protected with parity
		    parameter dataprot = 2,		 //data are protected with ecc		    
        parameter read2x   = 0,   //support double clocked write back
        parameter write2x  = 0,   //double clocked refill		    
		    parameter NONECCDRAM = "TRUE",	//non-ECC dram
		    parameter ECCSCRUB   = "FALSE"
		   )		//icache size in 36kb blocks
`endif
	(input iu_clk_type gclk, input bit rst,
	 input  cache_ram_in_type	 iu_in,		//iu read/write
	 output cache_ram_out_type	iu_out,
	 input  cache_ram_in_type	 mem_in,		//mem read/write
	 output cache_ram_out_type	mem_out	 
	);
	generate
		case(fpgatech)
		default: xcv5_icache_ram #(.tagprot(tagprot),	.dataprot(dataprot), .read2x(read2x), .write2x(write2x), .NONECCDRAM(NONECCDRAM),.ECCSCRUB(ECCSCRUB)) ic_ram(.*); 
		endcase
	endgenerate
endmodule

//dcache ram
`ifndef SYNP94
module dcache_ram #(
		    parameter int tagprot  = 1,		//tags are protected with parity
		    parameter int dataprot = 2,		//data are protected with ecc
	      parameter int read2x   = 0,  //double clocked write back
    	   parameter int write2x  = 0,  //double clocked refill		    
        parameter NONECCDRAM = "FALSE", 
		    parameter ECCSCRUB = "FALSE",
			parameter fpgatech_type fpgatech= xilinx_virtex5		    
		   )		//dcache size in 36kb blocks
`else		   
module dcache_ram #(
			  parameter fpgatech = 1,
		    parameter tagprot  = 1,		//tags are protected with parity
		    parameter dataprot = 2,		//data are protected with ecc
        parameter read2x   = 0,  //double clocked write back
        parameter write2x  = 0,  //double clocked refill		    		    
        parameter NONECCDRAM = "FALSE",        
		    parameter ECCSCRUB = "FALSE"		    
		   )		//dcache size in 36kb blocks
`endif
	(input iu_clk_type gclk, input bit rst,
	 input  cache_ram_in_type	 iu_in,		 //iu read/write
	 output cache_ram_out_type	iu_out,
	 input  cache_ram_in_type	 mem_in,		//mem read/write
	 output cache_ram_out_type	mem_out	 
	);
	generate
		case(fpgatech)
		default: xcv5_dcache_ram #(.tagprot(tagprot), .read2x(read2x), .write2x(write2x), .dataprot(dataprot), .NONECCDRAM(NONECCDRAM), .ECCSCRUB(ECCSCRUB)) dc_ram(.*); 
		endcase
	endgenerate
endmodule

//128-bit wide blockram memory
`ifndef SYNP94
module bram_memory_128 #(
		    	parameter int dataprot = 2,	//data are protected with ecc
				 parameter int ADDRMSB  = 8,		//512 deep by default  
				 parameter fpgatech_type fpgatech= xilinx_virtex5
		   )
`else		   		
module bram_memory_128 #(parameter fpgatech=1, 
		    	parameter dataprot = 2,	//data are protected with ecc
				 parameter ADDRMSB  = 8		//512 deep by default  
		   )		
`endif
		(input iu_clk_type gclk, input bit rst,
		 input bit [ADDRMSB:0] 	addr,
		 input bit 		we,		//write enable
		 input cache_data_type 	din,		//data in
		 output cache_data_type dout		//dataa out
    );
	generate
		case(fpgatech)
		default : xcv5_bram_memory_128 #(.dataprot(dataprot),.ADDRMSB(ADDRMSB)) bram_mem(.*);
		endcase
	endgenerate
endmodule 

//32-bit wide blockram ROM
`ifndef SYNP94
module bram_rom_32 #(
				 parameter int ADDRMSB  = 12,		//8K deep by default  
				 parameter fpgatech_type fpgatech= xilinx_virtex5
		   )
`else		   		
module bram_rom_32 #(parameter fpgatech=1, 
			 parameter ADDRMSB  = 12		//8K deep by default  
		   )		
`endif
		(input iu_clk_type gclk, input bit rst,
		 input bit [ADDRMSB:0] 	addr,
		 output bit [31:0] 	dout		//dataa out
    );
	generate
		case(fpgatech)
		default : xcv5_bram_rom_128 #(.ADDRMSB(ADDRMSB)) bram_mem(.*);
		endcase
	endgenerate
endmodule 

module debug_dma_buf #(
		`ifndef SYNP94
		parameter fpgatech_type fpgatech = xilinx_virtex5
		`else
         parameter fpgatech = 1
        `endif
        )
		( input iu_clk_type gclk, 
		  input bit eth_rx_clk,
		  input bit eth_tx_clk,
		  input bit rst,
			input  debug_dma_read_buffer_in_type   eth_rb_in,
			input  debug_dma_write_buffer_in_type  eth_wb_in,
			output debug_dma_write_buffer_out_type eth_wb_out,
			input  debug_dma_read_buffer_in_type   dma_rb_in,
      output debug_dma_read_buffer_out_type  dma_rb_out,
      input  debug_dma_write_buffer_in_type  dma_wb_in,
			//error report
			output bit dberr,
			output bit sberr
		);
		
	generate
		case(fpgatech)
		default : xcv5_debug_dma_buf dma_buf(.*);
		endcase
	endgenerate
endmodule

module simdma_init_rom #(
		`ifndef SYNP94
		parameter fpgatech_type fpgatech = xilinx_virtex5
		`else
         parameter fpgatech = 1
        `endif
        )
		(input iu_clk_type gclk, input bit rst,
					   input  bit [15:0]	raddr,
					   output bit [31:0]	dout);
					   
	generate
		case(fpgatech)
		default : xcv5_simdma_init_rom init_rom(.*);
		endcase
	endgenerate		
endmodule	

module dtlbram #(parameter fpgatech_type fpgatech = xilinx_virtex5, parameter ECC = "TRUE", parameter ECCSCRUB = "FALSE", parameter DOREG = 1) (input iu_clk_type 		gclk, input bit			rst,
                                                                        input mmu_dtlbram_addr_type raddr,
                                                                        input mmu_dtlbram_addr_type waddr,
                                                                        input bit                   we,                                                           
                                                                        input mmu_dtlbram_data_type wdata,
                                                                        output mmu_dtlbram_data_type     rdata,
                                                                        output bit sberr,
                                                                        output bit dberr); 
         generate 
           case(fpgatech)
             default: xcv5_dtlbram #(.ECC(ECC), .ECCSCRUB(ECCSCRUB), .DOREG(DOREG)) tlbram(.*);
           endcase
         endgenerate                                                                                                                                      
endmodule

module itlbram #(parameter fpgatech_type fpgatech = xilinx_virtex5, parameter ECC = "TRUE", parameter ECCSCRUB = "FALSE") (input iu_clk_type 		gclk, input bit			rst,
                                                                        input mmu_itlbram_addr_type raddr,
                                                                        input mmu_itlbram_addr_type waddr,
                                                                        input bit                   we,                                                           
                                                                        input mmu_itlbram_data_type wdata,
                                                                        output mmu_itlbram_data_type     rdata,
                                                                        output bit sberr,
                                                                        output bit dberr); 
         generate 
           case(fpgatech)
             default: xcv5_itlbram #(.ECC(ECC), .ECCSCRUB(ECCSCRUB)) tlbram(.*);
           endcase
         endgenerate                                                                                                                                      
endmodule

module itlbram_fast #(parameter fpgatech_type fpgatech = xilinx_virtex5, parameter ECC = "TRUE", parameter ECCSCRUB = "FALSE") (input iu_clk_type 		gclk, input bit			rst,
                                                                        input mmu_itlbram_addr_type fromiu_addr,
                                                                        input mmu_itlbram_addr_type frommem_addr,
                                                                        input bit                   fromiu_we,
                                                                        input mmu_itlbram_data_type fromiu_data,
                                                                        input mmu_itlbram_data_type frommem_data,
                                                                        input bit                   frommem_we,
                                                                        output mmu_itlbram_data_type  toiu_data,
                                                                        output bit sberr,
                                                                        output bit dberr); 
         generate 
           case(fpgatech)
             default: xcv5_itlbram_fast #(.ECC(ECC), .ECCSCRUB(ECCSCRUB)) tlbram(.*);
           endcase
         endgenerate                                                                                                                                      
endmodule


module mac_gmii #(parameter fpgatech_type fpgatech = xilinx_virtex5, parameter CLKMUL = 5, parameter CLKDIV = 4,  parameter CLKIN_PERIOD = 10.0, parameter BOARDSEL=1) 
(    
  // clock
  input bit           reset /* synthesis syn_maxfan=1000000 */,          //global reset input
  input bit           clkin, 
  input bit           clk200,     // 200 MHz reference clock for IDELAYCTRL
  input bit           ring_clk,   // user clock
  output bit          ring_rst,   // ring reset

  output bit [63:0] rxq_bits,
  output bit [7:0]  rxq_aux_bits,
  output bit        rxq_val,
  input bit         rxq_rdy,

  input bit [63:0] txq_bits,
  input bit [7:0]  txq_aux_bits,
  input bit        txq_val,
  output bit       txq_rdy,

  // GMII Interface (1000 Base-T PHY interface)
  output bit [7:0]    GMII_TXD   /* synthesis syn_useioff=1 */,   
  output bit          GMII_TX_EN /* synthesis syn_useioff=1 */,
  output bit          GMII_TX_ER /* synthesis syn_useioff=1 */,
  output bit          GMII_TX_CLK, //to PHY. Made in ODDR
  input  bit [7:0]    GMII_RXD,
  input  bit          GMII_RX_DV,
  input  bit          GMII_RX_ER,
  input  bit          GMII_RX_CLK, //from PHY. Goes through BUFG
  output bit          GMII_RESET_B      
);
  generate 
    case(fpgatech)
    default: xcv5_mac_gmii #(.CLKMUL(CLKMUL), .CLKDIV(CLKDIV), .CLKIN_PERIOD(CLKIN_PERIOD), .BOARDSEL(BOARDSEL)) macgmii(.*);
  endcase
  endgenerate                                                                                                                                      
endmodule		   

