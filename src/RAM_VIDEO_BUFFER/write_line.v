`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:56:32 04/08/2014 
// Design Name: 
// Module Name:    write_line 
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
module write_line(
		input wire memory_clk,
		input wire Write_Line,
		input wire [8:0] v_line,
		input wire StartUploading,
		input wire ReadyWrite,
		output wire [15:0] Memory_Data,
		output reg  [22:0] external_ram_write_address,
		output reg start_external_ram_write,
		output reg [9:0] line_buffer_read_address,
		input wire [15:0] Data_to_read_from_line_buffer,
		output reg WRITE
    );

localparam H_LEN = 10'd640;
localparam Burst_Len = 64;

reg [9:0] counter;
reg [23:0] mem_init_value;

wire [5:0] burst_pointer = counter[5:0];
wire OS_start_write; // OneShoot de señal anterior
one_shot one_shot_1( OS_start_write, Write_Line, memory_clk );


//assign line_buffer_read_address = counter;
assign Memory_Data = Data_to_read_from_line_buffer;


initial begin
	counter 								<= H_LEN;
	WRITE									<= 0;
	start_external_ram_write		<= 0;
end
always @(posedge memory_clk) begin
	line_buffer_read_address <= counter;
	if (OS_start_write) begin
		external_ram_write_address <= 640*v_line;
		counter <= 0;
	end
	
	if (StartUploading) begin
		WRITE<=1; //La señal StartDownloading empieza un ciclo antes que el primer dato
	end
	else if (ReadyWrite) 		WRITE<=0;
	
	if (WRITE) begin
		start_external_ram_write 	<= 0;
	end
	
	if (WRITE) begin
		//Memory_Data <= Data_to_read_from_line_buffer;
		if (burst_pointer == 63) begin
			external_ram_write_address <= external_ram_write_address + 22'd64;
			WRITE <= 0;
		end
		counter	<= counter + 1'b1;

	end else if (counter < (H_LEN-1)) begin
		start_external_ram_write<= 1;
	end

	
	
end


endmodule
