//---------------------------------------------------------------------------   
// File:        icacheram.v
// Author:      Zhangxi Tan
// Description: icacheram mapping for xilinx virtex 5	
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
import libiu::*;
import libcache::*;
`else
`include "../../../cpu/libiu.sv"
`include "../../../cpu/libmmu.sv"
`include "../../../cpu/libcache.sv"
`endif

// *************************$ refill timing when write2x = 1***************************
// clk     ______________                ______________
//        |              |              |              |
//                       ----------------              ----------------
//         _______        _______        _______        _______
// clk2x  |       |      |       |      |       |      |       |
//                --------       --------       --------       --------
//
//          <-------addr & controls------>
// 
//          <----data1----><----data2---->
//                                       
//********************de-serialize & write timing******************** 
//                                      ^----------------------------------------latch addr&controls at posedge clk
//                                        <-------addr & controls------>
//
//                       ^ ------------------------------------------------------latch data1 at negedge of clk
//                         <-----------data1------------>
//
//                                      ^ ---------------------------------------latch data2 at posedge of clk
//                                        <-----------data2------------>
//                                                     ^
//                                                     |_________________________write to $ at the second neg edge of clk
//


//icache ram, mem can refill (write) it at 2x clock freq. 
`ifndef SYNP94
module xcv5_icache_ram #(parameter int tagprot = 1,		//tags are protected with parity
		    	 parameter int dataprot = 2,		              //data are protected with ecc
          parameter int read2x  = 0,                 //TODO support double clocked write back
      		  parameter int write2x = 0,                 //double clocked refill
      			 parameter NONECCDRAM = "TRUE",		//non-ECC dram
		      parameter ECCSCRUB = "FALSE" 
		    	 )
