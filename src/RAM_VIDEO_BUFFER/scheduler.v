`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    08:44:17 04/14/2014 
// Design Name: 
// Module Name:    scheduler 
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
module scheduler(
		input wire 				mem_clk,
		input wire 				start_read,
		input wire				StartDownloading,
		input wire 				start_write,
		input wire				StartUploading,
		input wire				ReadyRead,
		input wire				ReadyWrite,
		output wire [22:0] 	address_in,
		input wire 				READ,
		input wire 				WRITE,
		input wire 	[22:0]	external_ram_read_address,
		input wire 	[22:0] 	external_ram_write_address,
		output wire				external_ram_start_write,
		output wire				external_ram_start_read
    );
	 reg mem_mux = 1;
	 reg [2:0] state = 0;
	 
	 assign external_ram_start_write = start_write & (~mem_mux);
	 assign external_ram_start_read = start_read & mem_mux;
	 assign address_in = mem_mux? external_ram_read_address:external_ram_write_address;
	 
	 always @(posedge mem_clk) begin
		case (state)
			0: begin //IDLE
				if (start_read)begin
					state <= 1;
					mem_mux <= 1;
				end
				else if (start_write ) begin
					state <= 3;
					mem_mux <= 0;
				end
			end
			
			1: begin	
					if (StartDownloading || READ) state <= 2; //Esperemos que empieze la lectura
				end
				
			2: begin //Estaba leyendo.
					if (ReadyRead && start_write) begin //Si habia una escritura encolada, la atiende
						state <= 3;
						mem_mux <= 0;
					end else if (ReadyRead) begin
						state <= 0;
					end
				end
				
			3: begin
				if (StartUploading || WRITE) state <= 4;//Esperemos que empieze la escritura
			end			
			4: begin //Estaba escribiendo
					if (ReadyWrite && start_read) begin
						state <= 1;
						mem_mux <= 1;
					end else if (ReadyWrite) begin
						state <= 0;
					end
				end
			default: begin
					state <= 0;
				end
		endcase		
	 end

endmodule
