//------------------------------------------------------------------------------   
// File:        libstd.sv
// Author:      Zhangxi Tan
// Description: standard helper library
//------------------------------------------------------------------------------  

`timescale 1ns / 1ps

`ifndef SYNP94
package libstd;
`endif

 function int log2x(int a);
	for (int i=0;i<31;i++) begin
		if (2**i >= a) begin
			return i;
		end
	end 
	return 32;
  endfunction
  
  //big endian conversion, ld/st
  function bit [15:0] ldsts_big_endian(bit [15:0] din);
   return {din[7:0], din[15:8]};
  endfunction
  
  function bit [31:0] ldst_big_endian(bit [31:0] din);
    return {din[7:0], din[15:8], din[23:16], din[31:24]};
  endfunction

  //big endian conversion, ldd/std  
  function bit [63:0] ldstd_big_endian(bit [63:0] din);
    return {ldst_big_endian(din[63:32]),ldst_big_endian(din[31:0])};
  endfunction

  function int halfbits(int nbits);
    return ((nbits % 2) ? nbits/2 + 1 : nbits/2);
  endfunction 
  
  function int max(int a, int b);
	return (a>b) ? a : b;
  endfunction
  
  function int min(int a, int b);
  return (a<b) ? a : b;
  endfunction


/*
pseudo-LRU

two-way set associative - one bit

   indicates which line of the two has been reference more recently


four-way set associative - three bits

   each bit represents one branch point in a binary decision tree; let 1
   represent that the left side has been referenced more recently than the
   right side, and 0 vice-versa

              are all 4 lines valid?
                   /       \
                 yes        no, use an invalid line
                  |
                  |
                  |
             bit_0 == 0?            state | replace      ref to | next state
              /       \             ------+--------      -------+-----------
             y         n             00x  |  line_0      line_0 |    11_
            /           \            01x  |  line_1      line_1 |    10_
     bit_1 == 0?    bit_2 == 0?      1x0  |  line_2      line_2 |    0_1
       /    \          /    \        1x1  |  line_3      line_3 |    0_0
      y      n        y      n
     /        \      /        \        ('x' means       ('_' means unchanged)
   line_0  line_1  line_2  line_3      don't care)

   (see Figure 3-7, p. 3-18, in Intel Embedded Pentium Processor Family Dev.
    Manual, 1998, http://www.intel.com/design/intarch/manuals/273204.htm)


note that there is a 6-bit encoding for true LRU for four-way set associative

  bit 0: bank[1] more recently used than bank[0]
  bit 1: bank[2] more recently used than bank[0]
  bit 2: bank[2] more recently used than bank[1]
  bit 3: bank[3] more recently used than bank[0]
  bit 4: bank[3] more recently used than bank[1]
  bit 5: bank[3] more recently used than bank[2]

  this results in 24 valid bit patterns within the 64 possible bit patterns
  (4! possible valid traces for bank references)

  e.g., a trace of 0 1 2 3, where 0 is LRU and 3 is MRU, is encoded as 111111

  you can implement a state machine with a 256x6 ROM (6-bit state encoding
  appended with a 2-bit bank reference input will yield a new 6-bit state),
  and you can implement an LRU bank indicator with a 64x2 ROM

*/
  function bit get_referenced_2way_lru(bit [1:0] hit);
    return (hit[1])? '1 : '0;
  endfunction

  //way selection algorithm
  function bit get_replaced_2way_lru(bit [1:0] valid, bit old_lru);
  bit ret;
  
  unique case(valid)
  2'b00: ret = '0;
  2'b01: ret = '1;
  2'b10: ret = '0;
  2'b11: ret = ~old_lru;
  endcase
  
  return ret;
  endfunction
  
  function bit get_new_2way_lru(bit [1:0] hit, bit [1:0] valid, bit old_lru);
    bit ret;
    
    if (|hit)
      ret = get_referenced_2way_lru(hit);
    else
      ret = get_replaced_2way_lru(valid, old_lru);
    
    return ret;
  endfunction
  
  function bit [2:0] get_referenced_4way_pseudo_lru(bit [1:0] ref_way, bit [2:0] old_lru);
    bit [2:0] new_lru;
    unique case(ref_way) 
     2'd0: new_lru = {2'b11, old_lru[0]};
     2'd1: new_lru = {2'b10, old_lru[0]};
     2'd2: new_lru = {1'b0, old_lru[1], 1'b1};
     2'd3: new_lru = {1'b0, old_lru[1], 1'b0};
    endcase
    
    return new_lru;
  endfunction
  
  function bit [1:0] get_replaced_4way_pseudo_lru(bit [3:0] valid, bit [2:0] old_lru);
    bit replaced_nway;
    
    unique case (valid)
    4'b0000: replaced_nway = 2'd0; 
    4'b0001: replaced_nway = 2'd1; 
    4'b0010: replaced_nway = 2'd0;
    4'b0011: replaced_nway = 2'd2;
    4'b0100: replaced_nway = 2'd0;
    4'b0101: replaced_nway = 2'd1;
    4'b0110: replaced_nway = 2'd0;
    4'b0111: replaced_nway = 2'd3;
    4'b1000: replaced_nway = 2'd0;
    4'b1001: replaced_nway = 2'd1;
    4'b1010: replaced_nway = 2'd0;
    4'b1011: replaced_nway = 2'd2;
    4'b1100: replaced_nway = 2'd0;
    4'b1101: replaced_nway = 2'd1;
    4'b1110: replaced_nway = 2'd0;
    4'b1111: begin
              unique casex(old_lru)
              3'b000, 3'b001: replaced_nway = 2'd0;
              3'b010, 3'b011: replaced_nway = 2'd1;
              3'b100, 3'b110: replaced_nway = 2'd2;
              3'b101, 3'b111: replaced_nway = 2'd3;
              endcase
             end
    endcase

    return replaced_nway;
  endfunction


 //64-bit ECC encoder (ripped from Xilinx unisim)
 
 function bit [7:0] bram_dip_ecc(input bit [63:0] di_in);
   bit [7:0] fn_dip_ecc;

   fn_dip_ecc[0] = di_in[0]^di_in[1]^di_in[3]^di_in[4]^di_in[6]^di_in[8]
      ^di_in[10]^di_in[11]^di_in[13]^di_in[15]^di_in[17]^di_in[19]
      ^di_in[21]^di_in[23]^di_in[25]^di_in[26]^di_in[28]
                ^di_in[30]^di_in[32]^di_in[34]^di_in[36]^di_in[38]
      ^di_in[40]^di_in[42]^di_in[44]^di_in[46]^di_in[48]
      ^di_in[50]^di_in[52]^di_in[54]^di_in[56]^di_in[57]^di_in[59]
      ^di_in[61]^di_in[63];

   fn_dip_ecc[1] = di_in[0]^di_in[2]^di_in[3]^di_in[5]^di_in[6]^di_in[9]
                  ^di_in[10]^di_in[12]^di_in[13]^di_in[16]^di_in[17]
                  ^di_in[20]^di_in[21]^di_in[24]^di_in[25]^di_in[27]^di_in[28]
                  ^di_in[31]^di_in[32]^di_in[35]^di_in[36]^di_in[39]
                  ^di_in[40]^di_in[43]^di_in[44]^di_in[47]^di_in[48]
                  ^di_in[51]^di_in[52]^di_in[55]^di_in[56]^di_in[58]^di_in[59]
                  ^di_in[62]^di_in[63];

   fn_dip_ecc[2] = di_in[1]^di_in[2]^di_in[3]^di_in[7]^di_in[8]^di_in[9]
                  ^di_in[10]^di_in[14]^di_in[15]^di_in[16]^di_in[17]
                  ^di_in[22]^di_in[23]^di_in[24]^di_in[25]^di_in[29]
                  ^di_in[30]^di_in[31]^di_in[32]^di_in[37]^di_in[38]^di_in[39]
                  ^di_in[40]^di_in[45]^di_in[46]^di_in[47]^di_in[48]
                  ^di_in[53]^di_in[54]^di_in[55]^di_in[56]
                  ^di_in[60]^di_in[61]^di_in[62]^di_in[63];

   fn_dip_ecc[3] = di_in[4]^di_in[5]^di_in[6]^di_in[7]^di_in[8]^di_in[9]
      ^di_in[10]^di_in[18]^di_in[19]
                  ^di_in[20]^di_in[21]^di_in[22]^di_in[23]^di_in[24]^di_in[25]
                  ^di_in[33]^di_in[34]^di_in[35]^di_in[36]^di_in[37]^di_in[38]^di_in[39]
                  ^di_in[40]^di_in[49]
                  ^di_in[50]^di_in[51]^di_in[52]^di_in[53]^di_in[54]^di_in[55]^di_in[56];

   fn_dip_ecc[4] = di_in[11]^di_in[12]^di_in[13]^di_in[14]^di_in[15]^di_in[16]^di_in[17]^di_in[18]^di_in[19]
                  ^di_in[20]^di_in[21]^di_in[22]^di_in[23]^di_in[24]^di_in[25]
                  ^di_in[41]^di_in[42]^di_in[43]^di_in[44]^di_in[45]^di_in[46]^di_in[47]^di_in[48]^di_in[49]
                  ^di_in[50]^di_in[51]^di_in[52]^di_in[53]^di_in[54]^di_in[55]^di_in[56];


   fn_dip_ecc[5] = di_in[26]^di_in[27]^di_in[28]^di_in[29]
                  ^di_in[30]^di_in[31]^di_in[32]^di_in[33]^di_in[34]^di_in[35]^di_in[36]^di_in[37]^di_in[38]^di_in[39]
                  ^di_in[40]^di_in[41]^di_in[42]^di_in[43]^di_in[44]^di_in[45]^di_in[46]^di_in[47]^di_in[48]^di_in[49]
                  ^di_in[50]^di_in[51]^di_in[52]^di_in[53]^di_in[54]^di_in[55]^di_in[56];

   fn_dip_ecc[6] = di_in[57]^di_in[58]^di_in[59]
                  ^di_in[60]^di_in[61]^di_in[62]^di_in[63];

 
   fn_dip_ecc[7] = fn_dip_ecc[0]^fn_dip_ecc[1]^fn_dip_ecc[2]^fn_dip_ecc[3]^fn_dip_ecc[4]^fn_dip_ecc[5]^fn_dip_ecc[6]
                  ^di_in[0]^di_in[1]^di_in[2]^di_in[3]^di_in[4]^di_in[5]^di_in[6]^di_in[7]^di_in[8]^di_in[9]
                  ^di_in[10]^di_in[11]^di_in[12]^di_in[13]^di_in[14]^di_in[15]^di_in[16]^di_in[17]^di_in[18]^di_in[19]
                  ^di_in[20]^di_in[21]^di_in[22]^di_in[23]^di_in[24]^di_in[25]^di_in[26]^di_in[27]^di_in[28]^di_in[29]
                  ^di_in[30]^di_in[31]^di_in[32]^di_in[33]^di_in[34]^di_in[35]^di_in[36]^di_in[37]^di_in[38]^di_in[39]
                  ^di_in[40]^di_in[41]^di_in[42]^di_in[43]^di_in[44]^di_in[45]^di_in[46]^di_in[47]^di_in[48]^di_in[49]
                  ^di_in[50]^di_in[51]^di_in[52]^di_in[53]^di_in[54]^di_in[55]^di_in[56]^di_in[57]^di_in[58]^di_in[59]
                  ^di_in[60]^di_in[61]^di_in[62]^di_in[63];
   return fn_dip_ecc;

 endfunction // fn_dip_ecc


`ifndef SYNP94
endpackage
`endif
