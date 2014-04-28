`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:46:44 04/28/2014 
// Design Name: 
// Module Name:    slow_clk_gen 
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
module slow_clk_gen(
    input wire fast_clk,
    output reg slow_clk
    );
	 
	 parameter counter_size = 16;
	 parameter reduction_factor = 16'hFFFF;
	 
	 reg [counter_size-1:0] counter;
	 
	 initial counter <= 16'd0;
	 
	 always @(posedge fast_clk) begin
	 
		counter = counter + 1;
		if (counter >= reduction_factor) begin
			counter = 0;
			slow_clk = ~slow_clk;
		end
		
	 end

endmodule
