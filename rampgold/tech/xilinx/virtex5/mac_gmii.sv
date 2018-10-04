//-------------------------------------------------------------------------------------------------  
// File:        mac_gmii.sv
// Author:      Zhangxi Tan 
// Description: Virtex 5 Gigabit MAC, clocking scheme from Microsoft BEEhive
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef SYNP94
import libeth::*;
`else
`include "../../../eth/libeth.sv"
`endif


module xcv5_mac_gmii #(parameter CLKMUL = 5, parameter CLKDIV = 4,  parameter CLKIN_PERIOD = 10.0, parameter BOARDSEL=1) 
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
)/* synthesis syn_sharing=on */;
  
  localparam  FIFORSTSHIFTMSB = 31;
  
  // Reset stuff ...
  (* syn_srlstyle="select_srl" *) bit [FIFORSTSHIFTMSB:0] fifo_rst;
  (* syn_maxfan=1000000 *)        bit eth_rst;
  bit       rst;
  bit [3:0] eth_rst_dly;
  
  // DCM internal signals
  bit            dfs_clkfx;
  bit [3:0]      dfs_rst_dly;
  
  // idelay signals
  bit [1:0]      ctrlLockx;
  bit            ctrlLock;
  
  // ethernet clocks
  bit            ethTXclock;
  bit            ethRXclock;
  
  bit            TX_EN_FROM_MAC;
  bit            TX_ER_FROM_MAC;
  bit [7:0]      TXD_FROM_MAC;

  (* syn_useioff=1 *) bit [7:0] RXdataDelayReg;
  (* syn_useioff=1 *) bit       RXdvDelayReg, RXerDelayReg;

  bit            RXclockDelay;
  bit [7:0]      RXdataDelay;
  bit            RXdvDelay, RXerDelay;
  
  bit [15:0]     RXmacData;
  bit [7:0]      RXdata;
  bit            RXdataValid;
  bit            RXgoodFrame;
  bit            RXbadFrame;
   
  bit [7:0]      TXdata;
  bit            TXdataValid;
  bit            TXack;

  // rxq

  bit rxq_full;
  bit rxq_empty;

  bit rxq_enq_clk;
  bit [63:0] rxq_enq_bits;
  bit [7:0] rxq_enq_aux_bits;
  bit rxq_enq_val;
  bit rxq_enq_rdy;

  bit rxq_deq_clk;
  bit [63:0] rxq_deq_bits;
  bit [7:0] rxq_deq_aux_bits;
  bit rxq_deq_val;
  bit rxq_deq_rdy;

  assign rxq_enq_clk = ethRXclock;
  assign rxq_deq_clk = ring_clk;

  assign rxq_deq_rdy = rxq_rdy;

  FIFO36_72
  #(
    .DO_REG(1),       // Enable output register (0 or 1)
    .EN_SYN("FALSE"), // Specifies FIFO as Asynchronous ("FALSE")
    .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
  )
  rxq
  (
    .RST(rst),

    .WRCLK(rxq_enq_clk),
    .DI(rxq_enq_bits),
    .DIP(rxq_enq_aux_bits),
    .WREN(~rst & rxq_enq_val),
    .FULL(rxq_full),
    .ALMOSTFULL(),
    .WRCOUNT(),
    .WRERR(),

    .RDCLK(rxq_deq_clk),
    .DO(rxq_deq_bits),
    .DOP(rxq_deq_aux_bits),
    .RDEN(~rst & rxq_deq_rdy),
    .EMPTY(rxq_empty),
    .ALMOSTEMPTY(),
    .RDCOUNT(),
    .RDERR(),

    .DBITERR(),
    .SBITERR(),
    .ECCPARITY()
  );

  assign rxq_enq_rdy = ~rxq_full;
  assign rxq_deq_val = ~rxq_empty;

  assign rxq_bits = rxq_deq_bits;
  assign rxq_aux_bits = rxq_deq_aux_bits;
  assign rxq_val = rxq_deq_val;


  // rx logic

  bit reg_rx_val, next_rx_val;
  bit [2:0] reg_rx_cnt, next_rx_cnt;
  bit [63:0] reg_rx_bits, next_rx_bits;
  bit reg_rx_good;
  bit reg_rx_bad;

  always_ff @(posedge ethRXclock or posedge rst)
  begin
    if (rst)
    begin
      reg_rx_val <= '0;
      reg_rx_cnt <= '0;
      reg_rx_bits <= '0;
      reg_rx_good <= '0;
      reg_rx_bad <= '0;
    end
    else
    begin
      reg_rx_val <= next_rx_val;
      reg_rx_cnt <= next_rx_cnt;
      reg_rx_bits <= next_rx_bits;
      reg_rx_good <= RXgoodFrame;
      reg_rx_bad <= RXbadFrame;
    end
  end

  always_comb
  begin
    next_rx_val = '0;
    next_rx_cnt = reg_rx_cnt;
    next_rx_bits = reg_rx_bits;

    if (RXdataValid)
    begin
      if (reg_rx_cnt == 3'd7)
        next_rx_val = 1'b1;

      next_rx_cnt = reg_rx_cnt + 1'b1;
      case (reg_rx_cnt)
      3'd0: next_rx_bits[7:0] = RXmacData;
      3'd1: next_rx_bits[15:8] = RXmacData;
      3'd2: next_rx_bits[23:16] = RXmacData;
      3'd3: next_rx_bits[31:24] = RXmacData;
      3'd4: next_rx_bits[39:32] = RXmacData;
      3'd5: next_rx_bits[47:40] = RXmacData;
      3'd6: next_rx_bits[55:48] = RXmacData;
      3'd7: next_rx_bits[63:56] = RXmacData;
      endcase
    end

    if (RXgoodFrame || RXbadFrame)
    begin
      next_rx_val = 1'b1;
      next_rx_cnt = '0;
    end
  end

  assign rxq_enq_bits = reg_rx_bits;
  assign rxq_enq_aux_bits = {1'b0, reg_rx_good | reg_rx_bad, reg_rx_good, reg_rx_bad, 1'b0, reg_rx_cnt-1'b1};
  assign rxq_enq_val = reg_rx_val;


  // txq

  bit txq_full;
  bit txq_empty;

  bit txq_enq_clk;
  bit [63:0] txq_enq_bits;
  bit [7:0] txq_enq_aux_bits;
  bit txq_enq_val;
  bit txq_enq_rdy;

  bit txq_deq_clk;
  bit [63:0] txq_deq_bits;
  bit [7:0] txq_deq_aux_bits;
  bit txq_deq_val;
  bit txq_deq_rdy;

  assign txq_enq_clk = ring_clk;
  assign txq_deq_clk = ethTXclock;

  assign txq_enq_bits = txq_bits;
  assign txq_enq_aux_bits = txq_aux_bits;
  assign txq_enq_val = txq_val;

  FIFO36_72
  #(
    .DO_REG(1),       // Enable output register (0 or 1)
    .EN_SYN("FALSE"), // Specifies FIFO as Asynchronous ("FALSE")
    .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
  )
  txq
  (
    .RST(rst),

    .WRCLK(txq_enq_clk),
    .DI(txq_enq_bits),
    .DIP(txq_enq_aux_bits),
    .WREN(~rst & txq_enq_val),
    .FULL(txq_full),
    .ALMOSTFULL(),
    .WRCOUNT(),
    .WRERR(),

    .RDCLK(txq_deq_clk),
    .DO(txq_deq_bits),
    .DOP(txq_deq_aux_bits),
    .RDEN(~rst & txq_deq_rdy),
    .EMPTY(txq_empty),
    .ALMOSTEMPTY(),
    .RDCOUNT(),
    .RDERR(),

    .DBITERR(),
    .SBITERR(),
    .ECCPARITY()
  );

  assign txq_enq_rdy = ~txq_full;
  assign txq_deq_val = ~txq_empty;

  assign txq_rdy = txq_enq_rdy;


  // tx logic

  bit reg_tx_state, next_tx_state;
  bit [9:0] reg_tx_cnt, next_tx_cnt;

  always_ff @(posedge ethTXclock or posedge rst)
  begin
    if (rst)
    begin
      reg_tx_state <= '0;
      reg_tx_cnt <= '0;
    end
    else
    begin
      reg_tx_state <= next_tx_state;
      reg_tx_cnt <= next_tx_cnt;
    end
  end

  always_comb
  begin
    next_tx_state = reg_tx_state;
    next_tx_cnt = reg_tx_cnt;
    TXdataValid = 1'b0;
    TXdata = '0;

    if (txq_deq_val && reg_tx_cnt[2:0] <= txq_deq_aux_bits[2:0])
    begin
      if (!(reg_tx_state == 1'b0 && reg_tx_cnt[2:0] == 3'd0) || TXack)
      begin
        next_tx_state = 1'b1;
        next_tx_cnt = reg_tx_cnt + 1'b1;
      end

      TXdataValid = 1'b1;
      case (reg_tx_cnt[2:0])
      3'd0: TXdata = txq_deq_bits[7:0];
      3'd1: TXdata = txq_deq_bits[15:8];
      3'd2: TXdata = txq_deq_bits[23:16];
      3'd3: TXdata = txq_deq_bits[31:24];
      3'd4: TXdata = txq_deq_bits[39:32];
      3'd5: TXdata = txq_deq_bits[47:40];
      3'd6: TXdata = txq_deq_bits[55:48];
      3'd7: TXdata = txq_deq_bits[63:56];
      endcase
    end
    else
    begin
      next_tx_state = 1'b0;
      next_tx_cnt = '0;
    end
  end

  assign txq_deq_rdy = (reg_tx_cnt[2:0] == txq_deq_aux_bits[2:0]);

  // Details

  always_ff @(posedge clkin)
  begin
    fifo_rst <= {reset ,fifo_rst[FIFORSTSHIFTMSB:1]};     //wait for ring_clk to be stable    
  end

  assign rst = fifo_rst[0];

  always_ff @(posedge clkin or posedge reset)
  begin
    if (reset)
      dfs_rst_dly <= '1;
    else
      dfs_rst_dly <= dfs_rst_dly >> 1;                    //this shift register can be shared with other DCM modules
  end

  always_ff @(posedge ring_clk or posedge rst)
  begin
    if (rst)
      eth_rst_dly <= '1;
    else
      eth_rst_dly <= eth_rst_dly >> 1;
  end  

  BUFG eth_rst_buf(.O(eth_rst), .I(eth_rst_dly[0]));

  assign ring_rst = eth_rst; 
  
  // GMII clock generation
    
  generate
    if (CLKIN_PERIOD > 8.33)  
      DCM_BASE
      #(
        .CLKFX_MULTIPLY(CLKMUL),
        .CLKFX_DIVIDE(CLKDIV),
        .CLKDV_DIVIDE(2.0),
        .CLKIN_PERIOD(CLKIN_PERIOD),
        .CLK_FEEDBACK("NONE"),
        .DFS_FREQUENCY_MODE("LOW")
      )
      clk_dfs
      (
        .CLKIN(clkin),            
        .CLKFX(dfs_clkfx),
        .LOCKED(),  
        .RST(dfs_rst_dly[0]),
        // unconnected ports to suppress modelsim warnings
        .CLK0(),
        .CLKFB(),             //we don't care if this clock is phase aligned with clkin
        .CLK90(),
        .CLKDV(),
        .CLK180(),
        .CLK270(),
        .CLK2X(),
        .CLK2X180(),
        .CLKFX180()
      );    
    else
      DCM_BASE
      #(
        .CLKFX_MULTIPLY(CLKMUL),
        .CLKFX_DIVIDE(CLKDIV),
        .CLKDV_DIVIDE(2.0),
        .CLKIN_PERIOD(CLKIN_PERIOD),
        .CLK_FEEDBACK("NONE"),             
        .DFS_FREQUENCY_MODE("HIGH")
      )
      clk_dfs
      (
        .CLKIN(clkin),            
        .CLKFX(dfs_clkfx),
        .LOCKED(), 
        .RST(dfs_rst_dly[0]),
        // unconnected ports to suppress modelsim warnings
        .CLK0(),
        .CLKFB(),             //we don't care if this clock is phase aligned with clkin
        .CLK90(),
        .CLKDV(),
        .CLK180(),
        .CLK270(),
        .CLK2X(),
        .CLK2X180(),
        .CLKFX180() 
      );
  endgenerate 

  BUFG eth_clkfx_buf(.O(ethTXclock), .I(dfs_clkfx));

  //------------------------------------------------------------------------
  // GMII Transmitter Logic : Drive TX signals through IOBs onto GMII
  // interface
  //------------------------------------------------------------------------
  // Infer IOB Output flip-flops.
  always @(posedge ethTXclock, posedge reset)
  begin
    if (reset == 1'b1)
    begin
      GMII_TX_EN <= 1'b0;
      GMII_TX_ER <= 1'b0;
      GMII_TXD   <= 8'h00;
    end
    else
    begin
      GMII_TX_EN <= TX_EN_FROM_MAC;
      GMII_TX_ER <= TX_ER_FROM_MAC;
      GMII_TXD   <= TXD_FROM_MAC;
    end
  end        

  assign GMII_RESET_B = ~reset;

  // ODDR for Phy Clock
  ODDR GMIIoddr
  (
    .Q(GMII_TX_CLK),
    .C(ethTXclock),
    .CE(1'b1),
    .D1(1'b0),
    .D2(1'b1),
    .R(reset),
    .S(1'b0)
  );

  // IDELAYs and BUFG for the Receive data and clock
  IDELAY
  #(
    .IOBDELAY_TYPE("FIXED"), // "DEFAULT", "FIXED" or "VARIABLE"
    .IOBDELAY_VALUE(0) // Any value from 0 to 63
  )
  RXclockBlk
  (
    .I(GMII_RX_CLK),
    .O(RXclockDelay),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .RST(1'b0)
  );

  BUFG bufgClientRx (.I(RXclockDelay), .O(ethRXclock));
  
  IDELAY
  #(
    .IOBDELAY_TYPE("FIXED"), // "DEFAULT", "FIXED" or "VARIABLE"
    .IOBDELAY_VALUE(20) // Any value from 0 to 63
  )
  RXdvBlock
  (
    .I(GMII_RX_DV),
    .O(RXdvDelay),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .RST(1'b0)
  );

  IDELAY
  #(
    .IOBDELAY_TYPE("FIXED"), // "DEFAULT", "FIXED" or "VARIABLE"
    .IOBDELAY_VALUE(20) // Any value from 0 to 63
  )
  RXerBlock
  (
    .I(GMII_RX_ER),
    .O(RXerDelay),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .RST(1'b0)
  );
        
  genvar idly;

  generate
    for (idly = 0; idly < 8; idly = idly + 1)
    begin: dlyBlock
      IDELAY
      #(
        .IOBDELAY_TYPE("FIXED"), // "DEFAULT", "FIXED" or "VARIABLE"
        .IOBDELAY_VALUE(20) // Any value from 0 to 63
      )
      RXdataBlock
      (
        .I(GMII_RXD[idly]),
        .O(RXdataDelay[idly]),
        .C(1'b0),
        .CE(1'b0),
        .INC(1'b0),
        .RST(1'b0)
      );
    end
  endgenerate
  
`ifndef MODEL_TECH         //don't want to simulate because this is unlikely wrong        
  // instantiate IDELAYCTRL
  assign ctrlLock = &ctrlLockx;
  
  generate
    case (BOARDSEL)
    default:
    begin //ML505/XUP
      //instantiate idelayctrls because of an ISE bug
      (* syn_noprune = 1, xc_loc="IDELAYCTRL_X0Y4" *) IDELAYCTRL idelayctrl0
      (
        .RDY(ctrlLockx[0]),
        .REFCLK(clk200),
        .RST(reset)
      );    
   
      (* syn_noprune = 1, xc_loc="IDELAYCTRL_X1Y5" *) IDELAYCTRL idelayctrl1
      (
        .RDY(ctrlLockx[1]),
        .REFCLK(clk200),
        .RST(reset)
       )/* synthesis xc_loc = "IDELAYCTRL_X0Y1" */;        
    end
    endcase                
  endgenerate
