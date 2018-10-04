//------------------------------------------------------------------------------------------------------------------
// File:        aludiv.sv
// Author:      Zhangxi Tan
// Description: alu div implementation for xilinx virtex 5. a simple non-restoring divider is implemented
//              output result is shaped, so that either pos or neg clk edge can sample the result
//------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libiu::*;
import libopcodes::*;
import libconf::*;
import libxalu::*;
`else
`include "../../../cpu/libiu.sv"
`include "../../../cpu/libxalu.sv"
`endif


typedef enum bit [2:0] {m_idle, m_udiv_ovf, m_div, m_qcorr, m_qcorr_final} div_state_type;  

typedef struct {
    bit [NTHREADIDMSB:0]	tid;				    //thread id
    bit [64:0]           s;          //partial remainder
    bit                  msb;        //msb of partial remainder
    bit [32:0]           d;          //divisor
    bit                  sign;       //sign 
    bit [4:0]            cnt;        //shift count 
    bit                  signdiv;    //sign(dividend)
    bit                  ovf;        //overflow bit for unsigned div  

    bit                  v;          //v flag
    bit                  valid;      //shift/sub finished
    bit [32:0]           q;          //result    
}div_reg_type;


//trying to run this divider at clk2x, but the result is valid in one clk cycle
module xcv5_alu_div_2x 
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type  din,
 input  bit                en,     //input valid
 input  y_reg_type         yin,    //y input
 output xalu_fu_out_type   dout,
 output bit                re      //input fifo RE control   
); 

div_state_type      vstate, rstate;
//bit [$bits(div_state_type)-1:0]			vstate, rstate;


div_reg_type        vd, rd;

bit                 ififo_re;           //input fifo RE control

//signals for input fifo parity verification
bit                 op1_parity;         //parity for OP1 
bit                 op2_parity;         //parity for OP2
bit                 misc_parity;        //parity for misc
bit                 y_parity;
   
bit                 parity_detected;    //input parity error detected

//shaper signals
typedef enum bit [1:0] {o_idle, o_latch, o_hold}  div_outctrl_type;      //output control state  
div_outctrl_type                   v_ostate, r_ostate;
//bit [$bits(div_outctrl_type)-1:0]                   v_ostate, r_ostate;


//adder control signals
bit [32:0]          addin1, addin2;     //adder input signals
bit [32:0]          addout;
bit                 addsub;             //0 = add, 1 = sub

//output register
xalu_fu_out_type    vo, ro;

