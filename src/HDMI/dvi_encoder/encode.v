//////////////////////////////////////////////////////////////////////////////
//
//  Xilinx, Inc. 2008                 www.xilinx.com
//
//////////////////////////////////////////////////////////////////////////////
//
//  File name :       encode.v
//
//  Description :     TMDS encoder  
//
//  Date - revision : Jan. 2008 - v 1.0
//
//  Author :          Bob Feng
//
//////////////////////////////////////////////////////////////////////////////  
//`default_nettype none
`timescale 1 ps / 1ps

/*
 Pipeline de 3 etapas



*/


module encode (
  input wire       p_clk_x1, // pixel clock input
  input wire       rstin,    // async. reset input (active high)
  input wire [7:0] din,      // data inputs: expect registered
  input wire       c0,       // c0 input
  input wire       c1,       // c1 input
  input wire       de,       // de input
  output reg [9:0] dout      // data outputs
);


// TODO: Añadir bloque generate para tener entradas opcionales de datos auxiliares (que ahora están como obligatorios)
// Solo se ocupan en el canal azul para el Hsync y el Vsync
// En los canales rojo y verde se envían datos auxiliares, que no son necesarios siempre
// Estos bits auxiliares deben ser mantenidos en valores logicos de 0


    parameter simple_encoder = 0;
    parameter aux_data_constant = 0;
    
    // Implementacion del módulo
    localparam use_XOR = 1;
    localparam invert_data = 0;
    
    
    
    
    // Datos de control
                              //0b1101010100
    localparam CTRL_TOKEN_0 = 10'b1101010100;
                              //0b0010101011
    localparam CTRL_TOKEN_1 = 10'b0010101011;
                              //0b0101010100
    localparam CTRL_TOKEN_2 = 10'b0101010100;
                              //0b1010101011
    localparam CTRL_TOKEN_3 = 10'b1010101011;



    




generate

// Modo simplificado
if( simple_encoder == 1 ) begin


    // Hacer pipeline
    reg [7:0] din_q;
    reg [7:0] q_m; // para asignaciones bloqueantes
    reg [7:0] q_m_reg;
    reg       de_q, de_reg;
    wire      c0_final, c1_final;
    
    always @( posedge p_clk_x1 ) begin
    
        din_q   <= din;  // 1
        q_m_reg <= q_m;  // 2
    
        de_q    <= de;   // 1
        de_reg  <= de_q; // 2
    end
    
    
    
    // --- Generación condicional de código ---
    // Datos constantes, no es necesario pasarlos por el pipeline
    if( aux_data_constant == 1 ) begin
        assign c0_final = c0;
        assign c1_final = c1;
    end
    // Datos variables, generar pipeline
    else begin
        // Registros de pipeline
        reg       c0_q, c1_q;
        reg       c0_reg, c1_reg;
        
        assign c0_final = c0_reg;
        assign c1_final = c1_reg;
        
        always @( posedge p_clk_x1 ) begin
            c0_q    <= c0;   // 1
            c0_reg  <= c0_q; // 2
            
            c1_q    <= c1;   // 1
            c1_reg  <= c1_q; // 2        
        end
    end

    // Etapa 1: Añadir bit 9 aplicando XOR o XNOR
    
    
    
    // XOR
    if( use_XOR == 1 ) begin
        always @( * ) begin
            q_m[0] = din_q[0];
            q_m[1] = q_m[0] ^ din_q[1];
            q_m[2] = q_m[1] ^ din_q[2];
            q_m[3] = q_m[2] ^ din_q[3];
            q_m[4] = q_m[3] ^ din_q[4];
            q_m[5] = q_m[4] ^ din_q[5];
            q_m[6] = q_m[5] ^ din_q[6];
            q_m[7] = q_m[6] ^ din_q[7];
        end
    end
    // XNOR
    else begin
        always @( * ) begin
            q_m[0] = din_q[0];
            q_m[1] = q_m[0] ^~ din_q[1];
            q_m[2] = q_m[1] ^~ din_q[2];
            q_m[3] = q_m[2] ^~ din_q[3];
            q_m[4] = q_m[3] ^~ din_q[4];
            q_m[5] = q_m[4] ^~ din_q[5];
            q_m[6] = q_m[5] ^~ din_q[6];
            q_m[7] = q_m[6] ^~ din_q[7];
        end
    end
    
    
    // Etapa 2: Añadir bit 10 invirtiendo o no los datos
    wire [9:0] q_final;
    
    // No invertir
    if( invert_data == 0 ) begin
        assign q_final[7:0] = q_m_reg[7:0];
    end
    // Invertir
    else begin
        assign q_final[7:0] = ~q_m_reg[7:0];
    end
    
    assign q_final[8] = use_XOR;
    assign q_final[9] = invert_data;
    
    // Etapa final: Decidir salida, incluyendo caracteres de control
    always @( posedge p_clk_x1 or posedge rstin ) begin
        if( rstin ) begin
            dout <= 10'd0;
        end
        else begin
            // Video activo
            if( de_reg ) begin
                dout <= q_final;
            end
            // Bits de control y datos
            else begin
                case ({c1_final, c0_final})
                    2'b00:   dout <= CTRL_TOKEN_0;
                    2'b01:   dout <= CTRL_TOKEN_1;
                    2'b10:   dout <= CTRL_TOKEN_2;
                    default: dout <= CTRL_TOKEN_3;
                endcase
            end
        end
        
        
    end


end
// Modo completo (standard compliant)
else begin

 ////////////////////////////////////////////////////////////
  // Counting number of 1s and 0s for each incoming pixel
  // component. Pipe line the result.
  // Register Data Input so it matches the pipe lined adder
  // output
  ////////////////////////////////////////////////////////////
  reg [3:0] n1d; //number of 1s in din
  reg [7:0] din_q;

  always @( posedge p_clk_x1 ) begin
    n1d <=#1 din[0] + din[1] + din[2] + din[3] + din[4] + din[5] + din[6] + din[7];

    din_q <=#1 din;
  end

  ///////////////////////////////////////////////////////
  // Stage 1: 8 bit -> 9 bit
  // Refer to DVI 1.0 Specification, page 29, Figure 3-5
  ///////////////////////////////////////////////////////
  // Desición de aplicar XOR o XNOR a los 8 bits dependiendo de la cantidad de 1 y 0
  // decision1 = 0: Aplicar XOR
  // decision1 = 1: Aplicar XNOR
  wire decision1 = (n1d > 4'h4) | ( (n1d == 4'h4) & (din_q[0] == 1'b0) );

/*
  reg [8:0] q_m;
  always @ (posedge p_clk_x1) begin
    q_m[0] <=#1 din_q[0];
    q_m[1] <=#1 (decision1) ? (q_m[0] ^~ din_q[1]) : (q_m[0] ^ din_q[1]);
    q_m[2] <=#1 (decision1) ? (q_m[1] ^~ din_q[2]) : (q_m[1] ^ din_q[2]);
    q_m[3] <=#1 (decision1) ? (q_m[2] ^~ din_q[3]) : (q_m[2] ^ din_q[3]);
    q_m[4] <=#1 (decision1) ? (q_m[3] ^~ din_q[4]) : (q_m[3] ^ din_q[4]);
    q_m[5] <=#1 (decision1) ? (q_m[4] ^~ din_q[5]) : (q_m[4] ^ din_q[5]);
    q_m[6] <=#1 (decision1) ? (q_m[5] ^~ din_q[6]) : (q_m[5] ^ din_q[6]);
    q_m[7] <=#1 (decision1) ? (q_m[6] ^~ din_q[7]) : (q_m[6] ^ din_q[7]);
    q_m[8] <=#1 (decision1) ? 1'b0 : 1'b1;
  end
*/

  // Resultado de primer paso; Aplicar XOR o XNOR a los 8 bits
  wire [8:0] q_m;
  assign q_m[0] = din_q[0];
  assign q_m[1] = (decision1) ? (q_m[0] ^~ din_q[1]) : (q_m[0] ^ din_q[1]);
  assign q_m[2] = (decision1) ? (q_m[1] ^~ din_q[2]) : (q_m[1] ^ din_q[2]);
  assign q_m[3] = (decision1) ? (q_m[2] ^~ din_q[3]) : (q_m[2] ^ din_q[3]);
  assign q_m[4] = (decision1) ? (q_m[3] ^~ din_q[4]) : (q_m[3] ^ din_q[4]);
  assign q_m[5] = (decision1) ? (q_m[4] ^~ din_q[5]) : (q_m[4] ^ din_q[5]);
  assign q_m[6] = (decision1) ? (q_m[5] ^~ din_q[6]) : (q_m[5] ^ din_q[6]);
  assign q_m[7] = (decision1) ? (q_m[6] ^~ din_q[7]) : (q_m[6] ^ din_q[7]);
  assign q_m[8] = (decision1) ? 1'b0 : 1'b1;

  /////////////////////////////////////////////////////////
  // Stage 2: 9 bit -> 10 bit
  // Refer to DVI 1.0 Specification, page 29, Figure 3-5
  /////////////////////////////////////////////////////////
  reg [3:0] n1q_m, n0q_m; // number of 1s and 0s for q_m
  always @ (posedge p_clk_x1) begin
    n1q_m  <=#1 q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
    n0q_m  <=#1 4'h8 - (q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7]);
  end

  

  reg [4:0] cnt = 0; //disparity counter, MSB is the sign bit
  wire decision2, decision3;

  assign decision2 = (cnt == 5'd0) | (n1q_m == n0q_m);
  /////////////////////////////////////////////////////////////////////////
  // [(cnt > 0) and (N1q_m > N0q_m)] or [(cnt < 0) and (N0q_m > N1q_m)]
  /////////////////////////////////////////////////////////////////////////
  assign decision3 = (~cnt[4] & (n1q_m > n0q_m)) | (cnt[4] & (n0q_m > n1q_m));

  ////////////////////////////////////
  // pipe line alignment
  ////////////////////////////////////
  reg       de_q, de_reg;
  wire      c0_final, c1_final;
  reg [8:0] q_m_reg;

  always @ (posedge p_clk_x1) begin
    de_q    <=#1 de;
    de_reg  <=#1 de_q;
    
    

    q_m_reg <=#1 q_m;
  end


  // Datos constantes, no es necesario pasarlos por el pipeline
    if( aux_data_constant == 1 ) begin
        assign c0_final = c0;
        assign c1_final = c1;
    end
    // Datos variables, generar pipeline
    else begin
        // Registros de pipeline
        reg       c0_q, c1_q;
        reg       c0_reg, c1_reg;
        
        assign c0_final = c0_reg;
        assign c1_final = c1_reg;
        
        always @( posedge p_clk_x1 ) begin
            c0_q    <= c0;   // 1
            c0_reg  <= c0_q; // 2
            
            c1_q    <= c1;   // 1
            c1_reg  <= c1_q; // 2        
        end
    end

  
  ///////////////////////////////
  // 10-bit out
  // disparity counter
  ///////////////////////////////
  always @ (posedge p_clk_x1 or posedge rstin) begin
	// Reset
    if( rstin ) begin
      dout <= 10'd0;
      cnt <= 5'd0;
    end
	// Estado normal
	else begin
	  // Video activo
      if( de_reg ) begin
        if(decision2) begin
          dout[9]   <=#1 ~q_m_reg[8]; 
          dout[8]   <=#1 q_m_reg[8]; 
          dout[7:0] <=#1 (q_m_reg[8]) ? q_m_reg[7:0] : ~q_m_reg[7:0];

          cnt <=#1 (~q_m_reg[8]) ? (cnt + n0q_m - n1q_m) : (cnt + n1q_m - n0q_m);
        end
		else begin
          if(decision3) begin
            dout[9]   <=#1 1'b1;
            dout[8]   <=#1 q_m_reg[8];
            dout[7:0] <=#1 ~q_m_reg[7:0];

            cnt <=#1 cnt + {q_m_reg[8], 1'b0} + (n0q_m - n1q_m);
          end else begin
            dout[9]   <=#1 1'b0;
            dout[8]   <=#1 q_m_reg[8];
            dout[7:0] <=#1 q_m_reg[7:0];

            cnt <=#1 cnt - {~q_m_reg[8], 1'b0} + (n1q_m - n0q_m);
          end
        end
      end // Señales video activo
	  
	  // Señales de control
	  else begin
        case ({c1_final, c0_final})
          2'b00:   dout <=#1 CTRL_TOKEN_0;
          2'b01:   dout <=#1 CTRL_TOKEN_1;
          2'b10:   dout <=#1 CTRL_TOKEN_2;
          default: dout <=#1 CTRL_TOKEN_3;
        endcase

        cnt <=#1 5'd0;
      end // señales de control
    end // No en reset (operación normal)
  end // Always








end
endgenerate

  
endmodule
