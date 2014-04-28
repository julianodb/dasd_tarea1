`default_nettype none
`timescale 1ns / 1ps
 
//////////////////////////////////////////////////////////////////////////////////
module top( 			
		/*PUERTOS DE USUARIO DEBAJO DE ESTA LINEA*/
		
/*ju*/input		wire	[1:0]		sw, 	// sw[1:0] switches 1 = MIN/MAX 0 = RGB/YUV
/*ju*/input		wire				btn,	// btn button switch R/G/B
/*ju*/output	wire	[7:0]		seg, 	// seg[7:0] 7 segments display
/*ju*/output	wire	[3:0]		an, 	// an[3:0] seg display select common anode
/*ju*/output	wire	[2:0]		Led, 	// Led[2:0] Leds 2=R, 1=G, 0=B, all=Y
		
		/*PUERTOS DE USUARIO ARRIBA DE ESTA LINEA*/

		/* reloj de la tarjeta */
		input 	wire 				clk,
		/* HDMI-IN */
		input 	wire 	[3:0] 	TMDS_IN, 
		input 	wire 	[3:0] 	TMDS_INB,
		/* HDMI-OUT */
		output 	wire 	[3:0] 	TMDS_OUT,
		output 	wire 	[3:0] 	TMDS_OUTB,
		/* EDID */
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
	
	reg 	[4:0] 	Display_Latency,Capture_Latency;
	wire 	[7:0] 	R_display,G_display,B_display;
	wire 	[7:0] 	R_capture,G_capture,B_capture;
	wire 	[15:0] 	PIXEL_DATA;
	wire	[15:0]	DATA_TO_RAM;
	wire				First_pixel,Last_pixel,Pixel_data_valid;
	wire global_clk,HDMI_Pixel_Clock_25MHz,EXTERNAL_RAM_INTERNAL_CLK,HDMI_CAPTURE_CLOCK;
	
/*ju*/wire				btn_pushed;
/*ju*/wire				btn_clock;
/*ju*/reg	[1:0]		curr_YRGB; // wich MAX/MIN is currently being displayed	
	
	HDMI_WRAPPER VLSI_HDMI_MEM_CURSO (
		//Puertos a pines de la tarjeta
		.clk(clk),
		.TMDS_IN(TMDS_IN),
		.TMDS_INB(TMDS_INB),
		.TMDS_OUT(TMDS_OUT),
		.TMDS_OUTB(TMDS_OUTB),
		.EDID_IN_SCL(EDID_IN_SCL),
		.EDID_IN_SDA(EDID_IN_SDA),
		.MemAdr_ext(MemAdr_ext),
		.MemDB(MemDB),
		.OE_out(OE_out),
		.WE_out(WE_out),
		.ADV_out(ADV_out),
		.MT_CLK(MT_CLK),
		.CE_out(CE_out),
		.CRE_out(CRE_out),
		.UB(UB),
		.LB(LB),
		.MemWait(MemWait),
		
		
		//Relojes de interes para el usuario
		.global_clk(global_clk), 											// 100 MHz, para lgica general.
		.HDMI_Pixel_Clock_25MHz(HDMI_Pixel_Clock_25MHz), 			// 25  MHz hacia HDMI.
		.EXTERNAL_RAM_INTERNAL_CLK(EXTERNAL_RAM_INTERNAL_CLK),	// 80  MHz.
		.HDMI_CAPTURE_CLOCK(HDMI_CAPTURE_CLOCK),						// 25  MHz desde HDMI.
		
		
		//Dato leido desde el buffer en RAM.
		.PIXEL_DATA(PIXEL_DATA), 
		//Pulsos que indican la llegada del primer y ultimo pixel desde RAM.
		.First_pixel(First_pixel),
		.Last_pixel(Last_pixel),
		
		//Esta seal indica que la salida de PIXEL_DATA es un dato vlido (Video activo).
		.Pixel_data_valid(Pixel_data_valid),
		
		//Datos a desplegar (ENTRADAS)
		.R_display(R_display),
		.G_display(G_display),
		.B_display(B_display),
		
		//Datos capturado por HDMI
		.R_capture(R_capture),
		.G_capture(G_capture),
		.B_capture(B_capture),
		
		//Datos a guardar en el buffer en RAM.
		.DATA_TO_RAM(DATA_TO_RAM),		
		
		//Latencia
		.Display_Latency(Display_Latency),
		.Capture_Latency(Capture_Latency)
	);	


	/************************LOGICA DE USUARIO*******************************/
	
/*ju*/
	slow_clk_gen scg(
		.fast_clk(global_clk),
		.slow_clk(btn_clock)
	);
	anti_bouncing ab(
		.slow_clk(btn_clock),
		.fast_clk(global_clk),
		.buton(btn),
		.single_pulse_push(btn_pushed)
	);
	initial curr_YRGB = 0;
	always @(posedge btn_pushed) curr_YRGB = curr_YRGB + 1;
	assign Led[0] = curr_YRGB[0] ~^ curr_YRGB[1];
	assign Led[1] = curr_YRGB[0];
	assign Led[2] = curr_YRGB[1];
/*ju*/
	
	/************************* CAPTURA DE VIDEO *****************************/
	/*   																					  		*/
	/*   	LOS DATOS QUE ESTAN A LA ENTRADA DE DATA_TO_RAM SE ALMACENAN 		*/	
	/*		EN MEMORIA EXTERNA CON UNA DIRECCION ASOCIADA A EL PIXEL DE 		*/
	/*		LA PANTALLA DEL CUAL PROVIENE.												*/
	/*		EN CASO QUE EXISTA UN PROCESO PREVIO A LA ESCRITURA DE MEMORIA 	*/
	/*		EN RAM (COMO POR EJEMPLO, TRANSFORMAR DE RGB A ESCALA DE GRISES)	*/
	/*		EXISTIRA UN RETARDO ASOCIADO, ESTE RETARDO PUEDE SER COMPENSADO	*/
	/*		RETRASANDO LAS SEALES QUE INICIAN Y CONTROLAN LA ESCRITURA DE 	*/
	/*		MEMORIA EN LA MISMA CANTIDAD DE CICLOS DE RELOJ (DEL RELOJ DE 		*/
	/*		CAPTURA) QUE DEMORA EL PROCESO.												*/
	/*		ESTE PROCESO SE ENCUENTRA AUTOMATIZADO INTERNAMENTE DENTRO DEL		*/
	/*		WRAPPER ENTREGADO Y EL RETRASO DE LAS SEALES SE PUEDE CONTROLAR	*/
	/*		UTILIZANDO EL REGISTRO "Capture_Latency"									*/
	/*																								*/
	/*		EJEMPLO:																				*/
	/*		reg [15:0]	ROJO Y VERDE;														*/
	/*		assign DATA_TO_RAM = ROJO_Y_VERDE;											*/
	/*		initial begin																		*/
	/*			Capture_Latency <= 1;														*/
	/*		end																					*/
	/*		always @(posedge HDMI_CAPTURE_CLOCK) begin								*/
	/*			ROJO_Y_VERDE <= {R_capture,G_capture};									*/
	/*		end																					*/
	/*																								*/
	/*		EN ESTE CASO ALMACENAMOS LOS VALORES DE PIXEL ROJO Y VERDE EN		*/
	/*		UNA VARIABLE Y ESTA VARIABLE SE ASIGNA A DATA_TO_RAM, ESTE 			*/
	/*		PROCESO TIENE UN RETRASO DE 1 CICLO DE RELOJ (ASIGNACION NO 		*/
	/*		BLOQUEANTE), POR LO QUE SE LE ASIGNA UN VALOR INCIAL DE 1 A			*/
	/*		"Capture_Latency" PARA COMPENSAR ESTE RETRASO.							*/
	/*																								*/
	/*		EL REGISTRO "Capture_Latency" soporta un valor mximo de 31			*/
	/*																								*/
	/*		EL CODIGO ESCRITO ABAJO GUARDA 5 BITS DE EL PIXEL ROJO, 6 BITS		*/
	/*		DEL PIXEL VERDE Y 5 BITS DEL PIXEL AZUL EN MEMORIA UTILIZANDO		*/
	/*		"assign" DIRECTAMENTE (OSEA UN CABLE), POR LO QUE POSEE UNA 		*/
	/*		LATENCIA DE 0 CICLOS. DATA_TO_RAM ES UN CABLE DE 16 BITS 			*/
	/*																								*/
	/************************************************************************/
	
	initial begin
		Capture_Latency <= 1;
	end
	
	reg [4:0] R;
	reg [5:0] G;
	reg [4:0] B;
	
	assign DATA_TO_RAM = {R, G, B}; 
	
	always @(posedge HDMI_CAPTURE_CLOCK) begin //reloj de captura
		//Fase uno.
		R <= R_capture>>3;
		G <= G_capture>>2;
		B <= B_capture>>3;

	end
	
	/*********************** DESPLIEGUE DE VIDEO ****************************/
	/*   																					  		*/
	/*   	LOS DATOS QUE FUERON ALMACENADOS EN RAM, SON LEIDOS CUANDO SEA 	*/
	/*		NECESARIO Y SE REPRESENTAN UTILIZANDO EL CABLE PIXEL_DATA			*/
	/*		(16 BITS). LA INFORMACION DE ESTE PIXEL DEBE DE SER INTERPRETADA	*/
	/*		O PROCESADA PARA OBTENER LOS VALORES DE "R_display", "G_display"	*/
	/*		Y "B_display". SI EL PROCESO DE INTERPRETACION/PROCESAMIENTO		*/
	/*		NO ES INMEDIATO Y PRESENTA UNA LATENCIA, ESTA PUEDE SER				*/
	/*		UTILIZANDO RETRASANDO LAS SEALES DE SINCRONISMO DEL VIDEO DE 		*/
	/*		DE SALIDA EN LA MISMA CANTIDAD DE CICLOS QUE DEMORA EL PROCESO		*/
	/*		DE INTERPRETAR/PROCESAR LOS DATOS PROVENIENTES DE MEMORA RAM		*/
	/*																								*/
	/*		ESTE PROCESO SE ENCUENTRA AUTOMATIZADO INTERNAMENTE DENTRO DEL		*/
	/*		WRAPPER ENTREGADO Y EL RETRASO DE LAS SEALES SE PUEDE CONTROLAR	*/
	/*		UTILIZANDO EL REGISTRO "Display_Latency"									*/
	/*																								*/
	/*		EJEMPLO:																				*/
	/*		reg [7:0] rojo,verde,azul														*/
	/*		assign R_display = rojo;														*/
	/*		assign G_display = verde;														*/
	/*		assign B_display = azul;														*/
	/*																								*/
	/*																								*/
	/*		initial begin																		*/
	/*			Display_Latency <= 1;														*/
	/*		end																					*/
	/*		always @(posedge HDMI_Pixel_Clock_25MHz) begin							*/
	/*			rojo 	<= PIXEL_DATA[15:8];													*/
	/*			verde	<=	PIXEL_DATA[7:0];													*/
	/*			azul	<= 8'd0;																	*/
	/*		end																					*/
	/*																								*/
	/*		EN EL EJEMPLO DE CAPTURA, SE ALMACENARON LOS VALORES ROJO Y			*/
	/*		VERDE DEL PIXEL EN RAM, AHORA EN EL PROCESO DE DESPLIEGUE			*/
	/*		RESTAURAMOS ESOS VALORES INTERPRETANDO CORRECTAMENTE LOS DATOS		*/
	/*		ESTE PROCESO TIENE UN RETRASO DE 1 CICLO DE RELOJ (ASIGNACION 		*/
	/*		NO BLOQUEANTE), POR LO QUE SE LE ASIGNA UN VALOR INCIAL DE 1 A		*/
	/*		"Display_Latency" PARA COMPENSAR ESTE RETRASO.							*/
	/*																								*/
	/*		EL REGISTRO "Display_Latency" soporta un valor mximo de 31			*/
	/*		EL CODIGO ESCRITO ABAJO INTERPRETA LOS COLORES DE LA MISMA MANERA	*/
	/*		EN QUE SE ALMACENARON EN MEMORIA RAM UTILIZANDO	"assign"				*/
	/*		DIRECTAMENTE (OSEA UN CABLE), POR LO QUE POSEE UNA LATENCIA DE		*/
	/*		0 CICLOS. PIXEL_DATA ES UN CABLE DE 16 BITS.								*/
	/*																								*/
	/*																								*/
	/************************************************************************/	
	
	/****DESPLIEGUE DE DATOS*****/
	reg [7:0] gris;
	initial begin
		Display_Latency <= 0;
	end
	
	assign R_display = PIXEL_DATA[15:11]<<3;
	assign G_display = PIXEL_DATA[10:5]<<2;
	assign B_display = PIXEL_DATA[4:0]<<3;
	
	//RELOJ DE DESPLIEGUE
	always @(posedge HDMI_Pixel_Clock_25MHz) begin
		
	end
	/****FIN DESPLIEGUE DE DATOS*****/

	/************************** FIN LOGICA DE USUARIO *************************/

endmodule
