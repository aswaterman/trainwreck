//-------------------------------------------------------------------------------------------  
// Description: Interface between FrontEnd machine and MAC (in Modelsim) using DPI
//-------------------------------------------------------------------------------------------   
//synthesis translate_off

`timescale 1ns / 1ps

typedef struct {
	int 	tx_en;
	int	tx_data;
} tx_request_type;

typedef struct {
	int	rxdv;
	int 	rx_data;
} rx_response_type;

import "DPI-C" context function void init_driver();
import "DPI-C" context function void transfer_tx(input tx_request_type req);
import "DPI-C" context function void transfer_rx(output rx_response_type req);

module mac_fedriver(
	input 	bit rxclk,
	input	bit txclk,
	input	bit rst,

	output	bit rxdv,
	output	bit [7:0] rxd,

	input	bit [7:0] txd,
	input	bit txen
);

initial begin
	init_driver();
end;

  rx_response_type rx_resp;
  tx_request_type tx_req;

  always_comb begin

    rxdv = '0;
    rxd = '0;

    if (rst == 0) begin 
      rxdv = int'(rx_resp.rxdv);
      rxd = int'(rx_resp.rx_data);

      tx_req.tx_en = int'(txen);
      tx_req.tx_data = int'(txd);
    end
  end

  always_ff @(negedge rxclk) begin
    transfer_rx(rx_resp);
  end

  always_ff @(negedge txclk) begin
    transfer_tx(tx_req);
  end

endmodule
      
    
    

