module top_level(
	input 	logic 		 CLOCK_50,
	input  	logic        OV7670_PCLK,
	output 	logic        OV7670_XCLK,
	input 	logic        OV7670_VSYNC,
	input  	logic        OV7670_HREF,
	input  	logic [7:0]  OV7670_DATA,
	output 	logic        OV7670_SIOC,
	inout  	wire         OV7670_SIOD,
	output 	logic        OV7670_PWDN,
	output 	logic        OV7670_RESET,
	
	output logic        VGA_HS,
	output logic        VGA_VS,
	output logic [7:0]  VGA_R,
	output logic [7:0]  VGA_G,
	output logic [7:0]  VGA_B,
	output logic        VGA_BLANK_N,
	output logic        VGA_SYNC_N,
	output logic        VGA_CLK,
	
	output logic [17:0] LEDR, 
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,

	input logic [3:0]   KEY

);
	wire sys_reset = ~KEY[0];
	wire rst_n = KEY[0]; 
	localparam int WIDTH = 640; 
	localparam int HEIGHT = 480; 

	//Camera and VGA PLL
	logic       clk_video;
	logic 		send_camera_config; assign send_camera_config = !KEY[2];
	logic			video_pll_locked;
	logic 		config_finished;
	assign OV7670_XCLK = clk_video;
	
	video_pll U0(
		 .areset(sys_reset),
		 .inclk0(CLOCK_50),
		 .c0(clk_video),
		 .locked(video_pll_locked)
	);
	
	//Camera programming and data stream
	logic [16:0] wraddress;
	logic [11:0] wrdata;
	logic wren;

	ov7670_controller U1(
		.clk(clk_video),  
		.resend (send_camera_config),
		.config_finished (config_finished),
		.sioc   (OV7670_SIOC),
		.siod   (OV7670_SIOD),
		.reset  (OV7670_RESET),
		.pwdn   (OV7670_PWDN)
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
	logic [11:0] video_data;
	wire vga_blank;  
	wire vga_sync;   


	image_buffer U3
	(
		.data_in(wrdata),
		.rd_clk(clk_video),
		.wr_clk(OV7670_PCLK),
		.ready(wrapper_ready), 
		.rst(sys_reset),
		.wren(wren),
		.wraddress(wraddress), 
		.image_start(filter_sop_out),
		.image_end(filter_eop_out),
		.data_out(video_data)
	);
	assign VGA_CLK = clk_video;
	
	
	logic wrapper_ready; 
	
	logic avalon_sop_out;
	logic avalon_eop_out;
	logic [29:0] data_avalon;
	logic avalon_valid_out; 
	logic avalon_ready_in; 
	
	
	// Add image buffer to AVALON-ST buffer 
	image_to_avalon_wrapper U3a 
	(
		.clk(clk_video), 
		.rst(KEY[0]), 
		
		.data_out(video_data), 
		.image_start(filter_sop_out), 
		.image_end(filter_eop_out), 
		.ready(wrapper_ready),
		
		.data_out_avalon(data_avalon), 
		.startofpacket_out(avalon_sop_out), 
		.endofpacket_out(avalon_eop_out), 
		.valid_out(avalon_valid_out), 
		.ready_in(pixel_ready), 
		
	);  
	
	
	logic pixel_ready;
	
	logic [29:0] pixel_data_out;         
	logic        pixel_sop_out; 
   logic        pixel_eop_out;   
   logic        pixel_valid_out;        
	

	centroid_colour_detector #(
		.WIDTH(WIDTH),
		.HEIGHT(HEIGHT)
	) U3b (
		.clk(clk_video), 
		.reset(KEY[0]), 
		.enable(1'b1), 
		
		.centroid_flag(LEDR[1]), 
		
		.data_in(data_avalon),
		.startofpacket_in(avalon_sop_out),
		.endofpacket_in(avalon_eop_out),
		.valid_in(avalon_valid_out),
		.ready_out(pixel_ready),
		
		.data_out(pixel_data_out), 
		.startofpacket_out(pixel_sop_out), 
		.endofpacket_out(pixel_eop_out), 
		.valid_out(pixel_valid_out), 
		.ready_in(vga_ready)
	
	);  

	 
	 wire clk = clk_video;
	  // Thresholding and binarizing
	  logic [29:0] data_thres;
	  logic sop_thres, eop_thres, valid_thres, ready_thres;

	  logic ready_edge;


	  global_threshold u_global_threshold (
		 .clk,
		 .rst_n(KEY[0]),
		 .enable(1'b1),

		 .data_i(data_avalon),
		 .startofpacket_i(avalon_sop_out),
		 .endofpacket_i(avalon_eop_out),
		 .valid_i(avalon_valid_out),
		 .ready_o(ready_thres),

		 .data_o(data_thres),
		 .startofpacket_o(sop_thres),
		 .endofpacket_o(eop_thres),
		 .valid_o(valid_thres),
		 .ready_i(ready_edge)
	  );
	  
	  
	  
	  // Edge detection
	  localparam logic signed [9*16-1:0] edge_detect_kernel = {
		 16'sh0000, 16'shFF00, 16'sh0000,
		 16'shFF00, 16'sh0400, 16'shFF00,
		 16'sh0000, 16'shFF00, 16'sh0000
	  };

	  logic [29:0] data_edge;
	  logic sop_edge, eop_edge, valid_edge;

	  logic ready_bclose;

	  convolution_filter #(
		 .WIDTH(WIDTH),
		 .HEIGHT(HEIGHT),
		 .K(3),
		 .W(16),
		 .W_FRAC(8)
	  ) u_edge_detection (
		 .clk,
		 .rst_n(KEY[0]),
		 .enable(1'b1),

		 .kernel_flat(edge_detect_kernel),

		 .data_i         (data_thres),
		 .startofpacket_i(sop_thres),
		 .endofpacket_i  (eop_thres),
		 .valid_i        (valid_thres),
		 .ready_o        (ready_edge),

		 .data_o         (data_edge),
		 .startofpacket_o(sop_edge),
		 .endofpacket_o  (eop_edge),
		 .valid_o        (valid_edge),
		 .ready_i        (ready_bclose) 
	  );
	  
	  
	  // Perform binary closure
	  logic [29:0] data_bclose;
	  logic sop_bclose, eop_bclose, valid_bclose;
	  logic [$clog2(WIDTH*HEIGHT)-1:0] edge_counter;

	  binary_closing #(
		 .WIDTH(WIDTH),
		 .HEIGHT(HEIGHT)
	  ) u_binary_closing (
		 .clk,
		 .rst_n(KEY[0]),
		 .enable(1'b1),

		 .data_i         (data_edge),
		 .startofpacket_i(sop_edge),
		 .endofpacket_i  (eop_edge),
		 .valid_i        (valid_edge),
		 .ready_o        (ready_bclose),

		 .data_o         (data_bclose),
		 .startofpacket_o(sop_bclose),
		 .endofpacket_o  (eop_bclose),
		 .valid_o        (valid_bclose),
		 .ready_i        (vga_ready), // <---- comes from above
		 
		 .edge_counter(edge_counter)
	  );
	  
//	  // Candidate bounding box detection
//  logic [33:0] box_out;
//  logic bbox_valid;
//
//  wire [8:0] bbox_min_x = box_out[33:25];
//  wire [8:0] bbox_max_x = box_out[24:16];
//  wire [7:0] bbox_min_y = box_out[15:8];
//  wire [7:0] bbox_max_y = box_out[7:0];
//
//  LinkRunCCA u_link_run_cca (
//    .clk,
//    .rst(~rst_n),
//    .datavalid(valid_bclose),
//    .pix_in(data_bclose[29]),
//    .datavalid_out(bbox_valid),
//    .box_out(box_out)
//  );
//
//  // Selected bounding box
//  logic [33:0] bbox;
//  logic bbox_out_valid;
//
//  wire [8:0] bbox_out_min_x = bbox[33:25];
//  wire [8:0] bbox_out_max_x = bbox[24:16];
//  wire [7:0] bbox_out_min_y = bbox[15:8];
//  wire [7:0] bbox_out_max_y = bbox[7:0];
//
//  bbox_candidates u_bbox_candidates (
//    .clk,
//    .rst_n,
//
//    .bbox_valid(bbox_valid),
//    .box_in(box_out),
//    .frame_end(eop_bclose),
//    .bbox_out(bbox),
//    .bbox_out_valid(bbox_out_valid)
//  );
//
//  // Frame buffer to store the binary image
//  logic data_fb, sop_fb, eop_fb, valid_fb;
//  wire data_thres_1 = data_thres[29];
//
//  logic [8:0] bbox_min_x_reg, bbox_max_x_reg;
//  logic [7:0] bbox_min_y_reg, bbox_max_y_reg;
//  logic       bbox_has_reg;
//
//  always_ff @(posedge clk) begin
//    if (!rst_n) begin
//      // default to full frame until we have a real bbox
//      bbox_min_x_reg <= 9'd0;
//      bbox_max_x_reg <= WIDTH-1;
//      bbox_min_y_reg <= 8'd0;
//      bbox_max_y_reg <= HEIGHT-1;
//      bbox_has_reg   <= 1'b0;
//    end else if (bbox_out_valid) begin
//      bbox_min_x_reg <= bbox_out_min_x;   // from bbox_candidates output
//      bbox_max_x_reg <= bbox_out_max_x;
//      bbox_min_y_reg <= bbox_out_min_y;
//      bbox_max_y_reg <= bbox_out_max_y;
//      bbox_has_reg   <= 1'b1;
//    end
//  end
//
//  logic ready_fast;
//  logic ready_frame;
//  
//  
//  
//
//  frame_buffer #(
//    .WIDTH(WIDTH),
//    .HEIGHT(HEIGHT)
//  ) u_frame_buffer (
//    .clk            (clk),
//    .rst_n          (rst_n),
//
//    // Avalon-ST Sink
//    .data_i         (data_thres_1),
//    .startofpacket_i(sop_thres),
//    .endofpacket_i  (eop_thres),
//    .valid_i        (valid_thres),
//    .ready_o        (ready_frame),
//
//    // Avalon-ST Source
//    .data_o         (data_fb),
//    .startofpacket_o(sop_fb),
//    .endofpacket_o  (eop_fb),
//    .valid_o        (valid_fb),
//    .ready_i        (ready_fast)
//  );
//
//  // Perform FAST (Features from Accelerated Segment Test)
//
//  logic        done_fast;
//  logic [$clog2(WIDTH)-1:0]   corner_tl_x, corner_tr_x, corner_br_x,
//corner_bl_x;
//  logic [$clog2(HEIGHT)-1:0]  corner_tl_y, corner_tr_y, corner_br_y,
//corner_bl_y;
//
//	logic [$clog2(WIDTH*HEIGHT)-1:0] num_inner_corners; 
//
//  FAST #(
//    .WIDTH (WIDTH),
//    .HEIGHT(HEIGHT)
//  ) u_fast (
//    .clk,
//    .rst_n,
//
//    // Bounding box (latched per frame inside FAST)
//    .bbox_min_x      (bbox_min_x_reg),
//    .bbox_max_x      (bbox_max_x_reg),
//    .bbox_min_y      (bbox_min_y_reg),
//    .bbox_max_y      (bbox_max_y_reg),
//
//    // Avalon-ST sink (from frame buffer)
//    .data_i          (data_fb),
//    .startofpacket_i (sop_fb),
//    .endofpacket_i   (eop_fb),
//    .valid_i         (valid_fb),
//    .ready_o         (ready_fast),   // back-pressure to frame buffer
//
//    // 4-corner outputs (valid at frame end)
//    .done_o          (done_fast),
//    .corner_tl_x     (corner_tl_x),
//    .corner_tl_y     (corner_tl_y),
//    .corner_tr_x     (corner_tr_x),
//    .corner_tr_y     (corner_tr_y),
//    .corner_br_x     (corner_br_x),
//    .corner_br_y     (corner_br_y),
//    .corner_bl_x     (corner_bl_x),
//    .corner_bl_y     (corner_bl_y), 
//	 .num_inner_corners (num_inner_corners)
//  );
//
//  // Draw the bounding box and corners for display on VGA
//  logic [29:0] drawn_data;
//  logic drawn_sop, drawn_eop, drawn_valid, drawn_ready;
//  
//		 
//		
//  bbox_overlay u_bbox_overlay (
//    .clk,
//    .rst_n,
//
//    // Avalon-ST sink (input stream)
//    .s_valid        (avalon_valid_out),    // from upstream module
//    .s_ready        (drawn_ready),            // backpressure to upstream
//    .s_sop          (avalon_sop_out),
//    .s_eop          (avalon_eop_out),
//    .s_data         (data_avalon),
//
//    // Avalon-ST source (output stream)
//    .m_valid        (drawn_valid),
//    .m_ready        (vga_ready), // Input from downstream
//    .m_sop          (drawn_sop),
//    .m_eop          (drawn_eop),
//    .m_data         (drawn_data),
//
//    // Bounding box inputs
//    .bbox_min_x     (bbox_min_x_reg),
//    .bbox_max_x     (bbox_max_x_reg),
//    .bbox_min_y     (bbox_min_y_reg),
//    .bbox_max_y     (bbox_max_y_reg),
//
//    // Corner coordinates
//    .corner_tl_x    (corner_tl_x),
//    .corner_tl_y    (corner_tl_y),
//    .corner_tr_x    (corner_tr_x),
//    .corner_tr_y    (corner_tr_y),
//    .corner_br_x    (corner_br_x),
//    .corner_br_y    (corner_br_y),
//    .corner_bl_x    (corner_bl_x),
//    .corner_bl_y    (corner_bl_y)
//  );

// IMAGE PROCESSING STUFF ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	  // Display BPM on HEX
	display u_display_num_corners (
	  .clk(clk_video),
	  .value   (edge_counter),
	  .display0(HEX0),
	  .display1(HEX1),
	  .display2(HEX2),
	  .display3(HEX3)
	);
	  
	  
	  // Pack 30-bit filtered pixel back to 12-bit for VGA
    logic [11:0] pixel_for_vga;
    assign pixel_for_vga = {
        data_edge[29:26],  // R[3:0]
        data_edge[19:16],  // G[3:0]
        data_edge[9:6]     // B[3:0]
    };
		
		
	
	vga_driver U4(
		 .clk(clk_video), 
		 .rst(sys_reset),
		 .pixel(pixel_for_vga),
		 .hsync(VGA_HS),
		 .vsync(VGA_VS),
		 .r(VGA_R),
		 .g(VGA_G),
		 .b(VGA_B),
	    .VGA_BLANK_N(VGA_BLANK_N),
	    .VGA_SYNC_N(VGA_SYNC_N),
		 .ready(vga_ready)
	);
		
	
endmodule