`else		    	 
module xcv5_icache_ram #(parameter  tagprot = 1,		//tags are protected with parity
		    	    parameter dataprot = 2,	            	//data are protected with ecc
             parameter read2x  = 0,               //TODO support double clocked write back
		    	    parameter write2x =0,                //double clocked refill
			       parameter NONECCDRAM = "TRUE",		     //non-ECC dram
		         parameter ECCSCRUB = "FALSE" 
		    	 )
`endif

	(input iu_clk_type 		gclk, input bit			rst,
	 input  cache_ram_in_type	  iu_in,		 //iu read/write
	 output cache_ram_out_type	 iu_out,
	 input  cache_ram_in_type	  mem_in,		//mem read/write
	 output cache_ram_out_type	 mem_out	 
	);
	bit [ICSIZE-1:0]		dberr;					                 //ecc error bit
	bit [ICSIZE-1:0]		sberr;					                 //ecc error bit
	bit 				ecc_dberr, ecc_sberr;			              //or reduced ecc error bits

	bit [ICACHELINEMSB_MEM:0]	d_rdata, d_wdata;			//cache read/write data,

	bit [31:0]		t_rdata, t_wdata;			                  //cache tag write data
	bit [3:0]			t_rp, t_wp;				                       //cache tag valid/parity bit	
	bit [8:0]			d_raddr, d_waddr, t_waddr, t_raddr;			//cache read/werite addr

	bit [ICACHELINESIZE_MEM-1:0]	 ecc_parity_dip;				 //ecc parity bit for storing in cache
	bit [ICSIZE-1:0]		d_wren;					//data we, generated based on write index
	bit				          t_wren;					//tag we

	//registers
	bit				iu_rsel;				//line select; 0 = first half, 1 = second half 
	
	//registers for deserialization
  bit [ICACHELINEMSB_MEM:0]                   deser_wdata;      //de-serialized write data
  bit [ICACHELINESIZE_MEM-1:0]                deser_ecc_parity; //de-serialized ecc parity bits
  (* syn_preserve=1 *) bit [8:0]              deser_waddr;      //de-serialized write address
  bit                       deser_wren;       //de-serizliaed we
 
  always_comb begin	//control signals
	  //-----------------Tag---------------------------
		//IU -> cache,  tag only	
		t_wren = (gclk.ce)? iu_in.write.we_tag : mem_in.write.we_tag;
				 
		t_waddr = (gclk.ce)? {iu_in.write.tid, iu_in.write.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]} : {mem_in.write.tid, mem_in.write.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};		//mem write to tag only when flush
		t_raddr = (gclk.ce)? {iu_in.read.tid, iu_in.read.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]} : {mem_in.read.tid, mem_in.read.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};								
					
		t_wdata = '0;
		//t_wdata[31-ICACHETAGLSB+2:0] = (gclk.ce)? iu_in.write.tag.tag.I : mem_in.write.tag.tag.I;
		t_wdata[31-ICACHETAGLSB:0] = (gclk.ce)? iu_in.write.tag.tag.I : mem_in.write.tag.tag.I;
		//only IU will modify the tag
		t_wp = {1'b0, iu_in.write.tag.valid, iu_in.write.tag.dirty, iu_in.write.tag.parity}; 

		//-----------tag output-----------
		//iu_out.tag = t_rdata[$left(iu_out.tag):0];	//doesn't support $left now
		iu_out.tag.tag.I = t_rdata[31-ICACHETAGLSB:0];
    mem_out.tag.tag.I = t_rdata[31-ICACHETAGLSB:0];
    
		{iu_out.tag.valid, iu_out.tag.dirty, iu_out.tag.parity} = (tagprot > 0) ? t_rp[2:0] : {t_rp[2:1], 1'b0};
		{mem_out.tag.valid, mem_out.tag.dirty, mem_out.tag.parity} = (tagprot > 0) ? t_rp[2:0] : {t_rp[2:1], 1'b0};
						
	  //-----------------Data---------------------------	
		//cache -> IU 
		//The following needs to be fast (~400 MHz) and optimized across module boundaries 
		//-----------data output-----------
		iu_out.data.data.I = (iu_rsel == 0)? d_rdata[ICACHELINEMSB_IU:0] : d_rdata[ICACHELINEMSB_MEM:ICACHELINEMSB_IU+1];
		iu_out.data.ecc_parity.I = '0;		//don't care in IU
					
		//-----------data input-----------
		//mem -> cache, data only
		
		if (write2x == 0) begin
    		d_wdata = {mem_in.write.data.data.I, mem_in.write.data.data.I};
    		d_wren  = (gclk.ce)? '0 : mem_in.write.we_data.I;	
    		d_waddr = {mem_in.write.tid, mem_in.write.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};
    		ecc_parity_dip = {2{mem_in.write.data.ecc_parity.I}};
		end
		else begin
      d_wdata = deser_wdata;
      d_wren  = (gclk.ce)? '0 : {ICSIZE{deser_wren}};	
      d_waddr = deser_waddr;		  
      ecc_parity_dip = deser_ecc_parity;
		end
		
		d_raddr = {iu_in.read.tid, iu_in.read.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};
		
		if (NONECCDRAM == "TRUE")
		   ecc_parity_dip = '0;
	end
	
	always_ff @(posedge gclk.clk) begin
		iu_rsel <= iu_in.read.index.I[ICACHEINDEXLSB_IU];
	end
	
  //deserialization (optimized away when write=0)
	always_ff @(posedge gclk.clk) begin    //these registers also help routing
	  deser_waddr <= {mem_in.write.tid, mem_in.write.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};
	  deser_wren  <= mem_in.write.we_data.I;	  
	  if (mem_in.write.we_data.I[0]) begin
  	  deser_wdata[ICACHELINEMSB_MEM:ICACHELINEMSB_IU+1] <= mem_in.write.data.data.I;
  	  deser_ecc_parity[ICACHELINESIZE_MEM-1:ICACHELINESIZE_IU] <= mem_in.write.data.ecc_parity.I;
	  end
	end
	
	always_ff @(negedge gclk.clk) begin
    if (mem_in.write.we_data.I[0]) begin
      deser_wdata[ICACHELINEMSB_IU:0] <= mem_in.write.data.data.I;
      deser_ecc_parity[ICACHELINESIZE_IU-1:0] <= mem_in.write.data.ecc_parity.I;
    end
	end
				
	//tag
	RAMB18SDP #(.DO_REG(1))
		ic_tag(
		.DO(t_rdata),
		.DOP(t_rp),
		.DI(t_wdata),
		.DIP(t_wp),	 
		.RDADDR(t_raddr), 
		.RDCLK(gclk.clk2x), 
		.RDEN(1'b1), 
		.REGCE(1'b1), 
		.SSR(rst), 
		.WE(4'hF), 
		.WRADDR(t_waddr), 
		.WRCLK(gclk.clk2x), 
		.WREN(t_wren));

	
	generate
		genvar i;	//generate variable
		
		case(dataprot)
		0:begin	//TODO: replace with byte-wide WE to simplify implementation
			//no protection				
			assign iu_out.data.ecc_error.sberr = '0; 
			assign iu_out.data.ecc_error.dberr = '0;
			assign mem_out.data.ecc_error.sberr = '0;
			assign mem_out.data.ecc_error.dberr = '0;

			//generate data BRAMs
			for(i=0;i<ICSIZE;i++) begin					  
			//data
				RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("FALSE"), .EN_ECC_WRITE("FALSE"),.EN_ECC_SCRUB("FALSE"))
					ic_data	(					 
					.DO(d_rdata[i*64+63:i*64]), 
//					.DOP(ecc_parity[i*8+7:i*8]), 					  
		  			.DI(d_wdata[i*64+63:i*64]),					
					.RDADDR(d_raddr), 
					.RDCLK(gclk.clk2x), 
					.RDEN(1'b1), 
					.REGCE(1'b1), 
					.SSR(rst), 
					.WE(8'hFF), 
					.WRADDR(d_waddr), 
					.WRCLK(gclk.clk2x), 
					.WREN(d_wren[i]),
					//unconnected ports
          .DIP(),
					.DOP(),
					.DBITERR(),
					.SBITERR(),
					.ECCPARITY()
					);  
				end
		end		
		//TODO: replace with byte-wide WE to simplify implementation	
		default:begin	//by default, use ECC
				assign ecc_sberr = |sberr;			//or-reduce error bits
				assign ecc_dberr = |dberr;
				assign iu_out.data.ecc_error.sberr = ecc_sberr; 
				assign iu_out.data.ecc_error.dberr = ecc_dberr;
				assign mem_out.data.ecc_error.sberr = ecc_sberr;
				assign mem_out.data.ecc_error.dberr = ecc_dberr;

				//generate data BRAMs
				for(i=0;i<ICSIZE;i++) begin					  
					//data
					RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE(NONECCDRAM),.EN_ECC_SCRUB(ECCSCRUB))
					ic_data	(
					.DBITERR(dberr[i]),
					.SBITERR(sberr[i]), 
					.DO(d_rdata[i*64+63:i*64]), 
//					.DOP(ecc_parity[i*8+7:i*8]), 					  
		  			.DI(d_wdata[i*64+63:i*64]),
					.DIP(ecc_parity_dip[i*8 +: 8]), 
					.RDADDR(d_raddr), 
					.RDCLK(gclk.clk2x), 
					.RDEN(1'b1), 
					.REGCE(1'b1), 
					.SSR(1'b0), 
					.WE(8'hFF), 
					.WRADDR(d_waddr), 
					.WRCLK(gclk.clk2x), 
					.WREN(d_wren[i]),
					//unconnected ports
					.DOP(),
					.ECCPARITY()
					);  
				end
			end
		endcase	
	endgenerate
endmodule


//icache ram, mem can refill (write) it at 2x clock freq. 
`ifndef SYNP94
module xcv5_icache_ram_wide #(parameter int tagprot = 1,		//tags are protected with parity
             parameter int dataprot = 2,		//data are protected with ecc
             parameter NONECCDRAM = "TRUE",		//non-ECC dram
             parameter ECCSCRUB = "FALSE" 
           )
`else		    	 
module xcv5_icache_ram_wide #(parameter  tagprot = 1,		//tags are protected with parity
             parameter dataprot = 2,	            	//data are protected with ecc
             parameter NONECCDRAM = "TRUE",		     //non-ECC dram
             parameter ECCSCRUB = "FALSE" 
           )
`endif

  (input iu_clk_type 		gclk, input bit			rst,
   input  cache_ram_in_type	  iu_in,		 //iu read/write
   output cache_ram_out_type	 iu_out,
   input  cache_ram_wide_in_type	  mem_in,		//mem read/write
   output cache_ram_wide_out_type	 mem_out	 
  );
  bit [ICSIZE-1:0]		dberr;					                     //ecc error bit
  bit [ICSIZE-1:0]		sberr;					                     //ecc error bit
  bit 				ecc_dberr, ecc_sberr;			                  //or reduced ecc error bits

  bit [ICACHELINEMSB_MEM:0]	d_rdata, d_wdata;			    //cache read/write data,

  bit [31:0]		t_rdata, t_wdata;			                  //cache tag write data
  bit [3:0]			t_rp, t_wp;				                       //cache tag valid/parity bit	
  bit [8:0]			d_raddr, d_waddr, t_waddr, t_raddr;			//cache read/werite addr

  //bit [CACHELINESIZE_MEM-1:0]	ecc_parity;				//ecc parity bit for storing in dram
  bit [ICSIZE-1:0]		d_wren;					//data we, generated based on write index
  bit				           t_wren;					//tag we

  //registers
  bit				iu_rsel;				//line select; 0 = first half, 1 = second half 
  //bit				ce;					//clock enable for IU/mem, 1 = IU, 0 = mem
  
 
  always_comb begin	//control signals
 
  //-----------------Tag---------------------------
    //IU -> cache,  tag only	
    t_wren = (gclk.ce)? iu_in.write.we_tag : mem_in.write.we_tag;
         
    t_waddr = (gclk.ce)? {iu_in.write.tid, iu_in.write.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]} : {mem_in.write.tid, mem_in.write.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};		//mem write to tag only when flush
    t_raddr = (gclk.ce)? {iu_in.read.tid, iu_in.read.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]} : {mem_in.read.tid, mem_in.read.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};								
          
    t_wdata = '0;
    t_wdata[31-ICACHETAGLSB+2:0] = (gclk.ce)? iu_in.write.tag.tag.I : mem_in.write.tag.tag.I;
    //only IU will modify the tag
    t_wp = {1'b0, iu_in.write.tag.valid, iu_in.write.tag.dirty, iu_in.write.tag.parity}; 

    //-----------tag output-----------
    //iu_out.tag = t_rdata[$left(iu_out.tag):0];	//doesn't support $left now
    iu_out.tag.tag.I = t_rdata[31-ICACHETAGLSB:0];
    mem_out.tag.tag.I = t_rdata[31-ICACHETAGLSB:0];
    {iu_out.tag.valid, iu_out.tag.dirty, iu_out.tag.parity} = (tagprot > 0) ? t_rp[2:0] : {t_rp[2:1], 1'b0};
    {mem_out.tag.valid, mem_out.tag.dirty, mem_out.tag.parity} = (tagprot > 0) ? t_rp[2:0] : {t_rp[2:1], 1'b0};
            
  //-----------------Data---------------------------	
    //cache -> IU 
    //The following needs to be fast (~400 MHz) and optimized across module boundaries 
    //-----------data output-----------
    iu_out.data.data.I = (iu_rsel == 0)? d_rdata[ICACHELINEMSB_IU:0] : d_rdata[ICACHELINEMSB_MEM:ICACHELINEMSB_IU+1];
    iu_out.data.ecc_parity.I = '0;		//don't care in IU
          
    //-----------data input-----------
    //mem -> cache, data only
    d_wdata = mem_in.write.data.data.I;
    d_wren  = (gclk.ce)? '0 : mem_in.write.we_data.I;	
    d_waddr = {mem_in.write.tid, mem_in.write.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};
    d_raddr = {iu_in.read.tid, iu_in.read.index.I[ICACHEINDEXMSB_MEM:ICACHEINDEXLSB_MEM]};
  end
  
  always_ff @(posedge(gclk.clk)) begin
    iu_rsel <= iu_in.read.index.I[ICACHEINDEXLSB_IU];
  end
        
  //tag
  RAMB18SDP #(.DO_REG(1))
    ic_tag(
    .DO(t_rdata),
    .DOP(t_rp),
    .DI(t_wdata),
    .DIP(t_wp),	 
    .RDADDR(t_raddr), 
    .RDCLK(gclk.clk2x), 
    .RDEN(1'b1), 
    .REGCE(1'b1), 
    .SSR(rst), 
    .WE(4'hF), 
    .WRADDR(t_waddr), 
    .WRCLK(gclk.clk2x), 
    .WREN(t_wren));

  
  generate
    genvar i;	//generate variable
    
    case(dataprot)
    0:begin	//TODO: replace with byte-wide WE to simplify implementation
      //no protection				
      assign iu_out.data.ecc_error.sberr = '0; 
      assign iu_out.data.ecc_error.dberr = '0;
      assign mem_out.data.ecc_error.sberr = '0;
      assign mem_out.data.ecc_error.dberr = '0;

      //generate data BRAMs
      for(i=0;i<ICSIZE;i++) begin					  
      //data
        RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("FALSE"), .EN_ECC_WRITE("FALSE"),.EN_ECC_SCRUB("FALSE"))
          ic_data	(					 
          .DO(d_rdata[i*64+63:i*64]), 
//					.DOP(ecc_parity[i*8+7:i*8]), 					  
          .DI(d_wdata[i*64+63:i*64]),					
          .RDADDR(d_raddr), 
          .RDCLK(gclk.clk2x), 
          .RDEN(1'b1), 
          .REGCE(1'b1), 
          .SSR(rst), 
          .WE(8'hFF), 
          .WRADDR(d_waddr), 
          .WRCLK(gclk.clk2x), 
          .WREN(d_wren[i]),
          //unconnected ports
          .DOP(),
          .DBITERR(),
          .SBITERR(),
          .ECCPARITY()
          );  
        end
    end		
    //TODO: replace with byte-wide WE to simplify implementation	
    default:begin	//by default, use ECC
        assign ecc_sberr = |sberr;			//or-reduce error bits
        assign ecc_dberr = |dberr;
        assign iu_out.data.ecc_error.sberr = ecc_sberr; 
        assign iu_out.data.ecc_error.dberr = ecc_dberr;
        assign mem_out.data.ecc_error.sberr = ecc_sberr;
        assign mem_out.data.ecc_error.dberr = ecc_dberr;

        //generate data BRAMs
        for(i=0;i<ICSIZE;i++) begin					  
          //data
          RAMB36SDP #(.DO_REG(1), .EN_ECC_READ("TRUE"), .EN_ECC_WRITE(NONECCDRAM),.EN_ECC_SCRUB(ECCSCRUB))
          ic_data	(
          .DBITERR(dberr[i]),
          .SBITERR(sberr[i]), 
          .DO(d_rdata[i*64+63:i*64]), 
//					.DOP(ecc_parity[i*8+7:i*8]), 					  
            .DI(d_wdata[i*64+63:i*64]),
          .DIP(mem_in.write.data.ecc_parity.I[i/2*8+7:i/2*8]), 
          .RDADDR(d_raddr), 
          .RDCLK(gclk.clk2x), 
          .RDEN(1'b1), 
          .REGCE(1'b1), 
          .SSR(1'b0), 
          .WE(8'hFF), 
          .WRADDR(d_waddr), 
          .WRCLK(gclk.clk2x), 
          .WREN(d_wren[i]),
          //unconnected ports
          .DOP(),
          .ECCPARITY()
          );  
        end
      end
    endcase	
  endgenerate
endmodule
