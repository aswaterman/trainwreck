//---------------------------------------------------------------------------   
// File:        dramctrl_bee3.sv
// Author:      Zhangxi Tan
// Description: Instantiate BEE3 mem controller for ML505/BEE3 for dual-rank 
//		2GB dimms
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SYNP94
import libtech::*;
`else
`include "../../libtech.sv"
`endif


module dramctrl_bee3_ml505 #(parameter bit REFRESHINHIBIT = 1'b1, parameter no_ecc_data_path = "FALSE")( 
 //dram clock
 input dram_clk_type            ram_clk,   //dram clock
 //signals to cpu
 mem_controller_interface.dram  user_if,
 
 //Signals to SODIMM
 inout [63:0]   DQ, //the 64 DQ pins
 inout [7:0]    DQS, //the 8  DQS pins
 inout [7:0]    DQS_L,
 output [1:0]   DIMMCK,  //differential clock to the DIMM
 output [1:0]   DIMMCKL,
 output [13:0]  A, //addresses to DIMMs
 output [2:0]   BA, //bank address to DIMMs
 output         RAS,
 output         CAS,
 output         WE,
 output [1:0]   ODT,
 output [1:0]   ClkEn, //common clock enable for both DIMMs. SSTL1_8
 output [1:0]   RS,
 output [7:0]   DM,
 
 //extra signals needed by bee3
 output         TxD,        	    //RS232 transmit data
 input          RxD,        	    //RS232 received data
 output         SingleError,       //Single errors
 output		DoubleError	    //Double errors
 );


//wire SingleError;  //goes to tester 
//wire DoubleError;  //goes to tester

wire ResetDDR; 
wire RxDin;
//(* syn_maxfan = 20 *) reg Reset;

wire StartDQCal0;

//TC5 interface signals
wire [35:0] LastALU;
wire injectTC5address;
wire CalFailed;
wire InhibitDDR;
wire Force;
wire DDRclockEnable;
wire RBfullx;
//reg RBfull;
//wire Reading;

//--------------------End of Declarations-------------------------------

always_ff @(posedge ram_clk.bee3.clk) user_if.RBfull <= RBfullx;

//Instantiate the TC5
TC5 TC5x(.Ph0(ram_clk.bee3.ph0), .ResetIn(ram_clk.bee3.rstTC5), .TxD(TxD), .RxD(RxDin),
   .StartDQCal0(StartDQCal0), .LastALU(LastALU), .injectTC5address(injectTC5address),
   .CalFailed(CalFailed), .InhibitDDR(InhibitDDR), .Force(Force), .DDRcke(DDRclockEnable), .ResetDDR(ResetDDR),
   .HoldFail(1'b0), .Start(), .testConf(), .Select(), .Which(1'b0),
   .TakeXD(), .XDbyte(8'd0), .SCL(), .SDA(), .SDAin(1'b0)
 );

  
//Instantiate the DDR2 controller
ddrController #(.REFRESHINHIBIT(REFRESHINHIBIT), .no_ecc_data_path(no_ecc_data_path)) ddr(
.CLK(ram_clk.bee3.clk),
.MCLK(ram_clk.bee3.mclk),
.MCLK90(ram_clk.bee3.mclk90),
.ResetDDR(ResetDDR),
.Reset(ram_clk.bee3.rst),
.CalFailed(CalFailed),
.DDRclockEnable(DDRclockEnable),
.Address(user_if.Address),
.Read(user_if.Read),
.ReadData(user_if.ReadData),
.WriteData(user_if.WriteData),

.DQ(DQ), //the 64 DQ pins
.DQS(DQS), //the 8  DQS pins
.DQS_L(DQS_L),
.DIMMCK(DIMMCK),  //differential clock to the two DIMMs
.DIMMCKL(DIMMCKL),
.A(A), //addresses to DIMMs
.DM(DM),
.BA(BA), //bank address to DIMMs
.RAS(RAS),
.CAS(CAS),
.WE(WE),
.RS(RS),
.ODT(ODT),  //two ODTs, one for each DIMM
.ClkEn(ClkEn), //common clock enable for both DIMMs. SSTL1_8
.StartDQCal0(StartDQCal0),
.LastALU(LastALU),
.injectTC5address(injectTC5address),
.InhibitDDR(InhibitDDR),
.Force(Force),
.SingleError(SingleError),
.DoubleError(DoubleError),
.RBempty(user_if.RBempty),
.RBfull(RBfullx),
.ReadRB(user_if.ReadRB),
.WBfull(user_if.WBfull),
.WriteWB(user_if.WriteWB),
.WBclock(user_if.WBclock),
.RBclock(user_if.RBclock),
.AFclock(user_if.AFclock),
.WriteAF(user_if.WriteAF),
.AFfull(user_if.AFfull)
);


//Pin buffer for RxD
  IBUF rsbuf(.I(RxD), .O(RxDin));

endmodule

module dramctrl_bee3 #(parameter bit REFRESHINHIBIT = 1'b1, parameter bit SINGLEMODULE= 1'b1, parameter WRITEECC="TRUE", parameter no_ecc_data_path = "FALSE")( 
 //dram clock
 input dram_clk_type            ram_clk,   //dram clock
 //signals to cpu
 mem_controller_interface.dram  user_if,
 
 //Signals to SODIMM
 inout [71:0]   DQ, //the 72 DQ pins
 inout [17:0]    DQS, //the 18  DQS pins
 inout [17:0]    DQS_L,
 output [1:0]   DIMMCK,  //differential clock to the DIMM
 output [1:0]   DIMMCKL,
 output         DIMMreset,  //low true
 output [13:0]  A, //addresses to DIMMs
 output [2:0]   BA, //bank address to DIMMs
 output         RAS,
 output         CAS,
 output         WE,
 output [1:0]   ODT,
 output    		ClkEn, //common clock enable for both DIMMs. SSTL1_8
 output [3:0]   RS,
 
 //extra signals needed by bee3
 output         TxD,        	    //RS232 transmit data, only used for debugging
 input          RxD,        	    //RS232 received data, only used for debugging
 output         SingleError,       //Single errors
 output			DoubleError	    //Double errors
 );


//wire SingleError;  //goes to tester 
//wire DoubleError;  //goes to tester

wire ResetDDR; 
wire RxDin;
//(* syn_maxfan = 20 *) reg Reset;

wire StartDQCal0;

//TC5 interface signals
wire [35:0] LastALU;
wire injectTC5address;
wire CalFailed;
wire InhibitDDR;
wire Force;
wire DDRclockEnable;
wire RBfullx;
wire KillRank3;

wire [143:0] ReadData, WriteData;
//reg RBfull;
//wire Reading;

//--------------------End of Declarations-------------------------------

always_ff @(posedge ram_clk.bee3.clk) user_if.RBfull <= RBfullx;

//Instantiate the TC5
TC5 TC5x(.Ph0(ram_clk.bee3.ph0), .ResetIn(ram_clk.bee3.rstTC5), .TxD(TxD), .RxD(RxDin),
   .StartDQCal0(StartDQCal0), .LastALU(LastALU), .injectTC5address(injectTC5address),
   .CalFailed(CalFailed), .InhibitDDR(InhibitDDR), .Force(Force), .DDRcke(DDRclockEnable), .ResetDDR(ResetDDR), .KillRank3,
   .HoldFail(1'b0), .Start(), .testConf(), .Select(), .Which(1'b0),
   .TakeXD(), .XDbyte(8'd0), .SCL(), .SDA(), .SDAin(1'b0)
 );

assign user_if.ReadData = ReadData;
assign WriteData = user_if.WriteData;
  
//Instantiate the DDR2 controller
ddrController #(.REFRESHINHIBIT(REFRESHINHIBIT), .SINGLEMODULE(SINGLEMODULE), .WRITEECC(WRITEECC), .no_ecc_data_path(no_ecc_data_path)) ddr(
.CLK(ram_clk.bee3.clk),
.MCLK(ram_clk.bee3.mclk),
.MCLK90(ram_clk.bee3.mclk90),
.ResetDDR(ResetDDR),
.Reset(ram_clk.bee3.rst),
.CalFailed(CalFailed),
.DDRclockEnable(DDRclockEnable),
.Address(user_if.Address),
.Read(user_if.Read),
.ReadData(ReadData),
.WriteData(WriteData),

.DQ(DQ), //the 72 DQ pins
.DQS(DQS), //the 18  DQS pins
.DQS_L(DQS_L),
.DIMMCK(DIMMCK),  //differential clock to the two DIMMs
.DIMMCKL(DIMMCKL),
.A(A), //addresses to DIMMs
.BA(BA), //bank address to DIMMs
.RAS(RAS),
.CAS(CAS),
.WE(WE),
.RS(RS),
.ODT(ODT),  //two ODTs, one for each DIMM
.ClkEn(ClkEn), //common clock enable for both DIMMs. SSTL1_8
.DIMMreset,
.StartDQCal0(StartDQCal0),
.LastALU(LastALU),
.injectTC5address(injectTC5address),
.InhibitDDR(InhibitDDR),
.KillRank3(KillRank3),     
.Force(Force),
.SingleError(SingleError),
.DoubleError(DoubleError),
.RBempty(user_if.RBempty),
.RBfull(RBfullx),
.ReadRB(user_if.ReadRB),
.WBfull(user_if.WBfull),
.WriteWB(user_if.WriteWB),
.WBclock(user_if.WBclock),
.RBclock(user_if.RBclock),
.AFclock(user_if.AFclock),
.WriteAF(user_if.WriteAF),
.AFfull(user_if.AFfull)
);


//Pin buffer for RxD
  IBUF rsbuf(.I(RxD), .O(RxDin));

endmodule