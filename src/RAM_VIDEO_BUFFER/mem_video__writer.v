//`default_nettype none
`timescale 1ns / 1ps

module mem_video__writer
	(
        // Relojes
		  mem_clk,
        vid_clk,
        
        // Interfaz al módulo entrada de video (con reloj de video)
        v_sync,
        data_valid,

        DATA_in,
        // Interfaz con memoria externa
		  StartUploading,
		  ReadyWrite,
		  Memory_Data,
		  external_ram_write_address,
		  start_external_ram_write,
		  WRITE
		  

	);


  // ---------- PARAMETROS ----------
    parameter        H_RES_PIX  = 640;
    parameter        V_RES_PIX  = 480;
    parameter [15:0] BASE_ADDR  = 0;

    
  // ---------- PARAMETROS LOCALES ----------
    // Bits necesarios para puertos
    localparam H_ADDR_BITS = ceil_log2( H_RES_PIX - 1 );
    localparam V_ADDR_BITS = ceil_log2( V_RES_PIX - 1 ); 
    

    
    
  // ---------- ENTRADAS Y SALIDAS ----------
    // Relojes
    input  wire                  mem_clk;
    input  wire                  vid_clk;
    
    // Interfaz al módulo entrada de video (con reloj de video)
    input wire                   v_sync;
    input wire                   data_valid;

	 input wire	[15:0]				DATA_in;
    
    // Interfaz con memoria externa
	 input wire							StartUploading;
	 input wire							ReadyWrite;
	 output wire [15:0]				Memory_Data;
	 output wire [22:0]				external_ram_write_address;
	 output wire						start_external_ram_write;
	 output wire						WRITE;
	
	
	 reg                   line_ready   = 0;
	// ---------- MÓDULO ----------
	
    // Salidas para controlar la block ram
    wire [H_ADDR_BITS-1:0]  data_in__addr;
    reg  [15:0]             data_in = 0;


    // Control del dispatcher
    reg        write_line  = 0;
    reg [29:0] init_add_wr = 0;   
   
   
    // Buffer de linea
    reg [15:0] line_buffer [H_RES_PIX-1:0];
   

    // Escribir en memoria externa (leer de block ram con reloj de la memoria)
    always @( posedge mem_clk ) begin
        data_in[15:0] = line_buffer[data_in__addr];
    end

    // Maquina de estados (escribir video recibido en buffer)
    reg [1:0]             state        = 0;
    //
    reg [H_ADDR_BITS-1:0] h_count      = 0;
    reg [V_ADDR_BITS-1:0] v_count      = 0;
	 reg [V_ADDR_BITS-1:0] v_line      = 0;
    //
    reg [1:0]             v_sync_shift = 0;
    
    
    always @( posedge vid_clk ) begin
    
        // Escribir en blockram solo cuando se reciban pixels activos
        if( data_valid ) begin
            line_buffer[h_count] <= DATA_in;
        end

        v_sync_shift <= { v_sync_shift[0], v_sync };    
        // Estado 0: Esperando Vsync
        if( state == 0 ) begin
            h_count     <= 0;
            v_count     <= 0;
            line_ready  <= 0;            
            if( (v_sync_shift == 2'b01) || (v_sync_shift == 2'b10) )
                state <= 1;
        end
        
        // Estado 1: Esperar primer pixel activo
        if( state == 1 ) begin
            if( data_valid ) begin
                h_count <= h_count + 1'b1;
                state   <= 2;
            end
        end


        // Estado 2: Recibir el resto de los pixels de la linea
        if( state == 2 ) begin
            // Direcciones de escritura
				//El reloj de memoria es 3.2 veces más rapido que el de video.
				//Hacemos esto para no "pisarnos la cola" en caso de que haya una
				//lectura de memoria en progreso y nos "atrasemos" en la escritura.
				if (h_count == H_RES_PIX-(H_RES_PIX/4)) begin
				    line_ready  <= 1;			//tenemos que adelantarnos 
					 v_line		<= v_count;		//un poco debido a los requerimientos de memoria
				end
				
            if( h_count == H_RES_PIX-1 ) begin
                h_count     <= 0;
                state       <= 3;
            end
            else begin
                h_count <= h_count + 1'b1;
            end
        end // Estado 2
        // Estado 3: Linea recibida
        if( state == 3 ) begin        
            line_ready <= 0;            
            // Frame recibida
            if( v_count == V_RES_PIX-1 ) begin
                v_count <= 0;
                state   <= 0;
            end
            else begin
                v_count <= v_count + 1'b1;
                state   <= 1;
            end
        end // Estado 3
    end // always
   

   
	 //assign Memory_Data = {data_in__addr[9:5],data_in__addr[9:4],data_in__addr[9:5]};
    // -- Dar señal de inicio --
    write_line mem_video_writer(.memory_clk(mem_clk),.Write_Line(line_ready),
											.v_line(v_line),
											.StartUploading(StartUploading),
											.ReadyWrite(ReadyWrite),
											.Memory_Data(Memory_Data),
											.external_ram_write_address(external_ram_write_address),
											.start_external_ram_write(start_external_ram_write),
											.line_buffer_read_address(data_in__addr),
											.Data_to_read_from_line_buffer(data_in),
											.WRITE(WRITE)
											);

    
    
    
  // ---------- FUNCIONES ----------
    // calcula bits necesarios para representar el argumento "in_number"
    // Evaluada en tiempo de sintesis
	function integer ceil_log2( input [31:0] in_number );
    begin
        for( ceil_log2 = 0; in_number > 0; ceil_log2 = ceil_log2 + 1 )
          in_number = in_number >> 1;
    end
    endfunction
    
    
    
endmodule
