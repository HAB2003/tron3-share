`timescale 1ns/1ps

module camera_stream_tb;

  localparam int N_COLS = 640;
  localparam int N_ROWS = 480;
  localparam int FRONT_PORCH = 10;
  localparam int TOTAL_PIXELS = N_COLS * N_ROWS;
  localparam int ADDR_W = $clog2(TOTAL_PIXELS); 
	logic [7:0] image [0:N_COLS*2-1];

	initial begin
	  $readmemh("colorbars.hex", image);
	end
  logic        pclk;
  logic        href;
  logic        vsync;
  logic [7:0]  D;
  logic [11:0] pixel;
  logic [16:0] addr;
  logic        we;

  ov7670_pixel_capture DUT1 (
    .pclk (pclk),
    .vsync(vsync),
    .href (href),
    .d    (D),
    .addr (addr),
    .pixel(pixel),
    .we   (we)
  );

 
  initial pclk = 1'b0;
  always  #10 pclk = ~pclk;  


  initial begin
    href  = 1'b0;
    vsync = 1'b1;   
    D     = '0;
	 addr = '0;
  end


  initial begin
    repeat (10) @(posedge pclk);
    vsync <= 1'b0; 

    for (int row = 0; row < N_ROWS; row++) begin
      for (int j = 0; j < FRONT_PORCH; j++) @(posedge pclk);
      for (int col_byte = 0; col_byte < N_COLS*2; col_byte++) begin
        @(posedge pclk);
		  href <= 1'b1;
        D <= image[col_byte];
      end
      @(posedge pclk) href <= 1'b0;
    end


    @(posedge pclk) vsync <= 1'b1;
    repeat (10) @(posedge pclk);
    @(posedge pclk) vsync <= 1'b0;

  
    repeat (50) @(posedge pclk);
    $finish;
  end

endmodule