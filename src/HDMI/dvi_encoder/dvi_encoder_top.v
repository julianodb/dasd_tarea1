//////////////////////////////////////////////////////////////////////////////
//
//////////////////////////////////////////////////////////////////////////////
//`default_nettype none
`timescale 1 ns / 1ps

module dvi_encoder_top (
  input  wire       pclk,           // pixel clock
  input  wire       pclkx2,         // pixel clock x2
  input  wire       pclkx10,        // pixel clock x2
  input  wire       serdesstrobe,   // OSERDES2 serdesstrobe
  input  wire       rstin,          // reset
  input  wire [7:0] blue_din,       // Blue data in
  input  wire [7:0] green_din,      // Green data in
  input  wire [7:0] red_din,        // Red data in
  input  wire       hsync,          // hsync data
  input  wire       vsync,          // vsync data
  input  wire       de,             // data enable
  output wire [3:0] TMDS,
  output wire [3:0] TMDSB);
    
  wire 	[9:0]	red;
  wire 	[9:0]	green;
  wire 	[9:0]	blue;

  wire [4:0] tmds_data0, tmds_data1, tmds_data2;
  wire [2:0] tmdsint;
  
  
  
  
  // ----- Realizar conversion de 8 bits a 10 bits, 1 encoder por canal -----
  localparam simple_ecoders = 0;
  
  encode #(
    .simple_encoder(simple_ecoders),
    .aux_data_constant(0)
  )
  encb (
    .p_clk_x1  (pclk),
    .rstin     (rstin),
    .din       (blue_din),
    .c0        (hsync),
    .c1        (vsync),
    .de        (de),
    .dout      (blue)
  );

  encode #(
    .simple_encoder(simple_ecoders),
    .aux_data_constant(1)
  )
  encg (
    .p_clk_x1	(pclk),
    .rstin	(rstin),
    .din		(green_din),
    .c0			(1'b0),
    .c1			(1'b0),
    .de			(de),
    .dout		(green)) ;
    
  encode #(
    .simple_encoder(simple_ecoders),
    .aux_data_constant(1)
  )
  encr (
    .p_clk_x1	(pclk),
    .rstin	(rstin),
    .din		(red_din),
    .c0			(1'b0),
    .c1			(1'b0),
    .de			(de),
    .dout		(red)) ;
  
  
  
  
  // ----- Serializar datos -----
  
  // 30 bits a 15 bits. Todos los canales (3) juntos
  wire [29:0] s_data = {red[9:5], green[9:5], blue[9:5],
                        red[4:0], green[4:0], blue[4:0]};

  convert_30to15_fifo pixel2x (
    .rst     (rstin),
    .clk     (pclk),
    .clkx2   (pclkx2),
    .datain  (s_data),
    .dataout ({tmds_data2, tmds_data1, tmds_data0}));
  
  // 5 bits a 1 bit. 1 serializador por canal, 3 en total
  serdes_n_to_1 #(.SF(5)) oserdes0 (
             .ioclk(pclkx10),
             .serdesstrobe(serdesstrobe),
             .reset(rstin),
             .gclk(pclkx2),
             .datain(tmds_data0),
             .iob_data_out(tmdsint[0])) ;

  serdes_n_to_1 #(.SF(5)) oserdes1 (
             .ioclk(pclkx10),
             .serdesstrobe(serdesstrobe),
             .reset(rstin),
             .gclk(pclkx2),
             .datain(tmds_data1),
             .iob_data_out(tmdsint[1])) ;

  serdes_n_to_1 #(.SF(5)) oserdes2 (
             .ioclk(pclkx10),
             .serdesstrobe(serdesstrobe),
             .reset(rstin),
             .gclk(pclkx2),
             .datain(tmds_data2),
             .iob_data_out(tmdsint[2])) ;


  // Serializar reloj TMDS
  reg [4:0] tmdsclkint = 5'b00000;
  reg toggle = 1'b0;
  
  // 10 bits a 5 bits
  // Proceso simple, pues solo tiene valores constantes, 0 ó 1
  always @ (posedge pclkx2 or posedge rstin) begin
    if (rstin)
      toggle <= 1'b0;
    else
      toggle <= ~toggle;
  end

  always @ (posedge pclkx2) begin
    if (toggle)
      tmdsclkint <= 5'b11111;
    else
      tmdsclkint <= 5'b00000;
  end

  wire tmdsclk;
  
  // 5 bits a 1 bit
  serdes_n_to_1 #(
    .SF           (5))
  clkout (
    .iob_data_out (tmdsclk),
    .ioclk        (pclkx10),
    .serdesstrobe (serdesstrobe),
    .gclk         (pclkx2),
    .reset        (rstin),
    .datain       (tmdsclkint));


  // ----- Generar salida diferenncial (TMDS) -----
  OBUFDS TMDS0 (.I(tmdsint[0]), .O(TMDS[0]), .OB(TMDSB[0])) ; // blue
  OBUFDS TMDS1 (.I(tmdsint[1]), .O(TMDS[1]), .OB(TMDSB[1])) ; // Red
  OBUFDS TMDS2 (.I(tmdsint[2]), .O(TMDS[2]), .OB(TMDSB[2])) ; // Green
  OBUFDS TMDS3 (.I(tmdsclk),    .O(TMDS[3]), .OB(TMDSB[3])) ; // Clock
  

endmodule
