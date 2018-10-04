`timescale 1ns / 1ps

`ifndef SYNP94
import libstd::*;
import libdebug::*;
import libiu::*;
import libconf::*;
import libtm::*;
`else
`include "../cpu/libiu.sv"
`include "../tm/libtm.sv"

`endif

module eth_dma_master(
	input iu_clk_type gclk, 
	input clkin,
	input bit rstin,
	input bit rst,
	output bit rstout,
	output bit [7:0] PHY_TXD,
	output bit PHY_TXEN,
	output bit PHY_TXER,
	output bit PHY_GTXCLK,
	input bit [7:0] PHY_RXD,
	input bit PHY_RXDV,
	input bit PHY_RXER,
	input bit PHY_RXCLK,
	input bit PHY_TXCLK,
	input bit PHY_COL,
	input bit PHY_CRS,
	output bit PHY_RESET,
	output bit eth_txclk,
	output bit eth_rxclk,
	output  debug_dma_read_buffer_in_type   eth_rb_in,
	output  debug_dma_write_buffer_in_type  eth_wb_in,
	input 	 debug_dma_write_buffer_out_type eth_wb_out,		
	output  debug_dma_cmdif_in_type         dma_cmd_in,     //cmd input 
  input   bit                             dma_cmd_ack,    //cmd has been accepted
	input 	 bit                             dma_done,		//dma status
        //timing model interface
        output  dma_tm_ctrl_type                dma2tm,
        input bit [3:0]							mac_lsn);

	bit fifo_we;
  bit ack_we, ack_re, ack_empty, ack_data_rx, ack_data_tx;
	bit send_data_we, send_data_re, send_data_empty;
	bit start_dma_rx, start_dma_gclk, start_dma_re, start_dma_empty;
	bit [31:0] rx_dout;
	bit [31:0] fifo_dout;

	bit [7:0] tx_data, rx_data;
	bit rx_data_valid, tx_data_valid, tx_ack;
	bit rx_clk_0_i, rx_client_clk_0_o, rx_client_clk_0, tx_client_clk_0_o, tx_client_clk_0;
	bit tx_phy_clk_0_o, tx_phy_clk_0;
	bit rx_good_frame, rx_bad_frame;
	bit gtx_clk_0, gtx_clk_0_i, refclk, refclk_bufg_i;
	bit gtxclk_dcm_clk0, gtxclk_dcm_clk0_b;
	bit	[3:0] dcm_rst_dly;		//shift register

	bit [5:0] tx_pre_reset_0_i, rx_pre_reset_0_i;
	bit [12:0] idelayctrl_reset_0_r;
	wire idelayctrl_reset_0_i;
	bit tx_reset_0_i, rx_reset_0_i;
	dma_tm_ctrl_type dma2tm_rx, dma2tm_gclk, r_dma2tm;
	bit dma2tm_we, dma2tm_re, dma2tm_empty;

  bit [15:0] tx_len_rx, tx_len_tx;
  bit tx_len_we, tx_len_re;
  
  bit dcm_locked;

  assign dcm_rst_out = rstin | ~dcm_locked;
	assign eth_rxclk = rx_client_clk_0;
	assign eth_txclk = tx_client_clk_0;
	assign PHY_RESET = ~dcm_rst_out;
	assign idelayctrl_reset_0_i = idelayctrl_reset_0_r[12];
	assign dma2tm = r_dma2tm;


	eth_rx_block gen_eth_rx_block (
		.clk(rx_client_clk_0),
		.reset(rx_reset_0_i),
		.rxd(rx_data),
		.rxdv(rx_data_valid),
		.packetvalid(rx_good_frame),
		.packetinvalid(rx_bad_frame),
		.eth_rb_in(eth_rb_in),
		.rx_dout(rx_dout),
		.tx_len_we(tx_len_we),
		.tx_len(tx_len_rx),
		.fifo_we(fifo_we),
		.ack_we(ack_we),
		.ack_data(ack_data_rx),
		.start_dma(start_dma_rx),
		.dma2tm(dma2tm_rx),
		.dma2tm_we(dma2tm_we),
		.rst_out(rstout),
		.mac_lsn);
		
	async_fifo_one #(
	   .DWIDTH($bits(dma_tm_ctrl_type)) // number of total bits in dma_tm_ctrl_type
	   ) dma2tm_fifo (
	   .rst(rx_reset_0_i),
	   .din({dma2tm_rx.threads_active, dma2tm_rx.threads_total, dma2tm_rx.tm_dbg_ctrl}),
	   .we(dma2tm_we),
	   .wclk(rx_client_clk_0),
	   .rclk(gclk.clk),
	   .re(dma2tm_re),
	   .empty(dma2tm_empty),
	   .full(),
	   .dout({dma2tm_gclk.threads_active, dma2tm_gclk.threads_total, dma2tm_gclk.tm_dbg_ctrl}));		
		
	async_fifo_one ack_fifo (
	  .rst(rx_reset_0_i),
	  .din(ack_data_rx),
	  .we(ack_we),
	  .wclk(rx_client_clk_0),
	  .rclk(tx_client_clk_0),
	  .re(ack_re),
	  .empty(ack_empty),
	  .full(),
	  .dout(ack_data_tx));
	  
	async_fifo_one start_dma_fifo (
	  .rst(rx_reset_0_i),
	  .din(),
	  .we(start_dma_rx),
	  .wclk(rx_client_clk_0),
	  .rclk(gclk.clk),
	  .re(start_dma_re),
	  .empty(start_dma_empty),
	  .full(),
	  .dout());
		
	async_fifo_one #(
	   .DWIDTH(16)
	   ) tx_len_fifo (
	   .rst(rx_reset_0_i),
	   .din(tx_len_rx),
	   .we(tx_len_we),
	   .wclk(rx_client_clk_0),
	   .rclk(tx_client_clk_0),
	   .re(tx_len_re),
	   .empty(),
	   .full(),
	   .dout(tx_len_tx));

	eth_tx_block  gen_tx_block(
		.clk(tx_client_clk_0),
		.reset(tx_reset_0_i),
		.tx_ack(tx_ack),
		.ack_empty(ack_empty),
		.ack_data(ack_data_tx),
		.ack_re(ack_re),
		.send_data_empty(send_data_empty),
		.send_data_re(send_data_re),
		.tx_len(tx_len_tx),
		.din(eth_wb_out.data),
		.tx_data(tx_data),
		.tx_en(tx_data_valid),
		.addr(eth_wb_in.addr),
		.mac_lsn);
		
    FIFO36 #(
    .SIM_MODE("SAFE"), 
    .ALMOST_FULL_OFFSET(),
    .ALMOST_EMPTY_OFFSET(),
    .DATA_WIDTH(36),
    .DO_REG(1),
    .EN_SYN("FALSE"),
    .FIRST_WORD_FALL_THROUGH("FALSE")
    ) dma_control_fifo (
    .ALMOSTEMPTY(),
    .ALMOSTFULL(),
    .DO(fifo_dout),
    .DOP(),
    .EMPTY(fifo_empty),
    .FULL(),
    .RDCOUNT(),
    .RDERR(),
    .WRCOUNT(),
    .WRERR(),
    .DI(rx_dout),
    .DIP(4'b0),
    .RDCLK(gclk.clk),
    .RDEN(fifo_read),
    .RST(rst),
    .WRCLK(eth_rxclk),
    .WREN(fifo_we)
    );

  dma_control  gen_dma_control (
    .clk(gclk.clk),
    .reset(rst),
    .start_dma_empty(start_dma_empty),
    .start_dma_re(start_dma_re),
    .fifo_empty(fifo_empty),
    .fifo_data(fifo_dout),
    .fifo_read(fifo_read),
    .dma_cmd_ack(dma_cmd_ack),
    .dma_done(dma_done),
    .dma_cmd_in(dma_cmd_in),
    .send_data(send_data_we));
    
  	async_fifo_one send_data_fifo (
	   .rst(rst),
	   .din(),
	   .we(send_data_we),
	   .wclk(gclk.clk),
	   .rclk(tx_client_clk_0),
	   .re(send_data_re),
	   .empty(send_data_empty),
	   .full(),
	   .dout());  

assign dma2tm_re = ~dma2tm_empty;
  
always_ff @(posedge gclk.clk) begin
    if (~dma2tm_empty)
      r_dma2tm <= dma2tm_gclk;
end

	//--------------------------------------------------------------------------
	//	DCM to generate 125 MHz GTXCLK and 200 MHZ REFCLK from 100MHz clock input
	//--------------------------------------------------------------------------

	 DCM_ADV 	#(
			.CLKFX_DIVIDE			(4),
			.CLKFX_MULTIPLY			(5),
			.CLKIN_PERIOD			(10)
			) gtxclk_dcm (
			      .CLK0(gtxclk_dcm_clk0),
            .CLK180(), 
            .CLK270(),
            .CLK2X(refclk),
            .CLK2X180(),
            .CLK90(),
            .CLKDV(),
            .CLKFX(gtx_clk_0),
            .CLKFX180(),
            .DO(),
            .DRDY(),
            .LOCKED(dcm_locked),
            .PSDONE(),
            .CLKFB(gtxclk_dcm_clk0_b),
            .CLKIN(clkin),
            .DADDR(),
            .DCLK(),
            .DEN(),
            .DI(),
            .DWE(),
            .PSCLK(),
            .PSEN(),
            .PSINCDEC(),
			      .RST(dcm_rst_dly[0]));
			      
  always_ff @(posedge clkin or posedge rstin) begin
    if (rstin)
        dcm_rst_dly <= '1;
    else
        dcm_rst_dly <= dcm_rst_dly >> 1;
  end			      
			      
	BUFG bufg_gtxclk_dcm (.I(gtxclk_dcm_clk0), .O(gtxclk_dcm_clk0_b));		
	BUFG bufg_gtx_clk_0 (.I(gtx_clk_0), .O(gtx_clk_0_i));	
	BUFG bufg_refclk (.I(refclk), .O(refclk_bufg_i));		

	//--------------------------------------------------------------------------
	//	Create synchronous reset signals
	//--------------------------------------------------------------------------

	always @(posedge tx_client_clk_0, posedge dcm_rst_out)
	begin
	if (dcm_rst_out == 1'b1)
		begin
		tx_pre_reset_0_i <= 6'h3F;
		tx_reset_0_i     <= 1'b1;
		end
	else
		begin
		tx_pre_reset_0_i[0]   <= 1'b0;
		tx_pre_reset_0_i[5:1] <= tx_pre_reset_0_i[4:0];
		tx_reset_0_i          <= tx_pre_reset_0_i[5];
		end
	end

	always @(posedge rx_client_clk_0, posedge dcm_rst_out)
	begin
	if (dcm_rst_out == 1'b1)
		begin
		rx_pre_reset_0_i <= 6'h3F;
		rx_reset_0_i     <= 1'b1;
		end
	else
		begin
		rx_pre_reset_0_i[0]   <= 1'b0;
		rx_pre_reset_0_i[5:1] <= rx_pre_reset_0_i[4:0];
		rx_reset_0_i          <= rx_pre_reset_0_i[5];
		end
	end  
					
	always @(posedge refclk_bufg_i, posedge dcm_rst_out)
	begin
	if (dcm_rst_out == 1'b1)
		begin
		idelayctrl_reset_0_r[0]    <= 1'b0;
		idelayctrl_reset_0_r[12:1] <= 12'b111111111111;
		end
	else
		begin
		idelayctrl_reset_0_r[0]    <= 1'b0;
		idelayctrl_reset_0_r[12:1] <= idelayctrl_reset_0_r[11:0];
		end
	end
			
	//--------------------------------------------------------------------------
	//	EMAC0 Clocking
	//	Instantiate IDELAYCTRL for the IDELAY in Fixed Tap Delay Mode
	//--------------------------------------------------------------------------

	(* syn_noprune = 1, xc_loc="IDELAYCTRL_X0Y4" *) IDELAYCTRL dlyctrl0 (
			.RDY				(),
			.REFCLK			(refclk_bufg_i),
	      .RST				(idelayctrl_reset_0_i));
    	

	(* syn_noprune = 1, xc_loc="IDELAYCTRL_X1Y5" *) IDELAYCTRL dlyctrl1 (
			.RDY				(),
			.REFCLK			(refclk_bufg_i),
	      .RST				(idelayctrl_reset_0_i));

	IODELAY #(
			.IDELAY_TYPE			("FIXED"),
			.IDELAY_VALUE			(0)
			) gmii_rxc0_delay (
			.IDATAIN				(PHY_RXCLK),
			.DATAOUT				(gmii_rx_clk_0_delay),
			.ODATAIN				(1'b0),
			.DATAIN     (),
			.T						(1'b1), 
			.C						(1'b0), 
			.CE					(1'b0), 
			.INC					(1'b0), 
			.RST					(1'b0));

	//--------------------------------------------------------------------------
	//	Put the PHY clocks from the EMAC through BUFGs.
	//	Used to clock the PHY 	side of the EMAC wrappers.
	//--------------------------------------------------------------------------
	 
	BUFG bufg_phy_tx_0 (.I(tx_phy_clk_0_o), .O(tx_phy_clk_0));
	BUFG bufg_phy_rx_0 (.I(gmii_rx_clk_0_delay), .O(rx_clk_0_i));

	//--------------------------------------------------------------------------
	//	Put the client clocks from the EMAC through BUFGs.
	//	Used to clock the client side of the EMAC wrappers.
	//--------------------------------------------------------------------------

	BUFG bufg_client_tx_0 (.I(tx_client_clk_0_o), .O(tx_client_clk_0));
	BUFG bufg_client_rx_0 (.I(rx_client_clk_0_o), .O(rx_client_clk_0));
								
	//--------------------------------------------------------------------------
	//	Instantiate the EMAC Wrapper
	//--------------------------------------------------------------------------

	v5_emac_v1_5_block EMac0_block (
			.TX_CLIENT_CLK_OUT_0		(tx_client_clk_0_o),
			.RX_CLIENT_CLK_OUT_0		(rx_client_clk_0_o),
			.TX_PHY_CLK_OUT_0		(tx_phy_clk_0_o),
			.TX_CLIENT_CLK_0		(tx_client_clk_0),
			.RX_CLIENT_CLK_0		(rx_client_clk_0),
			.TX_PHY_CLK_0			(tx_phy_clk_0),
			.EMAC0CLIENTRXD			(rx_data),
			.EMAC0CLIENTRXDVLD		(rx_data_valid),
			.EMAC0CLIENTRXGOODFRAME		(rx_good_frame),
			.EMAC0CLIENTRXBADFRAME		(rx_bad_frame),
			.EMAC0CLIENTRXFRAMEDROP (),
      .EMAC0CLIENTRXSTATS   (),
      .EMAC0CLIENTRXSTATSVLD    (),
      .EMAC0CLIENTRXSTATSBYTEVLD  (),
			.CLIENTEMAC0TXD			(tx_data),
			.CLIENTEMAC0TXDVLD		(tx_data_valid),
			.EMAC0CLIENTTXACK		(tx_ack),
			.CLIENTEMAC0TXFIRSTBYTE		(1'b0),
			.CLIENTEMAC0TXUNDERRUN		(1'b0),
			.EMAC0CLIENTTXCOLLISION  (),
      .EMAC0CLIENTTXRETRANSMIT  (),
			.CLIENTEMAC0TXIFGDELAY		(8'b0),
      .EMAC0CLIENTTXSTATS   (),
      .EMAC0CLIENTTXSTATSVLD  (),
      .EMAC0CLIENTTXSTATSBYTEVLD  (),
			.CLIENTEMAC0PAUSEREQ		(1'b0),
			.CLIENTEMAC0PAUSEVAL		(16'b0),
			.GTX_CLK_0			(gtx_clk_0_i),
			.GMII_TXD_0			(PHY_TXD),
			.GMII_TX_EN_0			(PHY_TXEN),
			.GMII_TX_ER_0			(PHY_TXER),
			.GMII_TX_CLK_0			(PHY_GTXCLK),
			.GMII_RXD_0			(PHY_RXD),
			.GMII_RX_DV_0			(PHY_RXDV),
			.GMII_RX_ER_0			(PHY_RXER),
			.GMII_RX_CLK_0			(rx_clk_0_i),
			.MII_TX_CLK_0			(PHY_TXCLK),
			.GMII_COL_0			(PHY_COL),
			.GMII_CRS_0			(PHY_CRS),
			.RESET				(rstin));


endmodule
		