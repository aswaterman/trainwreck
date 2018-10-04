//---------------------------------------------------------------------------   
// File:        clkgen.v
// Author:      Zhangxi Tan
// Description: Generate clk for Xilinx V5	
//---------------------------------------------------------------------------

`timescale 1ns / 1ps

module xcv5_cpu_clkgen #(parameter CLKMUL = 2.0, parameter CLKDIV = 2.0, parameter CLKIN_PERIOD = 10.0) (input bit clkin, input rstin, output bit clk, output bit clk2x, output bit ce, output bit locked) /* synthesis syn_sharing=on */;
	bit	[3:0]	dll_rst_dly, dfs_rst_dly;		//shift register
	bit		dfs_locked; //locked

	//wire	clkin_b;				//clkin after ibufg
	wire	dfs_clkfx, dfs_clkfx_b;			       //clkfs of DFS
	wire dfs_clk0, dfs_clk0_b;            //DFS clkfb input
	wire	dll_clk0, dll_clk0_b, dll_clk2x;	//DLL output clk
	
	//dfs input/output
	//IBUFG clkin_buf(.O(clkin_b), .I(clkin));
	//IBUFGDS clkin_buf(.O(clkin_b), .I(clkin_p), .IB(clkin_n));
	  
	BUFG  dfs_clkfb_buf(.O(dfs_clk0_b), .I(dfs_clk0));
	BUFG  dfs_clkfx_buf(.O(dfs_clkfx_b), .I(dfs_clkfx));

	//dll input/output
	BUFG dll_clk0_buf(.O(dll_clk0_b), .I(dll_clk0));
	BUFG dll_clk2x_buf(.O(clk2x), .I(dll_clk2x));
	

	assign	clk   = dll_clk0_b; 	
	assign clk0  = dfs_clk0_b;

	generate
		if (CLKIN_PERIOD > 8.33)  
			DCM_BASE #(.CLKFX_MULTIPLY(CLKMUL),
				   .CLKFX_DIVIDE(CLKDIV),
				   .CLKDV_DIVIDE(2.0),
				   .CLKIN_PERIOD(CLKIN_PERIOD),
				   .DFS_FREQUENCY_MODE("LOW")) clk_dfs(
					.CLKIN(clkin),
					.CLKFB(dfs_clk0_b),
					.CLKFX(dfs_clkfx),
					.LOCKED(dfs_locked),	
					.RST(dfs_rst_dly[0]),
					.CLK0(dfs_clk0),
					//unconnected ports to suppress modelsim warnings
          .CLK90(),
          .CLKDV(),
					.CLK180(),
					.CLK270(),
					.CLK2X(),
					.CLK2X180(),
					.CLKFX180()
				);		
		else
			DCM_BASE #(.CLKFX_MULTIPLY(CLKMUL),
				   .CLKFX_DIVIDE(CLKDIV),
				   .CLKDV_DIVIDE(2.0),
				   .CLKIN_PERIOD(CLKIN_PERIOD),
				   .DFS_FREQUENCY_MODE("HIGH")) clk_dfs(
					.CLKIN(clkin),
					.CLKFB(dfs_clk0_b),
					.CLKFX(dfs_clkfx),
					.LOCKED(dfs_locked),	
					.RST(dfs_rst_dly[0]),
					.CLK0(dfs_clk0),
					//unconnected ports to suppress modelsim warnings
					.CLK180(),
					.CLK270(),
          .CLK90(),
          .CLKDV(),
					.CLK2X(),
					.CLK2X180(),
					.CLKFX180()
				);
		
		if (CLKIN_PERIOD * CLKDIV / CLKMUL > 8.33)  
			DCM_BASE #(.CLKFX_MULTIPLY(2.0),
				   .CLKFX_DIVIDE(2.0),
				   .CLKIN_PERIOD(CLKIN_PERIOD * CLKDIV / CLKMUL),
				   .DLL_FREQUENCY_MODE("LOW")) clk_dll(
					.CLKIN(dfs_clkfx_b),
					.CLKFB(dll_clk0_b),
					.CLK0(dll_clk0),
					.CLK2X(dll_clk2x),
					.LOCKED(locked),	
					.RST(dll_rst_dly[0]),
					//unconnected ports to suppress modelsim warnings
					.CLKFX(),
					.CLK90(ce),
					.CLK180(),
					.CLK270(),					
					.CLK2X180(),
					.CLKDV(),
					.CLKFX180()
				);		
		else
			DCM_BASE #(.CLKFX_MULTIPLY(2.0),
				   .CLKFX_DIVIDE(2.0),
				   .CLKIN_PERIOD(CLKIN_PERIOD * CLKDIV / CLKMUL),
				   .DLL_FREQUENCY_MODE("HIGH")) clk_dll(
					.CLKIN(dfs_clkfx_b),
					.CLKFB(dll_clk0_b),
					.CLK0(dll_clk0),
					.CLK2X(dll_clk2x),
					.LOCKED(locked),	
					.RST(dll_rst_dly[0]),
					//unconnected ports to suppress modelsim warnings
					.CLKFX(),
					.CLK90(ce),
					.CLK180(),
					.CLK270(),					
					.CLK2X180(),
					.CLKDV(),
					.CLKFX180()
				);
	endgenerate

  always_ff @(posedge clkin or posedge rstin) begin
    if (rstin)
        dfs_rst_dly <= '1;
    else
        dfs_rst_dly <= dfs_rst_dly >> 1;
  end

	always_ff @(posedge dfs_clkfx_b or negedge dfs_locked) begin
		if (!dfs_locked)
			dll_rst_dly <= '1;
		else
			dll_rst_dly <= dll_rst_dly >> 1;
	end 
endmodule