//`default_nettype none
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:56:40 11/10/2012 
// Design Name: 
// Module Name:    dvi_tx_fixed_res 
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
module dvi_tx_fixed_res(
    // Relojes
    p_clk_x1,
    p_clk_x2,
    p_clk_x10,
    serdesstrobe,
    // Coordenadas de pixel que debe salir
    hcount,
	vcount,
    // Datos de colores
	red_data,
	green_data,
	blue_data,
    // Video activo
	active,
    blanking_active_line,
    // Salidas diferenciales
	TMDS_OUT,
    TMDS_OUTB,
    // Reset
	reset,
	Display_Latency
);


    // ----- PARAMETROS -----
    // Resolucion
    parameter H_PIXELS  = 640;
    parameter V_LINES   = 480;
    // Duracion pulsos de sincronismo horizontal (pixels)
    parameter H_FN_PRCH = 16; // Front porch
    parameter H_SYNC_PW = 96; // Pulse width
    parameter H_BK_PRCH = 48; // Back porch
    // Duracion pulsos de sincronismo vertical (lineas)
    parameter V_FN_PRCH = 10; // Front porch
    parameter V_SYNC_PW = 2;  // Pulse width
    parameter V_BK_PRCH = 33; // Back porch
    // Polaridad de señales de sincronismo
    parameter [0:0] H_SYNC_POL = 0;
    parameter [0:0] V_SYNC_POL = 0;
    // Compenzar latencia(s)


    // ----- PARAMETROS LOCALES PARA CALCULAR LONGITUD DE PUERTAS -----
    localparam  H_COUNT_BITS = ceil_log2(H_PIXELS); // pixels
    localparam  V_COUNT_BITS = ceil_log2(V_LINES);  // lineas

    
    // ----- PUERTOS -----
    // Relojes
	 input wire [4:0] Display_Latency;
    input wire p_clk_x1;
    input wire p_clk_x2;
    input wire p_clk_x10;
    input wire serdesstrobe;
    // Coordenadas de pixel que debe salir
    output wire [H_COUNT_BITS-1:0] hcount;
	output wire [V_COUNT_BITS-1:0] vcount;
    // Datos de colores
	input wire [7:0] red_data;
	input wire [7:0] green_data;
	input wire [7:0] blue_data;
    // Video activo
	output wire active;
    output wire blanking_active_line;
    // Salidas diferenciales
	output wire [3:0] TMDS_OUT;
    output wire [3:0] TMDS_OUTB;
    // Reset
	input wire reset;



    // ----- TIMING CONTROLLER -----
    wire H_sync, V_sync, active_req_data, active_send;


    h_sync__v_sync__gen #(
        .H_PIXELS(H_PIXELS),
        .V_LINES(V_LINES),
        .H_FN_PRCH(H_FN_PRCH),
        .H_SYNC_PW(H_SYNC_PW),
        .H_BK_PRCH(H_BK_PRCH),
        .V_FN_PRCH(V_FN_PRCH),
        .V_SYNC_PW(V_SYNC_PW),
        .V_BK_PRCH(V_BK_PRCH),
        .H_SYNC_POL(H_SYNC_POL),
        .V_SYNC_POL(V_SYNC_POL)
    )
    hv(
        .h_count_req(hcount), //output
        .v_count_req(vcount), //output
        //
        .h_sync(H_sync), //output
        .v_sync(V_sync), //output
        //
        .restart(reset),
        .active_req_data(active_req_data),
        .active_send(active_send),
        .blanking_active_line(blanking_active_line),
        .clk(p_clk_x1)
	 );

    assign active = active_req_data;
	 
	 
	 // ----- COMPENZAR LATENCIA -----
    wire h_sinc__lat_fix, v_sync__lat_fix, active__lat_fix;
    
    reg [30:0] h_sinc__lat_pip = ~H_SYNC_POL;
    reg [30:0] v_sync__lat_pip = ~V_SYNC_POL;
    reg [30:0] active__lat_pip = 0;
	 
	 assign h_sinc__lat_fix = (Display_Latency < 1)? H_sync: h_sinc__lat_pip[Display_Latency-1];
	 assign v_sync__lat_fix = (Display_Latency < 1)? V_sync: v_sync__lat_pip[Display_Latency-1];
	 assign active__lat_fix = (Display_Latency < 1)? active_send: active__lat_pip[Display_Latency-1];
	 
	 always @( posedge p_clk_x1 ) begin
       h_sinc__lat_pip <= { h_sinc__lat_pip[29:0], H_sync };
       v_sync__lat_pip <= { v_sync__lat_pip[29:0], V_sync };
       active__lat_pip <= { active__lat_pip[29:0], active_send };
    end
	 
	 


    // ----- TRANSMISOR -----
    dvi_encoder_top dvi_tx0 (
        .pclk        (p_clk_x1),
        .pclkx2      (p_clk_x2),
        .pclkx10     (p_clk_x10),
        .serdesstrobe(serdesstrobe),
        .rstin       (reset),
        .blue_din    (blue_data),
        .green_din   (green_data),
        .red_din     (red_data),
        .hsync       (h_sinc__lat_fix),
        .vsync       (v_sync__lat_fix),
        .de          (active__lat_fix),
        .TMDS        (TMDS_OUT),
        .TMDSB       (TMDS_OUTB)
    );




    // calcula bits necesarios para representar el argumento "value"
    // Evaluada en tiempo de sintesis
	function integer ceil_log2( input [31:0] in_number );
    begin
        for( ceil_log2 = 0; in_number > 0; ceil_log2 = ceil_log2 + 1 )
          in_number = in_number >> 1;
    end
    endfunction


endmodule
