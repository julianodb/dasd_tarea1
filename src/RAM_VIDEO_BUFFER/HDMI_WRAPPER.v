`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:43:33 04/21/2014 
// Design Name: 
// Module Name:    HDMI_WRAPPER 
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
module HDMI_WRAPPER(	
		input 	wire	clk,
		output	wire	global_clk,
		output 	wire 	HDMI_Pixel_Clock_25MHz,
		output	wire	EXTERNAL_RAM_INTERNAL_CLK,
		output 	wire	HDMI_CAPTURE_CLOCK,
		
		(* KEEP="TRUE" *) output 	reg				First_pixel,
		(* KEEP="TRUE" *) output	reg				Last_pixel,
		(* KEEP="TRUE" *) output	reg				Pixel_data_valid,
		
		output	wire	[15:0]	PIXEL_DATA,
		
		input		wire	[7:0]		R_display,
		input		wire	[7:0]		G_display,
		input		wire	[7:0]		B_display,
		
		input		wire	[15:0]	DATA_TO_RAM,
		output	wire	[7:0]		R_capture,
		output 	wire	[7:0]		G_capture,
		output	wire	[7:0]		B_capture,

		
		input 	wire	[4:0]		Display_Latency,
		input		wire	[4:0]		Capture_Latency,
		
		input 	wire 	[3:0] 	TMDS_IN, 
		input 	wire 	[3:0] 	TMDS_INB,
		output 	wire 	[3:0] 	TMDS_OUT,
		output 	wire 	[3:0] 	TMDS_OUTB,
		input 	wire 				EDID_IN_SCL,
		inout 	wire 				EDID_IN_SDA,
		
		output 	wire	[22:0] 	MemAdr_ext,
		inout  	wire 	[15:0] 	MemDB,
		output 	wire 				OE_out,
		output 	wire 				WE_out,
		output 	wire 				ADV_out,
		output 	wire 				MT_CLK,
		output 	wire 				CE_out,
		output 	wire 				CRE_out,
		output 	wire 				UB,
		output 	wire 				LB,
		input  	wire 				MemWait
		
    );
	//Cable con dirección de memoria para gestiones internas
	wire [23:0] MemAdr;
	//De la dirección que se genera, se descarta el bit menos significativo
	assign MemAdr_ext = MemAdr[23:1];
	 
	wire HDMI_Pixel_Clock_50MHz,HDMI_Pixel_Clock_250MHz;
	wire serdesstrobe;

	System_Clock_Generator HDMI_AND_MEMORY_CLOCK_MANAGER (

			//Entrada desde el reloj de la tarjeta. (100 MHz)
			.clk(clk),
			
			//Salida de reloj global. Usado para lógica general. (100 MHz)
			.g_clk(global_clk), //Sin usar en este ejemplo. Pueden usarlo como gusten.
			
			//Reloj de memoria interno. Usado para las transacciones de memoria dentro de
			//la tarjeta (80 MHz)
			.EXTERNAL_RAM_INTERNAL_CLK(EXTERNAL_RAM_INTERNAL_CLK),
			
			//Reloj de memoria externo. Usado para alimentar a la memoria externa (80 MHz)
			.EXTERNAL_RAM_EXTERNAL_CLK(MT_CLK),
			
			//Relojes necesarios para salida HDMI.
			.HDMI_Pixel_Clock_25MHz(HDMI_Pixel_Clock_25MHz),
			.HDMI_Pixel_Clock_50MHz(HDMI_Pixel_Clock_50MHz),
			.HDMI_Pixel_Clock_250MHz(HDMI_Pixel_Clock_250MHz),
			
			//Señal utilizada para sincronización serializador/deserializador HDMI.
			.serdesstrobe(serdesstrobe)
	);
	
	
	//EL EDID PERMITE A SU EQUIPO (COMPUTADOR) RECONOCER EL FPGA COMO UN MONITOR EXTERNO
	EDID_I2C #( .rom_init_file("rom_data/edid_2.coe") ) 
	IDENTIFICADOR_MONITOR_VLSI (
			.clk(EXTERNAL_RAM_INTERNAL_CLK),
			.SCL_PIN(EDID_IN_SCL),
			.SDA_PIN(EDID_IN_SDA)
	);		  
	
	
		

	wire [9:0] 	horizontal_pixel_pointer;
   wire [8:0] 	vertical_pixel_pointer;
   wire 			video_is_active;				//Vertical or horizontal blanking
   wire 			blanking_active_line; 		//Video is inactive, but it is in a active line (horizontal blanking)
	
	
	
	always @(posedge HDMI_Pixel_Clock_25MHz) begin
		First_pixel <= (video_is_active && (horizontal_pixel_pointer == 10'd0) && (vertical_pixel_pointer == 9'd0));
		Last_pixel <= (video_is_active && (horizontal_pixel_pointer == 10'd639) && (vertical_pixel_pointer == 9'd479));
		Pixel_data_valid <= video_is_active;
	end
	
	dvi_tx_fixed_res dvi_main_tx_0
	(
		.p_clk_x1(HDMI_Pixel_Clock_25MHz), 
		.p_clk_x2(HDMI_Pixel_Clock_50MHz), 
		.p_clk_x10(HDMI_Pixel_Clock_250MHz),
		.serdesstrobe(serdesstrobe),
		.hcount(horizontal_pixel_pointer), 
		.vcount(vertical_pixel_pointer), 
		.red_data(R_display), 
		.green_data(G_display), 
		.blue_data(B_display),
		.active(video_is_active),
		.blanking_active_line(blanking_active_line),
		.TMDS_OUT(TMDS_OUT), 
		.TMDS_OUTB(TMDS_OUTB), 
		.reset(1'b0),
		.Display_Latency(Display_Latency)
	);
	
	
	wire [7:0] R_in, G_in, B_in;
	assign R_capture = R_in;
	assign G_capture = G_in;
	assign B_capture = B_in;
	wire rx_p_clk_x1, rx_vsync, rx_active;

	dvi_decoder dvi_decoder_1 (
		.tmdsclk_p(TMDS_IN[3]),      	// tmds clock
		.tmdsclk_n(TMDS_INB[3]),      // tmds clock
		.blue_p  (TMDS_IN[0]),        // Blue data in
		.green_p (TMDS_IN[1]),        // Green data in
		.red_p   (TMDS_IN[2]),        // Red data in
		.blue_n  (TMDS_INB[0]),       // Blue data in
		.green_n (TMDS_INB[1]),       // Green data in
		.red_n   (TMDS_INB[2]),       // Red data in
		.exrst   (1'b0),              // external reset input, e.g. reset button
		.reset(),          				// rx reset
		
		.pclk(rx_p_clk_x1), 				// regenerated pixel clock
		.pclkx2(),          				// double rate pixel clock
		.pclkx10(),         				// 10x pixel as IOCLK
		.pllclk0(),         				// send pllclk0 out so it can be fed into a different BUFPLL
		.pllclk1(),         				// PLL x1 output
		.pllclk2(),         				// PLL x2 output

		.pll_lckd(),       				// send pll_lckd out so it can be fed into a different BUFPLL
		.serdesstrobe(),   				// BUFPLL serdesstrobe output
		.tmdsclk(),        				// TMDS cable clock

		.hsync(),          				// hsync data
		.vsync(rx_vsync),          	// vsync data
		.de(rx_active),            	// data enable

		
		.blue_vld(),
		.green_vld(),
		.red_vld(),
		.blue_rdy(),
		.green_rdy(),
		.red_rdy(),

		.psalgnerr(),

		// Salida 30 bits //
		.sdout(),
		// Salidas 8 bits //
		.red(R_in),      // pixel data out
		.green(G_in),    // pixel data out
		.blue(B_in)      // pixel data out
	);
	assign HDMI_CAPTURE_CLOCK = rx_p_clk_x1;
	wire [15:0] 	data_read;
	wire [15:0] 	data_write;
	wire 				start_read;
	wire 				start_write;
	reg 				start_config = 1;
	wire 				StartDownloading;
	wire 				StartUploading;
	wire 				ReadyConfig;
	wire 				ReadyRead;	
	wire 				ReadyWrite;
	wire [22:0] 	address_in;
	wire 				external_ram_start_write;
	wire 				external_ram_start_read;
	
	PSDRAMDriver PSDRAM ( 
		.ClkMem(EXTERNAL_RAM_INTERNAL_CLK),
		.WE(WE_out),
		.CE(CE_out),
		.OE(OE_out),
		.LB(LB),
		.UB(UB),
		.ADV(ADV_out),
		.CRE(CRE_out),
		.WAIT(MemWait),
		.ADDR(MemAdr),
		.DATA_BUS(MemDB),
		.Address(address_in),  //Address to write/read
		.DataRead(data_read),
		.DataWrite(data_write),
		.StartWrite(external_ram_start_write),
		.StartRead(external_ram_start_read),
		.StartConfig(start_config),
		.StartDownloading(StartDownloading),
		.StartUploading(StartUploading),
		.ReadyRead(ReadyRead),
		.ReadyWrite(ReadyWrite),
		.ReadyConfig(ReadyConfig),

		//Puertos no usados.
		.StartReadBCR(1'b0),
		.ReadyReadBCR(),
		.StartSendBuff(),
		.DebugRam()
	);				
		
	//Buffer de linea	
	reg 	[15:0] 	LineBuffer[639:0];
	reg 	[15:0] 	Pixel;		//Desde Buffer
	wire 	[15:0] 	Pixel_In;  //Hacia Buffer
	wire 				Pixel_wen;		//Activa la escritura en buffer
	wire	[9:0] 	Pixel_write_addr; //Dirección de escritura en buffer.
	assign PIXEL_DATA = Pixel;
	
	
	always @(posedge HDMI_Pixel_Clock_25MHz) begin
		Pixel <= LineBuffer[horizontal_pixel_pointer];
	end
	
	always @(posedge EXTERNAL_RAM_INTERNAL_CLK) begin
		if (Pixel_wen) begin
			LineBuffer[Pixel_write_addr] <= Pixel_In;
		end
	end	
	wire WRITE,READ;
	wire [22:0] external_ram_read_address;
	wire [22:0] external_ram_write_address;
	
	
	
	scheduler mem_address_scheduler(
			.mem_clk(EXTERNAL_RAM_INTERNAL_CLK),
			.start_read(start_read),
			.StartDownloading(StartDownloading),
			.start_write(start_write),
			.StartUploading(StartUploading),
			.ReadyRead(ReadyRead),
			.ReadyWrite(ReadyWrite),
			.address_in(address_in),
			.READ(READ),
			.WRITE(WRITE),
			.external_ram_read_address(external_ram_read_address),
			.external_ram_write_address(external_ram_write_address),
			.external_ram_start_write(external_ram_start_write),
			.external_ram_start_read(external_ram_start_read)
	);
	 
	 
	read_line mem_video_reader(
			.memory_clk(EXTERNAL_RAM_INTERNAL_CLK),
			.Read_Line(blanking_active_line),
			.v_line(vertical_pixel_pointer),
			.StartDownloading(StartDownloading),
			.ReadyRead(ReadyRead),
			.Memory_Data(data_read),
			.external_ram_read_address(external_ram_read_address),
			.start_external_ram_read(start_read),
			.line_buffer_write_enable(Pixel_wen),
			.Data_to_write_in_line_buffer(Pixel_In),
			.line_buffer_write_address(Pixel_write_addr),
			.READ(READ),
			.RAM_BUSY()
	);
	
	 // ----- COMPENZAR LATENCIA -----
    wire rx_vsync__lat_fix, rx_active__lat_fix;
	 
	 reg [30:0] rx_vsync__lat_pip = 0;
	 reg [30:0] rx_active__lat_pip = 0;
	 
	 assign rx_vsync__lat_fix 	= (Capture_Latency < 1)? rx_vsync: rx_vsync__lat_pip[Capture_Latency-1];
	 assign rx_active__lat_fix = (Capture_Latency < 1)? rx_active: rx_active__lat_pip[Capture_Latency-1];
	 
	 always @( posedge rx_p_clk_x1 ) begin
       rx_vsync__lat_pip 	<= { rx_vsync__lat_pip[29:0], rx_vsync };
       rx_active__lat_pip  <= { rx_active__lat_pip[29:0], rx_active };
    end
	 
	
	mem_video__writer mem_video (	
			.mem_clk(EXTERNAL_RAM_INTERNAL_CLK),
			.vid_clk(rx_p_clk_x1),
			.v_sync(rx_vsync__lat_fix),
			.data_valid(rx_active__lat_fix),
			.DATA_in(DATA_TO_RAM),
			.StartUploading(StartUploading),
			.ReadyWrite(ReadyWrite),
			.Memory_Data(data_write),
			.external_ram_write_address(external_ram_write_address),
			.start_external_ram_write(start_write),
			.WRITE(WRITE)
	);

	reg temp = 1;				
	always @(posedge EXTERNAL_RAM_INTERNAL_CLK) begin
		if (ReadyConfig) begin
			start_config<=temp;
			temp<=0;
		end
	end

endmodule
