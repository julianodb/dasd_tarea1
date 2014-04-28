`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:22:36 12/29/2011 
// Design Name: 
// Module Name:    one_shot 
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
module one_shot( sigOut, sigIn, clk );

output reg sigOut;
input sigIn;

input clk;

/*
// Mejor implementacion, usa 1 flip flop menos y tiene menos retardo a la salida
reg prev_state;
always @( posedge clk ) begin
	prev_state <= sigIn;
	if( {prev_state,sigIn} == 2'b01 )
		sigOut <= 1;
	else
		sigOut <= 0;
end

// Condiciones iniciales para simulacion y FPGA
initial begin
	prev_state <= 0;
end
*/


reg [1:0] shift = 0;

always @(posedge clk) begin
	shift <= {shift[0], sigIn};
	if( shift == 2'b01 )
		sigOut <= 1;
	else
		sigOut <= 0;
end


endmodule
