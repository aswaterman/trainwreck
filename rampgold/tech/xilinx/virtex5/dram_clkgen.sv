//---------------------------------------------------------------------------   
// File:        dram_clkgen.v
// Author:      Zhangxi Tan
// Description: Generate dram clk & rst for Xilinx virtex5. Support MIG/BEE3 
//              mem controllers now
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libtech::*;
`else
`include "../../libtech.sv"
`endif


module xcv5_dram_clkgen_mig #(parameter CLKMUL = 8, parameter CLKDIV = 3, parameter CLKDIV200 = 4, parameter CLKIN_PERIOD = 10.0) 
                        (input bit clkin, input bit rstin, input bit dramrst, output dram_clk_type ram_clk);

        bit		locked;                      //locked, used for rst200

        wire	pll_clk0, pll_clk0_b;			         //clk0 of PLL
        wire pll_clk90, pll_clk90_b;          //clk90 
        wire	pll_clkdiv0, pll_clkdiv0_b;      //clkdiv0
        wire pll_clk200, pll_clk200_b;        //clk 200 MHz
        
        wire	pll_fb, pll_fb_b;                //pllfb
        
        bit   rst_tmp;
          
        // # of clock cycles to delay deassertion of reset. Needs to be a fairly
        // high number not so much for metastability protection, but to give time
        // for reset (i.e. stable clock cycles) to propagate through all state
        // machines and to all control signals (i.e. not all control signals have
        // resets, instead they rely on base state logic being reset, and the effect
        // of that reset propagating through the logic). Need this because we may not
        // be getting stable clock cycles while reset asserted (i.e. since reset
        // depends on DCM lock status)
        localparam RST_SYNC_NUM = 25;
        
        bit [RST_SYNC_NUM-1:0]     rst0_sync_r    /* synthesis syn_maxfan = 10 */;
        bit [RST_SYNC_NUM-1:0]     rst200_sync_r  /* synthesis syn_maxfan = 10 */;
        bit [RST_SYNC_NUM-1:0]     rst90_sync_r   /* synthesis syn_maxfan = 10 */;
        bit [(RST_SYNC_NUM/2)-1:0] rstdiv0_sync_r /* synthesis syn_maxfan = 10 */;
      
        
        BUFG  pll_clk0_buf(.O(pll_clk0_b), .I(pll_clk0));
        BUFG  pll_clk90_buf(.O(pll_clk90_b), .I(pll_clk90));
        BUFG  pll_clkdiv0_buf(.O(pll_clkdiv0_b), .I(pll_clkdiv0));
//        BUFG  pll_fb_buf(.O(pll_fb_b), .I(pll_fb));
        BUFG  pll_clk200_buf(.O(pll_clk200_b), .I(pll_clk200));
        

//        assign ram_clk.mig.clk200  = clkin;        //assume clkin is 200 MHz, otherwise write customized clkgen model to overide this signal
        assign ram_clk.mig.clk200  = pll_clk200_b;        //assume clkin is 200 MHz, otherwise write customized clkgen model to overide this signal
        assign ram_clk.mig.clk0    = pll_clk0_b;
        assign ram_clk.mig.clk90   = pll_clk90_b;
        assign ram_clk.mig.clkdiv0 = pll_clkdiv0_b;
        
        PLL_BASE #(
                .BANDWIDTH("OPTIMIZED"),      // "HIGH", "LOW" or "OPTIMIZED"
                .CLKFBOUT_MULT(CLKMUL),       // Multiplication factor for all output clocks
                .CLKFBOUT_PHASE(0.0),         // Phase shift (degrees) of all output clocks
                .CLKIN_PERIOD(CLKIN_PERIOD),  // Clock period (ns) of input clock on CLKIN

                .CLKOUT0_DIVIDE(CLKDIV),      // Division factor for CLK0 (1 to 128)
                .CLKOUT0_DUTY_CYCLE(0.5),     // Duty cycle for CLKOUT0 (0.01 to 0.99)
                .CLKOUT0_PHASE(0.0),          // Phase shift (degrees) for CLKOUT0 (0.0 to 360.0)

                .CLKOUT1_DIVIDE(CLKDIV),      // Division factor for CLK90 (1 to 128)
                .CLKOUT1_DUTY_CYCLE(0.5),     // Duty cycle for CLKOUT1 (0.01 to 0.99)
                .CLKOUT1_PHASE(90.0),         // Phase shift (degrees) for CLKOUT1 (0.0 to 360.0)

                .CLKOUT2_DIVIDE(CLKDIV*2),    // Division factor for CLKDIV0 (1 to 128)
                .CLKOUT2_DUTY_CYCLE(0.5),     // Duty cycle for CLKOUT2 (0.01 to 0.99)
                .CLKOUT2_PHASE(0.0),          // Phase shift (degrees) for CLKOUT2 (0.0 to 360.0)
                
                .CLKOUT3_DIVIDE(CLKDIV200),   // Division factor for CLK2000 (1 to 128)
                .CLKOUT3_DUTY_CYCLE(0.5),     // Duty cycle for CLKOUT3 (0.01 to 0.99)
                .CLKOUT3_PHASE(0.0),          // Phase shift (degrees) for CLKOUT2 (0.0 to 360.0)


                .COMPENSATION("SYSTEM_SYNCHRONOUS"), // "SYSTEM_SYNCHRONOUS",
                .DIVCLK_DIVIDE(1), // Division factor for all clocks (1 to 52)
                .REF_JITTER(0.100) // Input reference jitter (0.000 to 0.999 UI%)

            ) clkBPLL (
                .CLKFBOUT(pll_fb),     // General output feedback signal
                .CLKOUT0(pll_clk0),    // 200+MHz
                .CLKOUT1(pll_clk90),   // 200+MHz, 90 degree shift
                .CLKOUT2(pll_clkdiv0), // clk0/2
                .CLKOUT3(pll_clk200),
                .CLKOUT4(), 
                .CLKOUT5(),
                .LOCKED(locked),     // Active high PLL lock signal
                .CLKFBIN(pll_fb),  // Clock feedback input
                .CLKIN(clkin),       // Clock input
                .RST(rstin)
          );


          assign rst_tmp = rstin | dramrst | ~locked;

          always_ff @(posedge pll_clk0_b or posedge rst_tmp)
            if (rst_tmp)
              rst0_sync_r <= '1;
            else
              // logical right shift by one (pads with 0)
              rst0_sync_r <= rst0_sync_r >> 1;

          always_ff @(posedge pll_clkdiv0_b or posedge rst_tmp)
            if (rst_tmp)
              rstdiv0_sync_r <= '1;
            else
            // logical right shift by one (pads with 0)
              rstdiv0_sync_r <= rstdiv0_sync_r >> 1;

          always_ff @(posedge pll_clk90_b or posedge rst_tmp)
            if (rst_tmp)
              rst90_sync_r <= '1;
            else
              rst90_sync_r <= rst90_sync_r >> 1;

          // make sure CLK200 doesn't depend on IDELAY_CTRL_RDY, else chicken n' egg

         always_ff @(posedge pll_clk200_b or negedge locked)
          if (!locked)
            rst200_sync_r <= '1;
          else
            rst200_sync_r <= rst200_sync_r >> 1;


         assign ram_clk.mig.rst0    = rst0_sync_r[0];
         assign ram_clk.mig.rst90   = rst90_sync_r[0];
         assign ram_clk.mig.rst200  = rst200_sync_r[0];
         assign ram_clk.mig.rstdiv0 = rstdiv0_sync_r[0];

endmodule

module xcv5_dram_clkgen_bee3 #(parameter CLKMUL = 8, parameter CLKDIV = 3, parameter PLLDIV = 1, parameter CLKIN_PERIOD = 10.0,  parameter BOARDSEL = 1) 
                        (input bit clkin, input bit rstin, input bit clk200, output dram_clk_type ram_clk);
  wire CLK;
  wire MCLK; 
  wire MCLK90;
  wire Ph0; //MCLK / 4
  wire CLKx;
  wire MCLKx;
  wire MCLK90x;
  wire Ph0x;
  wire PLLBfb;
  wire allLock;
  wire ctrlLock;
  
  bit [2:0] ctrlLockx;
  
                       
  //This PLL generates MCLK and MCLK90 at whatever frequency we want.
  PLL_BASE #(
  .BANDWIDTH("OPTIMIZED"),     // "HIGH", "LOW" or "OPTIMIZED"
  .CLKFBOUT_MULT(CLKMUL),      // Multiplication factor for all output clocks
  .CLKFBOUT_PHASE(0.0),        // Phase shift (degrees) of all output clocks
  .CLKIN_PERIOD(CLKIN_PERIOD), // Clock period (ns) of input clock on CLKIN

  .CLKOUT0_DIVIDE(CLKDIV), // Division factor for MCLK (1 to 128)
  .CLKOUT0_DUTY_CYCLE(0.5), // Duty cycle for CLKOUT0 (0.01 to 0.99)
  .CLKOUT0_PHASE(0.0), // Phase shift (degrees) for CLKOUT0 (0.0 to 360.0)

  .CLKOUT1_DIVIDE(CLKDIV), // Division factor for MCLK90 (1 to 128)
  .CLKOUT1_DUTY_CYCLE(0.5), // Duty cycle for CLKOUT1 (0.01 to 0.99)
  .CLKOUT1_PHASE(90.0), // Phase shift (degrees) for CLKOUT1 (0.0 to 360.0)

  .CLKOUT2_DIVIDE(CLKDIV * 4), // Division factor for Ph0 (1 to 128)
  .CLKOUT2_DUTY_CYCLE(0.375), // Duty cycle for CLKOUT2 (0.01 to 0.99)
  .CLKOUT2_PHASE(0.0), // Phase shift (degrees) for CLKOUT2 (0.0 to 360.0)

  .CLKOUT3_DIVIDE(1), // Division factor for CLKOUT3 (1 to 128)
  .CLKOUT3_DUTY_CYCLE(0.5), // Duty cycle for CLKOUT3 (0.01 to 0.99)
  .CLKOUT3_PHASE(0.0), // Phase shift (degrees) for CLKOUT3 (0.0 to 360.0)

  .CLKOUT4_DIVIDE(CLKDIV * 2), // Division factor for CLK (1 to 128)
  .CLKOUT4_DUTY_CYCLE(0.5), // Duty cycle for CLKOUT4 (0.01 to 0.99)
  .CLKOUT4_PHASE(0.0), // Phase shift (degrees) for CLKOUT4 (0.0 to 360.0)

  .CLKOUT5_DIVIDE(1), // Division factor for CLKOUT5 (1 to 128)
  .CLKOUT5_DUTY_CYCLE(0.5), // Duty cycle for CLKOUT5 (0.01 to 0.99)
  .CLKOUT5_PHASE(0.0), // Phase shift (degrees) for CLKOUT5 (0.0 to 360.0)

  .COMPENSATION("SYSTEM_SYNCHRONOUS"), // "SYSTEM_SYNCHRONOUS",
  .DIVCLK_DIVIDE(PLLDIV), // Division factor for all clocks (1 to 52)
  .REF_JITTER(0.100) // Input reference jitter (0.000 to 0.999 UI%)


  ) clkBPLL (
  .CLKFBOUT(PLLBfb), // General output feedback signal
  .CLKOUT0(MCLKx), // 200+MHz
  .CLKOUT1(MCLK90x), // 200+MHz, 90 degree shift
  .CLKOUT2(Ph0x), // MCLK/4
  .CLKOUT3(),
  .CLKOUT4(CLKx), // MCLK/2
  .CLKOUT5(),
  .LOCKED(allLock), // Active high PLL lock signal
  .CLKFBIN(PLLBfb), // Clock feedback input
  .CLKIN(clkin), // Clock input
  .RST(rstin)
  );
 bit Reset;
 
 localparam RST_SYNC_NUM = 25;
        
 bit [RST_SYNC_NUM-1:0]     rst0_sync_r    /* synthesis syn_maxfan = 20 */;
 bit						rst0_sync_TC5  /* synthesis syn_maxfan = 20 */;
 
 BUFG bufc (.O(CLK), .I(CLKx));
 BUFG bufM (.O(MCLK), .I(MCLKx));
 BUFG bufM90 (.O(MCLK90), .I(MCLK90x));
 BUFG p0buf(.O(Ph0), .I(Ph0x));
  
  
 assign Reset = rstin  | ~allLock | ~ctrlLock;

 always_ff @(posedge MCLK or posedge Reset)  begin 
    if (Reset)
      rst0_sync_r <= '1;
    else
      rst0_sync_r <=  rst0_sync_r >> 1;
 end
 
 always_ff @(posedge Ph0) rst0_sync_TC5 <= rst0_sync_r[0];

generate
 case (BOARDSEL)
 default :	begin	//ML505/XUP
 assign ctrlLock = &ctrlLockx;
//instantiate an idelayctrl.
 IDELAYCTRL idelayctrl0 (
  .RDY(ctrlLockx[0]),
`ifdef MODEL_TECH
  .REFCLK(MCLK), 
