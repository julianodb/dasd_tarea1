`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    07:30:54 04/08/2014 
// Design Name: 
// Module Name:    read_line 
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
module read_line(
		input wire memory_clk,
		input wire Read_Line,
		input wire [8:0] v_line,
		input wire StartDownloading,
		input wire ReadyRead,
		input wire [15:0] Memory_Data,
		output reg [22:0] external_ram_read_address,
		output reg start_external_ram_read,
		output reg line_buffer_write_enable,
		output reg [9:0] line_buffer_write_address,
		output reg [15:0] Data_to_write_in_line_buffer,
		output reg RAM_BUSY,
		output reg READ
		
	);
localparam H_LEN = 10'd640;
localparam Burst_Len = 128;

reg [9:0] counter;
reg [23:0] mem_init_value;

initial begin
	counter 								<= H_LEN;
	mem_init_value 					<= 0;
	line_buffer_write_address 		<= 0;
	READ 									<= 0;
	line_buffer_write_enable		<= 0;
	line_buffer_write_address		<= 0;
	Data_to_write_in_line_buffer 	<= 0;
	RAM_BUSY 							<= 0;
end

wire [5:0] burst_pointer = counter[5:0];


wire OS_start_read; // OneShoot de señal anterior
one_shot one_shot_1( OS_start_read, Read_Line, memory_clk );

always @(posedge memory_clk) begin
	if (OS_start_read) begin
		external_ram_read_address 	<= 640*v_line; //Dirección de línea.
		counter 							<= 0;
		RAM_BUSY							<=	1;		
	end
	if (StartDownloading) 	READ<=1; //La señal StartDownloading empieza un ciclo antes que el primer dato
	else if (ReadyRead) 		READ<=0;	
	
	if (READ) begin	//La lectura empezo
		start_external_ram_read		<=	0;
		line_buffer_write_enable	<=	1;
		line_buffer_write_address 	<=	counter; //Dirección de escritura en block ram (Aquí se escribe la linea)
		counter 							<= counter + 1'b1;
		Data_to_write_in_line_buffer  <= Memory_Data;
		if (burst_pointer == 63) begin
			//Se aumenta la dirección para la siguiente ráfaga
			external_ram_read_address <= external_ram_read_address + 22'd64; 
		end
	end else if (counter < H_LEN) begin	//Si no se esta leyendo, pero hay una lectura pendiente
		line_buffer_write_enable	<= 0;
		start_external_ram_read		<= 1;
	end else if (counter == H_LEN) begin
		RAM_BUSY							<=	0;
	end
end 


endmodule
