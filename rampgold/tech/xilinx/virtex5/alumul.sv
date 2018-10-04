//--------------------------------------------------------------------------------------------------
// File:        alumul.sv
// Author:      Zhangxi Tan
// Description: alu mul/shf mappings for xilinx virtex 5.
//              output result is shaped, so that either pos or neg clk edge can sample the result
//--------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libiu::*;
import libopcodes::*;
import libconf::*;
import libxalu::*;
import libtech::*;
`else
`include "../../../cpu/libiu.sv"
`include "../../../cpu/libxalu.sv"
`endif

function automatic bit[47:0] shift_mul(bit [4:0] cnt, bit bleft);
  bit [4:0]  mul_cnt;
  bit [47:0] ret_mul;
  
  mul_cnt = (bleft)? cnt : 32-cnt;
  ret_mul = unsigned'(2**mul_cnt);

  return ret_mul;
endfunction

task automatic gen_ops(input xalu_in_fifo_type din, output bit [47:0] op1, output bit [47:0] op2, output bit direction);

  bit [47:0] dsp_op1, dsp_op2;
`ifndef SYNP94
  bit        shift_dir = '1;          //0 - left, 1 - right
`else  
  bit        shift_dir;          		//0 - left, 1 - right  

  shift_dir = '1;          
`endif

  // if right-shift by zero, do a left-shift by zero (special case)
  unique case(din.mode)
  c_SRL: shift_dir = |din.op2[4:0];
  c_SRA: shift_dir = |din.op2[4:0];
  default: shift_dir = 0;
  endcase

  unique case(din.mode)
  c_UMUL: begin dsp_op1 = unsigned'(din.op1); dsp_op2 = unsigned'(din.op2); end
  c_SMUL: begin dsp_op1 = signed'(din.op1); dsp_op2 = signed'(din.op2); end
  c_SRL: begin dsp_op1 = unsigned'(din.op1); dsp_op2 = shift_mul(din.op2[4:0], ~shift_dir); end
  c_SLL: begin dsp_op1 = unsigned'(din.op1); dsp_op2 = shift_mul(din.op2[4:0], ~shift_dir); end
  c_SRA: begin dsp_op1 = signed'(din.op1); dsp_op2 = shift_mul(din.op2[4:0], ~shift_dir); end
  default: begin dsp_op1 = unsigned'(din.op1); dsp_op2 = unsigned'(din.op2); end
  endcase

  op1 = dsp_op1;
  op2 = dsp_op2;
  direction = shift_dir;
endtask

module xcv5_alu_mul_shf 
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type  din,
 input  bit                en,     //input valid
 output xalu_fu_out_type   dout,
 output bit                re      //input fifo RE control   
); 
  
  bit [47:0]          op1, op2;
  bit                 dir;        //shift direction

  typedef enum bit [2:0] {m_idle, m_cycle1, m_cycle2, m_cycle3, m_cycle4} mul_state_type;
  
  typedef struct {
    xalu_obuf_type         data;       //data to be put in out buffer
    logic [NTHREADIDMSB:0]	tid;				    //thread id
    logic                  usehi;      //use hi 32-bit result    
    bit                 valid;      //result is valid
  }mul_out_reg_type;                 
  
   //signals for input fifo parity verification
   bit               op1_parity;                 //parity for OP1 
   bit               op2_parity;                 //parity for OP2
   bit               misc_parity;                //parity for misc
   
    
  xalu_in_fifo_type   rdin, vdin;                 //input registers
  
(* syn_maxfan=8 *)  mul_state_type      vstate, rstate;             //MUL FSM state
//  (* syn_maxfan=4 *)  bit [$bits(mul_state_type)-1:0] rstate;				//MUL FSM state
//    bit [$bits(mul_state_type)-1:0]      	  			vstate;             
  
  mul_state_type      d_state[0:2];               //delayed FSM state for latchin result
//  bit [$bits(mul_state_type)-1:0]      		d_state[0:2];               //delayed FSM state for latchin result
  bit                 parity_detected[0:2];       //delayed parity error
  
  mul_out_reg_type    vo, ro;                     //output registers
  
  bit                 ififo_re;                   //input FIFO control
  
  typedef enum bit [1:0] {o_idle, o_latch, o_hold}  mul_outctrl_type;     //output control state  
  mul_outctrl_type                   v_ostate, r_ostate;    //output register timing control;
//  bit [$bits(mul_outctrl_type)-1:0]                   		v_ostate, r_ostate;    //output register timing control;

  //shaped output registers
  xalu_fu_out_type    s_vo, s_ro;                 
    
  //dsp input wires
  logic [29:0]    dspA;
  logic [17:0]    dspB;
  
  //dsp output wires
  bit [47:0]    dspP;
  bit           dspZ;
  
  //registers used to balance DSP input registers and M registers
  dsp_ctrl_type vctrl, rctrl;      //dsp control registers
    
  always_comb begin
    //default values
    vdin = rdin;

    gen_ops(rdin, op1, op2, dir);    
    
    dspA = unsigned'(op1[16:0]);
    dspB = unsigned'(op2[16:0]);
    
    vstate = rstate;
    vctrl = DSP_MUL2;             //this is the most common one
    vo = ro;
    vo.data.V = '0;               //only used by div
              
    
    ififo_re = '0;                 
    
    v_ostate = r_ostate;
    s_vo     = s_ro;   
   
    //mul input FSM
    unique case(rstate)     
      m_idle:  begin
                  if (en) begin                
                    vstate = m_cycle1;
                    ififo_re = '1;
                  end
                  
                  vdin = din;           //latch result from input fifo                       
               end
      m_cycle1: begin
                dspA = unsigned'(op1[16:0]);
                dspB = unsigned'(op2[16:0]);
                vctrl = DSP_MUL1;
                
                vstate = m_cycle2;        
                end
      m_cycle2: begin
                dspA = signed'(op1[32:17]);
                dspB = unsigned'(op2[16:0]);
                vctrl = DSP_MUL2;
                
                vstate = m_cycle3;
                end
      m_cycle3: begin
                dspA = unsigned'(op1[16:0]);
                dspB = signed'(op2[32:17]);
                vctrl= DSP_MUL3;
                
                vstate = m_cycle4;
                end
      m_cycle4: begin
                dspA = signed'(op1[32:17]);
                dspB = signed'(op2[32:17]);
                vctrl = DSP_MUL4;

                vdin = din;          

                if (en) begin 
                  vstate = m_cycle1;   
                  ififo_re = '1;
                end
                else
                  vstate = m_idle;                  
                end                
/*    default : begin 
                ififo_re = '0;
                vctrl = '{'x, 'x};
                vdin  = 'x;
                dspA  = 'x;
                dspB  = 'x;
              end */
    endcase
    
    //result output FSM decoder (this is not a state machine!)
    unique case(d_state[2])
    m_cycle1 : begin
                vo.usehi = dir;       //insert pipeline registers here if necessary
                vo.tid = rdin.tid;
                vo.valid = '0;
                
                if (!dir) begin
                  vo.data.res = unsigned'(dspP[16:0]);
                  vo.data.Z = !(|dspP[16:15]) & dspZ;
                  vo.data.parity = (LUTRAMPROT)? ^dspP[16:0]: '0;
                end
                else 
                  vo.data = init_obuf_data;
               end
    m_cycle2 :    vo = ro;        
    m_cycle3 : begin                 //input fifo parity check goes here
                if (ro.usehi) begin
                  vo.data.res[1:0] = dspP[16:15];
                  vo.data.parity = (LUTRAMPROT)? ^{dspP[16:15], parity_detected[2]} : '0;
                end
                else begin
                  //vo.data.res[33:17] = dspP[16:0];
                  vo.data.res[31:17] = dspP[14:0];
                  vo.data.y.y[1:0]   = dspP[16:15];
                  vo.data.N          = vo.data.res[31];
                  vo.data.Z          = (dspZ & ro.data.Z);
                  //vo.data.parity = (LUTRAMPROT)? ^(dspP[16:0], parity_detected[1], vo.data.Z, ro.data.parity} : '0;     //this carry chain can be shared 
                  vo.data.parity     = (LUTRAMPROT)? ^{dspP[14:0], parity_detected[2], vo.data.Z, vo.data.N, ro.data.parity} : '0;   //this carry chain can be shared 
                  vo.data.y.parity   = (LUTRAMPROT) ? ^dspP[16:15] : '0;
                end
               end
    m_cycle4 : begin
                if (ro.usehi) begin
                  vo.data.res[31:2] = dspP[29:0];
                  vo.data.parity = (LUTRAMPROT)? ^{dspP[29:0], ro.data.parity} : '0;                  
                  vo.valid = '1;
                end
                else begin
                  //vo.data.res[63:34] = dspP[29:0];
                  vo.data.y.y[31:2] = dspP[29:0];
                  vo.data.y.parity = (LUTRAMPROT)? ^{dspP[29:0], ro.data.y.parity} : '0;                //part of this carry chain can be shared 
                  vo.valid = '1;
                end                
               end
    default :  begin 
                 vo.valid = '0;         //no output result by default
                 vo.tid   = 'x;
                 vo.usehi = 'x;
                 vo.data  = 'x;
               end
    endcase
    
    
    
    //output register shaping FSM
    unique case(r_ostate)
    o_idle  : if (ro.valid) begin
               v_ostate   = o_latch;
           
               s_vo.data  = ro.data;          //latch result
               s_vo.tid   = ro.tid;
           
               s_vo.valid = '1;
              end
              else
                s_vo.valid = '0;    //valid = '0;
    o_latch : v_ostate = o_hold;
    o_hold  : begin v_ostate = o_idle; s_vo.valid = '0; end
/*    default : begin 
                v_ostate = r_ostate; s_vo.valid ='0;
                s_vo.data = 'x;
                s_vo.tid  = 'x;
              end */
    endcase
    
    //output to buffer
    dout = s_ro;
    re   = ififo_re;    
  end
  
  always_ff @(posedge gclk.clk2x) begin
    
      //input registers
      rdin <= vdin;
      
      //generate parities from input FIFO
      op1_parity      <= ^{rdin.op1, rdin.op1_parity};
      op2_parity      <= ^{rdin.op2, rdin.op2_parity};
      misc_parity     <= ^{rdin.tid, rdin.mode, rdin.misc_parity};

      rctrl <= vctrl;
      
      //precision is dumb at recognizing conditional operators
      /*rstate <= (rst) ? m_idle : vstate;
          
      d_state[0] <= (rst) ? m_idle : rstate;
      d_state[1] <= (rst) ? m_idle : d_state[0];
      d_state[2] <= (rst) ? m_idle : d_state[1];
      
      parity_detected[0] <= (rst) ? '0 : op1_parity | op2_parity | misc_parity;
      parity_detected[1] <= (rst) ? '0 : parity_detected[0];
      parity_detected[2] <= (rst) ? '0 : parity_detected[1];
      */
      
      if (rst) rstate <= m_idle; else  rstate <= vstate;
          
      if (rst) d_state[0] <= m_idle; else d_state[0] <= rstate;
      if (rst) d_state[1] <= m_idle; else d_state[1] <= d_state[0];
      if (rst) d_state[2] <= m_idle; else d_state[2] <= d_state[1];
      
      if (rst) parity_detected[0] <= '0; else parity_detected[0] <= op1_parity | op2_parity | misc_parity;
      if (rst) parity_detected[1] <= '0; else parity_detected[1] <= parity_detected[0];
      if (rst) parity_detected[2] <= '0; else parity_detected[2] <= parity_detected[1];

      
      ro <= vo;

      //shape output signals and make sure it meet a posedge      
      //r_ostate <= (rst) ? o_idle : v_ostate;
      if (rst) r_ostate <= o_idle; else r_ostate <= v_ostate;
      s_ro <= s_vo;
  end
    

 DSP48E #(
        .ALUMODEREG(1),
        .AREG(1),
        .BREG(1),
        .CARRYINREG(0),
        .CARRYINSELREG(1),
        .CREG(0),
        .MASK(48'hFFFFFFFF8000),        //only test the lowest 15 bit
        .MREG(1),
        .OPMODEREG(1),
        .PATTERN(48'h000000000000),
        .PREG(1),
        .SEL_MASK("MASK"),
        .SEL_PATTERN("PATTERN"),
        .USE_MULT("MULT_S"),
        .USE_PATTERN_DETECT("PATDET"),
        .USE_SIMD("ONE48")
        )
   dsp_mul(
        .A(dspA), 
        .B(dspB),
        .ALUMODE(rctrl.alumode),
        .CARRYIN(1'b0),
        .CARRYINSEL(3'b0),
        .CEA1(1'b0),
        .CEA2(1'b1),		
        .CEALUMODE(1'b1),
        .CEB1(1'b0),
        .CEB2(1'b1),	
        .CEC(1'b0),
        .CECARRYIN(1'b0),
        .CECTRL(1'b1),
        .CEM(1'b1),
        .CEMULTCARRYIN(1'b0),	
        .CEP(1'b1),
        .CLK(gclk.clk2x),			//2x clock
        .OPMODE(rctrl.opmode),
        .RSTA(rst),
        .RSTALLCARRYIN(rst),
        .RSTALUMODE(rst),
        .RSTB(rst),
        .RSTC(rst),
        .RSTCTRL(rst),
        .RSTP(rst),
        .RSTM(1'b0),
        .P(dspP),
        .PATTERNDETECT(dspZ),
        //unconnected ports
        .C(),
        .ACIN(),
        .BCIN(),
        .CARRYCASCIN(),
        .MULTSIGNIN(),
        .PCIN(),
        .ACOUT(),
        .BCOUT(),
        .CARRYCASCOUT(),
        .CARRYOUT(),
        .MULTSIGNOUT(),
        .OVERFLOW(),
        .PATTERNBDETECT(),
        .PCOUT(),
        .UNDERFLOW()	
        );	
endmodule

//high performance multiple implementation using 4 DSP48Es.
module xcv5_alu_mul_shf_fast
(input  iu_clk_type gclk, input bit rst, 
 input  xalu_in_fifo_type  din,
 output xalu_fu_out_type   dout
); 

bit [47:0]          op1, op2;
bit                 shf_dir, r_shf_dir;

//dsp signals
bit [29:0] dspA_lo, dspA_hi;
bit [17:0] dspB_lo, dspB_hi, dspB_lo_cas, dspB_hi_cas;
bit [1:0]	 dspZ;
bit [47:0] dspP[0:3], dspP_cas[0:2];

bit [63:0]  P;

//pipeline registers (can be shared)

always_comb begin

  gen_ops(din, op1, op2, shf_dir);    
  
  
  //dsp signals
  dspA_lo = unsigned'(op1[16:0]);
  dspA_hi = signed'(op1[32:17]);
  
  dspB_lo = unsigned'(op2[16:0]);
  dspB_hi = signed'(op2[32:17]);        

  //output signals
  P = {dspP[3][29:0],dspP[2][16:0],dspP[0][16:0]};
  
  dout.tid   = '0;    //not used
  dout.valid = '1;    //always valid;
  dout.data.V = '0;

  dout.data.res = (r_shf_dir) ? P[63:32] : P[31:0];
  dout.data.y.y = P[63:32];
  dout.data.N  = P[31];
  dout.data.Z  = &dspZ;
     
  //parity
  dout.data.parity  = '0;   //not used (no LUTRAM here)
  dout.data.y.parity = (LUTRAMPROT) ? ^dout.data.y.y : '0;  
end

always_ff @(posedge gclk.clk) begin
  r_shf_dir <= shf_dir;
end

DSP48E #(
     .ALUMODEREG(0),
     .AREG(0),
     .BREG(0),
     .ACASCREG(0),
     .BCASCREG(0),     
     .CARRYINREG(0),
     .CARRYINSELREG(0),
     .CREG(0),
     .MASK(48'hFFFFFFFE0000),        //only test the lowest 17 bit
     .MREG(1),
     .OPMODEREG(0),
     .PATTERN(48'h000000000000),
     .PREG(0),
     .SEL_MASK("MASK"),
     .SEL_PATTERN("PATTERN"),
     .USE_MULT("MULT_S"),
     .USE_PATTERN_DETECT("PATDET"),
     .USE_SIMD("ONE48")
     )
dsp_mul_0(
     .A(dspA_lo), 
     .B(dspB_lo),
     .ALUMODE(4'b0),
     .CARRYIN(1'b0),
     .CARRYINSEL(3'b0),
     .CEA1(1'b0),
     .CEA2(1'b1),		
     .CEALUMODE(1'b1),
     .CEB1(1'b0),
     .CEB2(1'b1),	
     .CEC(1'b0),
     .CECARRYIN(1'b0),
     .CECTRL(1'b1),
     .CEM(1'b1),
     .CEMULTCARRYIN(1'b0),	
     .CEP(1'b1),
     .CLK(gclk.clk),
     .OPMODE(7'b0000101),
     .RSTA(),
     .RSTALLCARRYIN(),
     .RSTALUMODE(),
     .RSTB(),
     .RSTC(),
     .RSTCTRL(),
     .RSTP(),
     .RSTM(rst),
     .P(dspP[0]),
     .PATTERNDETECT(dspZ[0]),
     .BCOUT(dspB_lo_cas),
     .PCOUT(dspP_cas[0]),
     //unconnected ports
     .ACOUT(),
     .C(),
     .ACIN(),
     .BCIN(),
     .CARRYCASCIN(),
     .MULTSIGNIN(),
     .PCIN(),
     .CARRYCASCOUT(),
     .CARRYOUT(),
     .MULTSIGNOUT(),
     .OVERFLOW(),
     .PATTERNBDETECT(),
     .UNDERFLOW()	
     );	


DSP48E #(
     .ALUMODEREG(0),
     .AREG(0),
     .BREG(0),
     .ACASCREG(0),
     .BCASCREG(0),
     .B_INPUT("CASCADE"),
     .CARRYINREG(0),
     .CARRYINSELREG(0),
     .CREG(0),
     .MASK(48'hFFFFFFFC0000),        //only test the lowest 18 bit
     .MREG(1),
     .OPMODEREG(0),
     .PATTERN(48'h000000000000),
     .PREG(0),
     .SEL_MASK("MASK"),
     .SEL_PATTERN("PATTERN"),
     .USE_MULT("MULT_S"),
     .USE_PATTERN_DETECT("NO_PATDET"),
     .USE_SIMD("ONE48")
     )
dsp_mul_1(
     .A(dspA_hi), 
     .B(),
     .BCIN(dspB_lo_cas),
     .ALUMODE(4'b0),
     .CARRYIN(1'b0),
     .CARRYINSEL(3'b0),
     .CEA1(1'b0),
     .CEA2(1'b1),		
     .CEALUMODE(1'b1),
     .CEB1(1'b0),
     .CEB2(1'b1),	
     .CEC(1'b0),
     .CECARRYIN(1'b0),
     .CECTRL(1'b1),
     .CEM(1'b1),
     .CEMULTCARRYIN(1'b0),	
     .CEP(1'b1),
     .CLK(gclk.clk),
     .OPMODE(7'b1010101),
     .RSTA(),
     .RSTALLCARRYIN(),
     .RSTALUMODE(),
     .RSTB(),
     .RSTC(),
     .RSTCTRL(),
     .RSTP(),
     .RSTM(rst),
     .P(dspP[1]),
     .PATTERNDETECT(),
     .ACOUT(),
     .BCOUT(),
     .PCOUT(dspP_cas[1]),
     .C(),
     .ACIN(),
     .CARRYCASCIN(),
     .MULTSIGNIN(),
     .PCIN(dspP_cas[0]),
     .CARRYCASCOUT(),
     .CARRYOUT(),
     .MULTSIGNOUT(),
     .OVERFLOW(),
     .PATTERNBDETECT(),
     .UNDERFLOW()	
     );	

DSP48E #(
     .ALUMODEREG(0),
     .AREG(0),
     .BREG(0),
     .ACASCREG(0),
     .BCASCREG(0),        
// .A_INPUT("CASCADE"),
     .CARRYINREG(0),
     .CARRYINSELREG(0),
     .CREG(0),
     .MASK(48'hFFFFFFFFC000),        //only test the lowest 14 bit
     .MREG(1),
     .OPMODEREG(0),
     .PATTERN(48'h000000000000),
     .PREG(0),
     .SEL_MASK("MASK"),
     .SEL_PATTERN("PATTERN"),
     .USE_MULT("MULT_S"),
     .USE_PATTERN_DETECT("PATDET"),
     .USE_SIMD("ONE48")
     )
dsp_mul_2(
     .A(dspA_lo), 
     .B(dspB_hi),
     .ALUMODE(4'b0),
     .CARRYIN(1'b0),
     .CARRYINSEL(3'b0),
     .CEA1(1'b0),
     .CEA2(1'b1),		
     .CEALUMODE(1'b1),
     .CEB1(1'b0),
     .CEB2(1'b1),	
     .CEC(1'b0),
     .CECARRYIN(1'b0),
     .CECTRL(1'b1),
     .CEM(1'b1),
     .CEMULTCARRYIN(1'b0),	
     .CEP(1'b1),
     .CLK(gclk.clk),
     .OPMODE(7'b0010101),
     .RSTA(),
     .RSTALLCARRYIN(),
     .RSTALUMODE(),
     .RSTB(),
     .RSTC(),
     .RSTCTRL(),
     .RSTP(),
     .RSTM(rst),
     .P(dspP[2]),
     .PATTERNDETECT(dspZ[1]),
     .ACOUT(),
     .BCOUT(dspB_hi_cas),
     .PCIN(dspP_cas[1]),
     .PCOUT(dspP_cas[2]),
     //unconnected ports
     .ACIN(),
     .BCIN(),
     .C(),
     .CARRYCASCIN(),
     .MULTSIGNIN(),
     .CARRYCASCOUT(),
     .CARRYOUT(),
     .MULTSIGNOUT(),
     .OVERFLOW(),
     .PATTERNBDETECT(),
     .UNDERFLOW()	
     );	


DSP48E #(
     .ALUMODEREG(0),
     .AREG(0),
     .BREG(0),
     .ACASCREG(0),
     .BCASCREG(0),        
     .B_INPUT("CASCADE"),
     .CARRYINREG(0),
     .CARRYINSELREG(0),
     .CREG(0),
     .MASK(48'hFFFFFFFFC000),        
     .MREG(1),
     .OPMODEREG(0),
     .PATTERN(48'h000000000000),
     .PREG(0),
     .SEL_MASK("MASK"),
     .SEL_PATTERN("PATTERN"),
     .USE_MULT("MULT_S"),
     .USE_PATTERN_DETECT("NO_PATDET"),
     .USE_SIMD("ONE48")
     )
dsp_mul_3(
     .A(dspA_hi), 
     .B(),
     .ACIN(),
     .BCIN(dspB_hi_cas),
     .ALUMODE(4'b0),
     .CARRYIN(1'b0),
     .CARRYINSEL(3'b0),
     .CEA1(1'b0),
     .CEA2(1'b1),		
     .CEALUMODE(1'b1),
     .CEB1(1'b0),
     .CEB2(1'b1),	
     .CEC(1'b0),
     .CECARRYIN(1'b0),
     .CECTRL(1'b1),
     .CEM(1'b1),
     .CEMULTCARRYIN(1'b0),	
     .CEP(1'b1),
     .CLK(gclk.clk),
     .OPMODE(7'b1010101),
     .RSTA(),
     .RSTALLCARRYIN(),
     .RSTALUMODE(),
     .RSTB(),
     .RSTC(),
     .RSTCTRL(),
     .RSTP(),
     .RSTM(rst),
     .P(dspP[3]),
     .PATTERNDETECT(),
     .ACOUT(),
     .BCOUT(),
     .PCIN(dspP_cas[2]),
     .PCOUT(),
     //unconnected ports
     .C(),
     .CARRYCASCIN(),
     .MULTSIGNIN(),
     .CARRYCASCOUT(),
     .CARRYOUT(),
     .MULTSIGNOUT(),
     .OVERFLOW(),
     .PATTERNBDETECT(),
     .UNDERFLOW()	
     );	
endmodule 