`else
  assign ctrlLock = '1; 
`endif
    
  always_ff @(posedge ethRXclock)
  begin  //register the delayed RXdata.
    RXdataDelayReg <= RXdataDelay;
    RXdvDelayReg <= RXdvDelay;
    RXerDelayReg <= RXerDelay;
  end
    
  //--------------------------------------------------------------------------
  // Instantiate the Virtex-5 Embedded Ethernet EMAC
  //--------------------------------------------------------------------------

  assign RXdata = RXmacData[7:0];  //TEMAC has a 16-bit interface

  TEMAC v5_emac
  (
    .RESET                          (rst),

    // EMAC0
    .EMAC0CLIENTRXCLIENTCLKOUT      (),
    .CLIENTEMAC0RXCLIENTCLKIN       (ethRXclock),
    .EMAC0CLIENTRXD                 (RXmacData),
    .EMAC0CLIENTRXDVLD              (RXdataValid),
    .EMAC0CLIENTRXDVLDMSW           (),
    .EMAC0CLIENTRXGOODFRAME         (RXgoodFrame),
    .EMAC0CLIENTRXBADFRAME          (RXbadFrame),
    .EMAC0CLIENTRXFRAMEDROP         (),
    .EMAC0CLIENTRXSTATS             (),
    .EMAC0CLIENTRXSTATSVLD          (),
    .EMAC0CLIENTRXSTATSBYTEVLD      (),

    .EMAC0CLIENTTXCLIENTCLKOUT      (),
    .CLIENTEMAC0TXCLIENTCLKIN       (ethTXclock),
    .CLIENTEMAC0TXD                 ({8'h0,TXdata}),
    .CLIENTEMAC0TXDVLD              (TXdataValid),
    .CLIENTEMAC0TXDVLDMSW           (1'b0),
    .EMAC0CLIENTTXACK               (TXack),
    .CLIENTEMAC0TXFIRSTBYTE         (1'b0),
    .CLIENTEMAC0TXUNDERRUN          (1'b0),
    .EMAC0CLIENTTXCOLLISION         (),
    .EMAC0CLIENTTXRETRANSMIT        (),
    .CLIENTEMAC0TXIFGDELAY          (),
    .EMAC0CLIENTTXSTATS             (),
    .EMAC0CLIENTTXSTATSVLD          (),
    .EMAC0CLIENTTXSTATSBYTEVLD      (),

    .CLIENTEMAC0PAUSEREQ            (1'b0),                 //no flow control now
    .CLIENTEMAC0PAUSEVAL            (16'b0),

    .PHYEMAC0GTXCLK                 (1'b0),
    .EMAC0PHYTXGMIIMIICLKOUT        (),
    .PHYEMAC0TXGMIIMIICLKIN         (ethTXclock),

    .PHYEMAC0RXCLK                  (ethRXclock),
    .PHYEMAC0RXD                    (RXdataDelayReg),
    .PHYEMAC0RXDV                   (RXdvDelayReg),
    .PHYEMAC0RXER                   (RXerDelayReg),
    .EMAC0PHYTXCLK                  (),
    .EMAC0PHYTXD                    (TXD_FROM_MAC),
    .EMAC0PHYTXEN                   (TX_EN_FROM_MAC),
    .EMAC0PHYTXER                   (TX_ER_FROM_MAC),
    .PHYEMAC0MIITXCLK               (1'b0),
    .PHYEMAC0COL                    (1'b0),
    .PHYEMAC0CRS                    (1'b0),

    .CLIENTEMAC0DCMLOCKED           (ctrlLock),
    .EMAC0CLIENTANINTERRUPT         (),
    .PHYEMAC0SIGNALDET              (1'b0),
    .PHYEMAC0PHYAD                  (5'b00000),
    .EMAC0PHYENCOMMAALIGN           (),
    .EMAC0PHYLOOPBACKMSB            (),
    .EMAC0PHYMGTRXRESET             (),
    .EMAC0PHYMGTTXRESET             (),
    .EMAC0PHYPOWERDOWN              (),
    .EMAC0PHYSYNCACQSTATUS          (),
    .PHYEMAC0RXCLKCORCNT            (3'b000),
    .PHYEMAC0RXBUFSTATUS            (2'b00),
    .PHYEMAC0RXBUFERR               (1'b0),
    .PHYEMAC0RXCHARISCOMMA          (1'b0),
    .PHYEMAC0RXCHARISK              (1'b0),
    .PHYEMAC0RXCHECKINGCRC          (1'b0),
    .PHYEMAC0RXCOMMADET             (1'b0),
    .PHYEMAC0RXDISPERR              (1'b0),
    .PHYEMAC0RXLOSSOFSYNC           (2'b00),
    .PHYEMAC0RXNOTINTABLE           (1'b0),
    .PHYEMAC0RXRUNDISP              (1'b0),
    .PHYEMAC0TXBUFERR               (1'b0),
    .EMAC0PHYTXCHARDISPMODE         (),
    .EMAC0PHYTXCHARDISPVAL          (),
    .EMAC0PHYTXCHARISK              (),

    .EMAC0PHYMCLKOUT                (),
    .PHYEMAC0MCLKIN                 (1'b0),
    .PHYEMAC0MDIN                   (1'b1),
    .EMAC0PHYMDOUT                  (),
    .EMAC0PHYMDTRI                  (),
    .EMAC0SPEEDIS10100              (),

    // EMAC1
    .EMAC1CLIENTRXCLIENTCLKOUT      (),
    .CLIENTEMAC1RXCLIENTCLKIN       (1'b0),
    .EMAC1CLIENTRXD                 (),
    .EMAC1CLIENTRXDVLD              (),
    .EMAC1CLIENTRXDVLDMSW           (),
    .EMAC1CLIENTRXGOODFRAME         (),
    .EMAC1CLIENTRXBADFRAME          (),
    .EMAC1CLIENTRXFRAMEDROP         (),
    .EMAC1CLIENTRXSTATS             (),
    .EMAC1CLIENTRXSTATSVLD          (),
    .EMAC1CLIENTRXSTATSBYTEVLD      (),

    .EMAC1CLIENTTXCLIENTCLKOUT      (),
    .CLIENTEMAC1TXCLIENTCLKIN       (1'b0),
    .CLIENTEMAC1TXD                 (16'h0000),
    .CLIENTEMAC1TXDVLD              (1'b0),
    .CLIENTEMAC1TXDVLDMSW           (1'b0),
    .EMAC1CLIENTTXACK               (),
    .CLIENTEMAC1TXFIRSTBYTE         (1'b0),
    .CLIENTEMAC1TXUNDERRUN          (1'b0),
    .EMAC1CLIENTTXCOLLISION         (),
    .EMAC1CLIENTTXRETRANSMIT        (),
    .CLIENTEMAC1TXIFGDELAY          (8'h00),
    .EMAC1CLIENTTXSTATS             (),
    .EMAC1CLIENTTXSTATSVLD          (),
    .EMAC1CLIENTTXSTATSBYTEVLD      (),

    .CLIENTEMAC1PAUSEREQ            (1'b0),
    .CLIENTEMAC1PAUSEVAL            (16'h0000),

    .PHYEMAC1GTXCLK                 (1'b0),
    .EMAC1PHYTXGMIIMIICLKOUT        (),
    .PHYEMAC1TXGMIIMIICLKIN         (1'b0),

    .PHYEMAC1RXCLK                  (1'b0),
    .PHYEMAC1RXD                    (8'h00),
    .PHYEMAC1RXDV                   (1'b0),
    .PHYEMAC1RXER                   (1'b0),
    .PHYEMAC1MIITXCLK               (1'b0),
    .EMAC1PHYTXCLK                  (),
    .EMAC1PHYTXD                    (),
    .EMAC1PHYTXEN                   (),
    .EMAC1PHYTXER                   (),
    .PHYEMAC1COL                    (1'b0),
    .PHYEMAC1CRS                    (1'b0),

    .CLIENTEMAC1DCMLOCKED           (1'b1),
    .EMAC1CLIENTANINTERRUPT         (),
    .PHYEMAC1SIGNALDET              (1'b0),
    .PHYEMAC1PHYAD                  (5'b00000),
    .EMAC1PHYENCOMMAALIGN           (),
    .EMAC1PHYLOOPBACKMSB            (),
    .EMAC1PHYMGTRXRESET             (),
    .EMAC1PHYMGTTXRESET             (),
    .EMAC1PHYPOWERDOWN              (),
    .EMAC1PHYSYNCACQSTATUS          (),
    .PHYEMAC1RXCLKCORCNT            (3'b000),
    .PHYEMAC1RXBUFSTATUS            (2'b00),
    .PHYEMAC1RXBUFERR               (1'b0),
    .PHYEMAC1RXCHARISCOMMA          (1'b0),
    .PHYEMAC1RXCHARISK              (1'b0),
    .PHYEMAC1RXCHECKINGCRC          (1'b0),
    .PHYEMAC1RXCOMMADET             (1'b0),
    .PHYEMAC1RXDISPERR              (1'b0),
    .PHYEMAC1RXLOSSOFSYNC           (2'b00),
    .PHYEMAC1RXNOTINTABLE           (1'b0),
    .PHYEMAC1RXRUNDISP              (1'b0),
    .PHYEMAC1TXBUFERR               (1'b0),
    .EMAC1PHYTXCHARDISPMODE         (),
    .EMAC1PHYTXCHARDISPVAL          (),
    .EMAC1PHYTXCHARISK              (),

    .EMAC1PHYMCLKOUT                (),
    .PHYEMAC1MCLKIN                 (1'b0),
    .PHYEMAC1MDIN                   (1'b0),
    .EMAC1PHYMDOUT                  (),
    .EMAC1PHYMDTRI                  (),
    .EMAC1SPEEDIS10100              (),

    // Host Interface 
    .HOSTCLK                        (1'b0),
    .HOSTOPCODE                     (2'b00),
    .HOSTREQ                        (1'b0),
    .HOSTMIIMSEL                    (1'b0),
    .HOSTADDR                       (10'b0000000000),
    .HOSTWRDATA                     (32'h00000000),
    .HOSTMIIMRDY                    (),
    .HOSTRDDATA                     (),
    .HOSTEMAC1SEL                   (1'b0),

    // DCR Interface
    .DCREMACCLK                     (1'b0),
    .DCREMACABUS                    (10'h000),
    .DCREMACREAD                    (1'b0),
    .DCREMACWRITE                   (1'b0),
    .DCREMACDBUS                    (32'h00000000),
    .EMACDCRACK                     (),
    .EMACDCRDBUS                    (),
    .DCREMACENABLE                  (1'b0),
    .DCRHOSTDONEIR                  ()
  );

  defparam v5_emac.EMAC0_PHYINITAUTONEG_ENABLE = "FALSE";
  defparam v5_emac.EMAC0_PHYISOLATE = "FALSE";
  defparam v5_emac.EMAC0_PHYLOOPBACKMSB = "FALSE";
  defparam v5_emac.EMAC0_PHYPOWERDOWN = "FALSE";
  defparam v5_emac.EMAC0_PHYRESET = "TRUE";
  defparam v5_emac.EMAC0_CONFIGVEC_79 = "FALSE";
  defparam v5_emac.EMAC0_GTLOOPBACK = "FALSE";
  defparam v5_emac.EMAC0_UNIDIRECTION_ENABLE = "FALSE";
  defparam v5_emac.EMAC0_LINKTIMERVAL = 9'h000;
  defparam v5_emac.EMAC0_MDIO_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_SPEED_LSB = "FALSE";
  defparam v5_emac.EMAC0_SPEED_MSB = "TRUE"; 
  defparam v5_emac.EMAC0_USECLKEN = "FALSE";
  defparam v5_emac.EMAC0_BYTEPHY = "FALSE";
  defparam v5_emac.EMAC0_RGMII_ENABLE = "FALSE";
  defparam v5_emac.EMAC0_SGMII_ENABLE = "FALSE";
  defparam v5_emac.EMAC0_1000BASEX_ENABLE = "FALSE";
  defparam v5_emac.EMAC0_HOST_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_TX16BITCLIENT_ENABLE = "FALSE";
  defparam v5_emac.EMAC0_RX16BITCLIENT_ENABLE = "FALSE";    
  defparam v5_emac.EMAC0_ADDRFILTER_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_LTCHECK_DISABLE = "FALSE";  
  defparam v5_emac.EMAC0_RXFLOWCTRL_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_TXFLOWCTRL_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_TXRESET = "FALSE";  
  defparam v5_emac.EMAC0_TXJUMBOFRAME_ENABLE = "TRUE";            //support jumbo frame
  defparam v5_emac.EMAC0_TXINBANDFCS_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_TX_ENABLE = "TRUE";  
  defparam v5_emac.EMAC0_TXVLAN_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_TXHALFDUPLEX = "FALSE";  
  defparam v5_emac.EMAC0_TXIFGADJUST_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_RXRESET = "FALSE";  
  defparam v5_emac.EMAC0_RXJUMBOFRAME_ENABLE = "TRUE";           //support jumbo frame
  defparam v5_emac.EMAC0_RXINBANDFCS_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_RX_ENABLE = "TRUE";  
  defparam v5_emac.EMAC0_RXVLAN_ENABLE = "FALSE";  
  defparam v5_emac.EMAC0_RXHALFDUPLEX = "FALSE";  
  defparam v5_emac.EMAC0_PAUSEADDR = 48'hFFEEDDCCBBAA;
  defparam v5_emac.EMAC0_UNICASTADDR = 48'h000000000000;
  defparam v5_emac.EMAC0_DCRBASEADDR = 8'h00;

endmodule
