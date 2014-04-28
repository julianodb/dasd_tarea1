`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:34:51 04/28/2014 
// Design Name: 
// Module Name:    anti_bouncing 
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
module anti_bouncing(
    input wire slow_clk,
    input wire fast_clk,
    input wire buton,
    output reg single_pulse_push
    );

reg q0, q1, q2, q3, aux;

always @(posedge slow_clk) begin

	q0 <= buton;
	q1 <= q0;
	q2 <= q1;
	q3 <= q2;

end

always @(posedge fast_clk) begin

	aux <= ~(q0 & q1 & q2 & q3);
	single_pulse_push <= aux & (q0 & q1 & q2 & q3);

end

endmodule
