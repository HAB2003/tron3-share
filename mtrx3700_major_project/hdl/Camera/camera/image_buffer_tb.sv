`timescale 1ns/1ps


module image_buffer_tb;


localparam int N_COLS = 640;
localparam int N_ROWS = 480;
localparam int TOTAL_PIXELS = N_COLS * N_ROWS;


  logic         rd_clk;
  logic 			 wr_clk;
  logic         rst;
  logic [11:0]  data_in;
  logic [16:0]  wraddress;
  logic         wren;
  logic         image_start;
  logic         image_end;
  logic [11:0]  data_out;
  logic			 vga_ready;	
  logic 			 VGA_HS;
  logic 			 VGA_VS;
  logic [7:0]   VGA_R;
  logic [7:0]   VGA_G;
  logic [7:0]   VGA_B;
  
	image_buffer DUT1
	(
		.data_in(data_in),
		.rd_clk(rd_clk),
		.wr_clk(wr_clk),
		.ready(vga_ready), 
		.rst(rst),
		.wren(wren),
		.wraddress(wraddress), 
		.image_start(image_start),
		.image_end(image_end),
		.data_out(data_out)
	);

	vga_driver DUT2(
		 .clk(rd_clk), 
		 .rst(rst),
		 .pixel(data_out),
		 .hsync(VGA_HS),
		 .vsync(VGA_VS),
		 .r(VGA_R),
		 .g(VGA_G),
		 .b(VGA_B),
		 .ready(vga_ready)
	);

  initial rd_clk = 0;
  initial wr_clk = 0;
  always #20 rd_clk = ~rd_clk; //25MHz
  always #20 wr_clk = ~wr_clk; //25MHz

	initial begin
		rst = 1;
		wren = 0;
		wraddress = 0;
		data_in = 0;
    repeat (5) @(posedge wr_clk);
    rst = 0;
	 $display("Writing pixels...");
    repeat (5) @(posedge wr_clk);
    rst = 0;
    $display("Writing pixels...");
    for (int i = 0; i < TOTAL_PIXELS; i++) begin
      @(posedge wr_clk);
      wren      = 1;
      wraddress = i;
      data_in      = i[11:0]; 
    end
    wren = 0;
	 repeat (100000) @(posedge rd_clk);
    // Read them back
	 

		
  end
endmodule