module top_level(
	input 	logic 		 CLOCK_50,
	input  	logic        OV7670_PCLK,
	output 	logic        OV7670_XCLK,
	input 	logic        OV7670_VSYNC,
	input  	logic        OV7670_HREF,
	input  	logic [7:0]  OV7670_DATA,
	output 	logic        OV7670_SIOC,
	inout  	wire         OV7670_SIOD,
	output 	logic        OV7670_PWON,
	output 	logic        OV7670_RESET,

   input  logic [3:0] KEY,
   output logic [9:0] LEDR

);
	logic sys_reset = 1'b0;

	//Camera and VGA PLL
	logic       clk_25_vga;
	logic       clk_12_camera; 
	logic 		resend_camera_config	 = 1'b0;
	logic			video_pll_locked;
	logic 		config_finished;
	assign OV7670_XCLK = clk_25_vga;
	video_PLL U0(
		.refclk(CLOCK_50),  
		.rst(sys_reset),      
		.outclk_1(clk_25_vga), 
		.locked(video_pll_locked)   
	);
	
	//Camera programming and data stream
	logic [16:0] wraddress;
	logic [11:0] wrdata;
	logic wren;

	ov7670_controller U1(
		.clk(clk_25_vga),  
		.resend (resend_camera_config),
		.config_finished (config_finished),
		.sioc   (OV7670_SIOC),
		.siod   (OV7670_SIOD),
		.reset  (OV7670_RESET),
		.pwdn   (OV7670_PWON)
	);
	

	ov7670_pixel_capture DUT1 (
	.pclk(OV7670_PCLK),
	.vsync(OV7670_VSYNC),
	.href(OV7670_HREF),
	.d(OV7670_DATA),
	.addr(wraddress),
	.pixel(wrdata),
	.we(wren)
	);

	logic filter_sop_out;
	logic filter_eop_out;
	logic vga_ready;
	logic [11:0] video_data /*synthesis keep*/;
	wire vga_blank;  
	wire vga_sync;   


	image_buffer U3
	(
		.data_in(wrdata),
		.rd_clk(clk_25_vga),
		.wr_clk(OV7670_PCLK),
		.ready(vga_ready), 
		.rst(sys_reset),
		.wren(wren),
		.wraddress(wraddress), 
		.image_start(filter_sop_out),
		.image_end(filter_eop_out),
		.data_out(video_data)
	);

    wire [29:0] data_in = {
        {video_data[11:8], video_data[11:8], 2'b00},
        {video_data[ 7:4], video_data[ 7:4], 2'b00},
        {video_data[ 3:0], video_data[ 3:0], 2'b00},
    };
	
	logic centroid_flag;
	
    assign vga_ready = 1'b1;
	 assign LEDR[9:1] = 9'b0;
	 assign LEDR[0] = centroid_flag;

	centroid_colour_detector u_centroid_colour_detector (
		.clk(clk_25_vga),
		.reset(KEY[0]),
		.enable(1'b1),

		.centroid_flag(centroid_flag),

		.data_in(data_in),
		.startofpacket_in(filter_sop_out),
		.endofpacket_in(filter_eop_out),
		.ready_out(1'b1),
		.valid_in(1'b1),

		.ready_in(1'b1)
	);
	
endmodule
