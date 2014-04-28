`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    07:39:50 04/21/2014 
// Design Name: 
// Module Name:    System_Clock_Generator 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module System_Clock_Generator
	(
		input 	wire 	clk,
		output 	wire 	g_clk,
		output 	wire 	EXTERNAL_RAM_INTERNAL_CLK,
		output 	wire 	EXTERNAL_RAM_EXTERNAL_CLK,
		output 	wire	HDMI_Pixel_Clock_25MHz,
		output 	wire	HDMI_Pixel_Clock_50MHz,
		output 	wire	HDMI_Pixel_Clock_250MHz,
		output 	wire	serdesstrobe
   );
	
	
	IBUFG clk_buffer_main(.I(clk),.O(g_clk));	
	
	wire        clkfx;
	
	DCM_CLKGEN
	#(
		.CLKFXDV_DIVIDE        (2),
		.CLKFX_DIVIDE          (5),
		.CLKFX_MULTIPLY        (4),
		.SPREAD_SPECTRUM       ("NONE"),
		.STARTUP_WAIT          ("FALSE"),
		.CLKIN_PERIOD          (10.0),
		.CLKFX_MD_MAX          (0.000)
	 )
	dcm_clkgen_inst
	(
		.CLKIN                 (g_clk),
		// Output clocks
		.CLKFX                 (clkfx),
		.CLKFX180              (),
		.CLKFXDV               (),
		// Ports for dynamic reconfiguration
		.PROGCLK               (1'b0),
		.PROGDATA              (),
		.PROGEN                (),
		.PROGDONE              (),
		// Other control and status signals
		.FREEZEDCM             (1'b0),
		.LOCKED                (),
		.STATUS                (),
		.RST                   (1'b0)
	);
	 
	
	BUFG clkout1_buf (.O (EXTERNAL_RAM_INTERNAL_CLK), .I(clkfx));
	OBUF clkout2_buf (.O (EXTERNAL_RAM_EXTERNAL_CLK), .I(clkfx));
	
	
	wire  pll_feed_back;
	wire p_clk_x1, p_clk_x2, p_clk_x10, pll_locked;
	wire pllclk0,pllclk1,pllclk2;

	assign HDMI_Pixel_Clock_25MHz = p_clk_x1;
	assign HDMI_Pixel_Clock_50MHz = p_clk_x2;
	assign HDMI_Pixel_Clock_250MHz = p_clk_x10;

	 PLL_BASE # (
		 .CLKIN_PERIOD(10), //Periodo cercano al del reloj de entrada
		 .CLKFBOUT_MULT(10), // Clock de salida PLL a 10x
		 .CLKOUT0_DIVIDE(4), // Clock de salida a 10x
		 .CLKOUT1_DIVIDE(40), //clock de salida a 1x
		 .CLKOUT2_DIVIDE(20), //Clock de salida a 2x
		 .COMPENSATION("INTERNAL")
	  ) PLL_OSERDES (
		 .CLKFBOUT(pll_feed_back),
		 .CLKOUT0(pllclk0),
		 .CLKOUT1(pllclk1),
		 .CLKOUT2(pllclk2),
		 .CLKOUT3(),
		 .CLKOUT4(),
		 .CLKOUT5(),
		 .LOCKED(pll_locked),
		 .CLKFBIN(pll_feed_back),
		 .CLKIN(g_clk),
		 .RST(1'b0)
	  );
	  BUFG	pclkbufg1x (.I(pllclk1), .O(p_clk_x1));
	  BUFG 	pclkbufg2x (.I(pllclk2), .O(p_clk_x2));
	  BUFPLL #(.DIVIDE(5)) ioclk_buf (.PLLIN(pllclk0), .GCLK(p_clk_x2), .LOCKED(pll_locked),
				  .IOCLK(p_clk_x10), .SERDESSTROBE(serdesstrobe), .LOCK());


endmodule