always_comb begin
  //default values
  vd = rd;
  vo = ro;
  
  vstate = rstate;
  v_ostate = r_ostate;
  
  ififo_re = '0;

  //adder input   
  addin1 = rd.s[64:32];

  if (rd.sign)  //sdiv
    addsub = (rd.msb == rd.d[32])? '1 : '0;
  else          //udiv
    addsub = (rd.msb == 0)? '1 : '0;
  
  addin2 = (addsub)? ~rd.d : rd.d;

  
  unique case(rstate)
  m_idle: begin          
            vd.cnt   = '0;
            vd.valid = '0;
            vd.tid   = din.tid;
            
            vd.sign    = (din.mode == c_SDIV)? '1 : '0;             

            vd.s[63:0] = {yin.y, din.op1}; vd.d = din.op2;
            vd.s[64] = (vd.sign)? yin.y[31]   : '0; 
            vd.d[32] = (vd.sign)? din.op2[31] : '0;      
            
            vd.msb = vd.s[64];
            
            vd.signdiv = yin.y[31];
            
            vd.ovf    = '0;

            if (en) begin                                                           
              //fifo control
              ififo_re = '1;
                
              vstate = m_udiv_ovf;
            end
          end
  m_udiv_ovf: begin    //udiv overflow detection
            vd.cnt = '0;
            vd.valid = '0;
            
            vd.ovf = !addout[32];
            
            vstate = (rd.sign == 0 && vd.ovf) ? m_qcorr : m_div;
                        
            vd.s[64:0] = {rd.s[63:0], addsub};    //just shift left
          end
  m_div : begin
            vd.valid = '0;
            
            vd.msb = addout[32];
            vd.s[64:0] = {addout[31:0], rd.s[31:0], addsub};
            
            vd.cnt = rd.cnt + 1;

            if (rd.cnt == 5'b11111) 
              vstate = m_qcorr;
          end
  m_qcorr: begin
            //does nothing but for smaller circuit
            vd.msb = addout[32];
            vd.s[64:0] = {addout[31:0], rd.s[31:0], addsub};
                         
            vd.valid    = '0;
            vstate      = m_idle;            
           end            
  endcase


  //correct q
  if (rd.sign) begin
    if (rd.msb != rd.signdiv) begin
      vd.q[32:0] = (rd.signdiv == rd.d[32])? 33'h1ffffffff : 33'h1;
      vd.q[32:0] = {!rd.s[31], rd.s[30:0], 1'b1} + vd.q[32:0];
    end
    else
      vd.q[32:0] = {!rd.s[31], rd.s[30:0], 1'b1};
      
      vd.v = vd.q[32] ^ vd.q[31]; 
      
      if (vd.v)   //overflow
        vd.q[31:0] = (rd.signdiv == rd.d[32])? 32'h7fffffff: 32'h80000000;      
  end
  else begin
      vd.v = rd.ovf;
      vd.q[32]   = {!rd.s[31]};             //no meaning here
      vd.q[31:0] = {rd.s[30:0], addsub};
      
      if (rd.ovf)
        vd.q[31:0] = 32'hffffffff;
        
  end
  //output FSM
  
  //no use part
  vo.data.y = '{0, 0};
  unique case(r_ostate)
  o_idle : begin
            if (rd.valid) begin
                v_ostate = o_latch;
                
                //latch result
                vo.tid    = rd.tid;
                vo.data.res[31:0] =  rd.q[31:0];
                vo.data.N = rd.q[31];
                vo.data.Z = (rd.q[31:0] == 0)? 1'b1 : 1'b0;
                vo.data.V = rd.v;		              
                vo.data.parity = (LUTRAMPROT)? ^{rd.q[31:0], vo.data.N, vo.data.Z, vo.data.V, parity_detected} : '0;
              
                vo.valid  = '1;                            
            end
            else
              vo.valid = '0;
           end
  o_latch: v_ostate = o_hold;
  o_hold : begin v_ostate = o_idle; vo.valid = '0; end
  endcase
  
  //output signals
  re   = ififo_re;
  dout = ro;
end

always_comb begin
  //div adder
  addout = addin1 + addin2 + addsub;
end

always_ff @(posedge gclk.clk2x) begin
  if (rst) rstate <= m_idle; else rstate <= vstate;
    
  rd <= vd;   
  
  //input parity detection
  op1_parity      <= ^{din.op1, din.op1_parity};
  op2_parity      <= ^{din.op2, din.op2_parity};
  misc_parity     <= ^{din.tid, din.mode, din.misc_parity};
  y_parity        <= ^yin;
  
  if (rd.cnt == 0) 
    parity_detected <= (LUTRAMPROT) ? op1_parity | op2_parity | misc_parity | y_parity : '0;
  else
    parity_detected <= parity_detected;

  //output registers & FSM state
  if (rst) r_ostate <= o_idle; else r_ostate <= v_ostate;
  ro <= vo;
end
  
endmodule

//working at clk 1x
/*
module xcv5_alu_div
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type  din,
 input  bit                en,     //input valid
 input  y_reg_type         yin,    //y input
 output xalu_fu_out_type   dout,
 output bit                re      //input fifo RE control   
); 

div_state_type      vstate, rstate;
//bit [$bits(div_state_type)-1:0]             vstate, rstate;

div_reg_type        vd, rd;

bit                 ififo_re;           //input fifo RE control

//signals for input fifo parity verification
bit                 op1_parity;         //parity for OP1 
bit                 op2_parity;         //parity for OP2
bit                 misc_parity;        //parity for misc
bit                 y_parity;
   
bit                 parity_detected;    //input parity error detected


//adder control signals
bit [32:0]          addin1, addin2;     //adder input signals
bit [32:0]          addout;
bit                 addsub;             //0 = add, 1 = sub

//output register
xalu_fu_out_type    vo, ro;

always_comb begin
  //default values
  vd = rd;
  vo = ro;
  
  vstate = rstate;
  
  ififo_re = '0;

  //adder input   
  addin1 = rd.s[64:32];

  if (rd.sign)  //sdiv
    addsub = (rd.msb == rd.d[32])? '1 : '0;
  else          //udiv
    addsub = (rd.msb == 0)? '1 : '0;
  
  addin2 = (addsub)? ~rd.d : rd.d;

  
  unique case(rstate)
  m_idle: begin          
            vd.cnt   = '0;
            vd.valid = '0;
            vd.tid   = din.tid;
            
            vd.sign    = (din.mode == c_SDIV)? '1 : '0;             

            vd.s[63:0] = {yin.y, din.op1}; vd.d = din.op2;
            vd.s[64] = (vd.sign)? yin.y[31]   : '0; 
            vd.d[32] = (vd.sign)? din.op2[31] : '0;      
            
            vd.msb = vd.s[64];
            
            vd.signdiv = yin.y[31];
            
            vd.ovf    = '0;

            if (en) begin                                                           
              //fifo control
              ififo_re = '1;
                
              vstate = m_udiv_ovf;
            end
          end
  m_udiv_ovf: begin    //udiv overflow detection
            vd.cnt = '0;
            vd.valid = '0;
            
            vd.ovf = !addout[32];
            
            vstate = (rd.sign == 0 && vd.ovf) ? m_qcorr : m_div;
                        
            vd.s[64:0] = {rd.s[63:0], addsub};    //just shift left
          end
  m_div : begin
            vd.valid = '0;
            
            vd.msb = addout[32];
            vd.s[64:0] = {addout[31:0], rd.s[31:0], addsub};
            
            vd.cnt = rd.cnt + 1;

            if (rd.cnt == 5'b11111) 
              vstate = m_qcorr;
          end
  m_qcorr: begin
            //does nothing but for smaller circuit
            vd.msb = addout[32];
            vd.s[64:0] = {addout[31:0], rd.s[31:0], addsub};
                         
            vd.valid    = '1;
            vstate      = m_idle;            
           end            
  endcase


  //correct q
  if (rd.sign) begin
    if (rd.msb != rd.signdiv) begin
      vd.q[32:0] = (rd.signdiv == rd.d[32])? 33'h1ffffffff : 33'h1;
      vd.q[32:0] = {!rd.s[31], rd.s[30:0], 1'b1} + vd.q[32:0];
    end
    else
      vd.q[32:0] = {!rd.s[31], rd.s[30:0], 1'b1};
      
      vd.v = vd.q[32] ^ vd.q[31]; 
      
      if (vd.v)   //overflow
        vd.q[31:0] = (rd.signdiv == rd.d[32])? 32'h7fffffff: 32'h80000000;      
  end
  else begin
      vd.v = rd.ovf;
      vd.q[32]   = {!rd.s[31]};             //no meaning here
      vd.q[31:0] = {rd.s[30:0], addsub};
      
      if (rd.ovf)
        vd.q[31:0] = 32'hffffffff;
        
  end

  //output registers
  
  //no use part
  vo.data.y = '{0, 0};

  //latch result
  vo.valid          = rd.valid;
  vo.tid            = rd.tid;
  vo.data.res[31:0] =  rd.q[31:0];
  vo.data.N = rd.q[31];
  vo.data.Z = (rd.q[31:0] == 0)? 1'b1 : 1'b0;
  vo.data.V = rd.v;		              
  vo.data.parity = (LUTRAMPROT)? ^{rd.q[31:0], vo.data.N, vo.data.Z, vo.data.V, parity_detected} : '0;                  
end

//output signals
assign  re   = ififo_re;
assign  dout = ro;


always_comb begin
  //div adder
  addout = addin1 + addin2 + addsub;
end

always_ff @(posedge gclk.clk) begin
  if (rst) rstate <= m_idle; else rstate <= vstate;
    
  rd <= vd;   
  
  //input parity detection
  op1_parity      <= ^{din.op1, din.op1_parity};
  op2_parity      <= ^{din.op2, din.op2_parity};
  misc_parity     <= ^{din.tid, din.mode, din.misc_parity};
  y_parity        <= ^yin;
  
  if (rd.cnt == 0) 
    parity_detected <= (LUTRAMPROT) ? op1_parity | op2_parity | misc_parity | y_parity : '0;
  else
    parity_detected <= parity_detected;

  //output registers
  ro <= vo;
end
  
endmodule
*/

module xcv5_alu_div
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type  din,
 input  bit                en,     //input valid
 input  y_reg_type         yin,    //y input
 output xalu_fu_out_type   dout,
 output bit                re      //input fifo RE control   
); 

div_state_type      vstate, rstate;
//bit [$bits(div_state_type)-1:0]             vstate, rstate;

div_reg_type        vd, rd;

bit                 ififo_re;           //input fifo RE control

//signals for input fifo parity verification
bit                 op1_parity;         //parity for OP1 
bit                 op2_parity;         //parity for OP2
bit                 misc_parity;        //parity for misc
bit                 y_parity;
   
bit                 parity_detected;    //input parity error detected


//adder control signals
bit [32:0]          addin1, addin2;     //adder input signals
bit [32:0]          addout;
bit                 addsub, r_addsub;             //0 = add, 1 = sub
bit                 addout_zero, r_addout_zero[0:1];

//output register
xalu_fu_out_type    vo, ro;

always_comb begin
  //default values
  vd = rd;
  vo = ro;
  
  vstate = rstate;
  
  ififo_re = '0;

  //adder input   
  addin1 = rd.s[64:32];

  if (rd.sign)  //sdiv
    addsub = (rd.msb == rd.d[32])? '1 : '0;
  else          //udiv
    addsub = (rd.msb == 0)? '1 : '0;
  
  addin2 = (addsub)? ~rd.d : rd.d;

  //div adder
  addout = addin1 + addin2 + addsub;  
  addout_zero = (addout == 0) ? '1 : '0;
  
  unique case(rstate)
  m_idle: begin          
            vd.cnt   = '0;
            vd.valid = '0;
            vd.tid   = din.tid;
            
            vd.sign    = (din.mode == c_SDIV)? '1 : '0;             

            vd.s[63:0] = {yin.y, din.op1}; vd.d = din.op2;
            vd.s[64] = (vd.sign)? yin.y[31]   : '0; 
            vd.d[32] = (vd.sign)? din.op2[31] : '0;      
            
            vd.msb = vd.s[64];
            
            vd.signdiv = yin.y[31];
            
            vd.ovf    = '0;

            if (en) begin                                                           
              //fifo control
              ififo_re = '1;
                
              vstate = m_udiv_ovf;
            end
          end
  m_udiv_ovf: begin    //udiv overflow detection
            vd.cnt = '0;
            vd.valid = '0;
            
            vd.ovf = !addout[32] || addout_zero;
            
            vstate = (rd.sign == 0 && vd.ovf) ? m_qcorr_final : m_div;
                        
            vd.s[64:0] = {rd.s[63:0], addsub};    //just shift left
          end
  m_div : begin
            vd.valid = '0;
            
            vd.msb = addout[32];
            vd.s[64:0] = {addout[31:0], rd.s[31:0], addsub};
            
            vd.cnt = rd.cnt + 1;

            if (rd.cnt == 5'b11111) begin
              vd.s[64:0] = {addout[32:0], rd.s[30:0], addsub};
              vstate = (rd.sign) ? m_qcorr : m_qcorr_final;
            end
          end
  m_qcorr: begin
            vd.s[64:0] = {addout[32:0], rd.s[31:0]};
                         
            vd.valid    = '0;
            vstate      = m_qcorr_final;            
           end            
 default: begin
            //don't care
            vd.s[64:0] = {addout[31:0], rd.s[31:0], addsub};
            
            vd.valid = '1;
            vstate = m_idle;
          end

  endcase


  //correct q
  if (rd.sign) begin
    if ((rd.msb != rd.signdiv || r_addout_zero[0]) && !r_addout_zero[1]) begin
      vd.q[32:0] = (r_addsub)? 33'h1 : 33'h1ffffffff;
      vd.q[32:0] = {!rd.s[31], rd.s[30:0], 1'b1} + vd.q[32:0];
    end
    else
      vd.q[32:0] = {!rd.s[31], rd.s[30:0], 1'b1};
      
    vd.v = vd.q[32] ^ vd.q[31]; 
      
    if (vd.v)   //overflow
       vd.q[31:0] = (rd.signdiv == rd.d[32])? 32'h7fffffff: 32'h80000000;      
  end
  else begin
      vd.v = rd.ovf;
      vd.q[32]   = {!rd.s[31]};             //no meaning here
      vd.q[31:0] = {rd.s[30:0], addsub};
      
      if (rd.ovf)
        vd.q[31:0] = 32'hffffffff;
        
  end

  //output registers
  
  //no use part
  vo.data.y = '{0, 0};

  //latch result
  vo.valid          = rd.valid;
  vo.tid            = rd.tid;
  vo.data.res[31:0] =  rd.q[31:0];
  vo.data.N = rd.q[31];
  vo.data.Z = (rd.q[31:0] == 0)? 1'b1 : 1'b0;
  vo.data.V = rd.v;		              
  vo.data.parity = (LUTRAMPROT)? ^{rd.q[31:0], vo.data.N, vo.data.Z, vo.data.V, parity_detected} : '0;                  
  
  

end


//output signals
assign  re   = ififo_re;
assign  dout = ro;


always_ff @(posedge gclk.clk) begin
  if (rst) rstate <= m_idle; else rstate <= vstate;
    
  rd <= vd;   
  r_addout_zero[0] <= addout_zero;
  r_addout_zero[1] <= r_addout_zero[0];
  r_addsub <= addsub;
  
  //input parity detection
  op1_parity      <= ^{din.op1, din.op1_parity};
  op2_parity      <= ^{din.op2, din.op2_parity};
  misc_parity     <= ^{din.tid, din.mode, din.misc_parity};
  y_parity        <= ^yin;
  
  if (rd.cnt == 0) 
    parity_detected <= (LUTRAMPROT) ? op1_parity | op2_parity | misc_parity | y_parity : '0;
  else
    parity_detected <= parity_detected;

  //output registers
  ro <= vo;
end
  
endmodule