`else  
  .REFCLK(clk200),
`endif
  .RST(~allLock)
  ) /* synthesis xc_loc = "IDELAYCTRL_X0Y6"*/;    

 IDELAYCTRL idelayctrl1 (
  .RDY(ctrlLockx[1]),
`ifdef MODEL_TECH
  .REFCLK(MCLK), 
`else  
  .REFCLK(clk200),
`endif
  .RST(~allLock)
  )/* synthesis xc_loc = "IDELAYCTRL_X0Y1" */;    

 IDELAYCTRL idelayctrl2 (
  .RDY(ctrlLockx[2]),
`ifdef MODEL_TECH
  .REFCLK(MCLK), 
`else  
  .REFCLK(clk200),
`endif
  .RST(~allLock)
  ) /* synthesis xc_loc = "IDELAYCTRL_X0Y2"*/;    
 end     
 endcase                
 endgenerate

  assign  ram_clk.bee3.mclk   = MCLK;
  assign  ram_clk.bee3.mclk90 = MCLK90;
  assign  ram_clk.bee3.clk    = CLK;
  assign  ram_clk.bee3.ph0    = Ph0;
  assign  ram_clk.bee3.rst    = rst0_sync_r[0];
  assign  ram_clk.bee3.rstTC5 = rst0_sync_TC5;
endmodule