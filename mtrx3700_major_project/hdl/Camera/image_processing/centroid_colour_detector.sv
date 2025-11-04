//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name: centroid_colour_detector
// Project Name: mtrx3700-assignment-major
// Target Devices: DE2-115
// Description: 
// 
// Dependencies:
// 
// Revision 0.01 - File Created
// 
//////////////////////////////////////////////////////////////////////////////////

module centroid_colour_detector #(
    parameter WIDTH = 320, 
    parameter HEIGHT = 240
)
(
    input  logic                        clk,
    input  logic                        reset,
    input  logic                        enable,          // Flag to enter SCAN state from state machine
    output logic                        centroid_flag, 
    output [$clog2(WIDTH)-1:0]          x_centroid, 
    output [$clog2(HEIGHT)-1:0]         y_centroid,

    // Avalon-ST Input
    input  logic [29:0] data_in,         // Pixel input from VGA source
    input  logic        startofpacket_in,// Start of packet signal
    input  logic        endofpacket_in,  // End of packet signal
    input  logic        valid_in,        // Input data is valid
    output logic        ready_out,        // We are ready for signal

    // Avalon-ST Output
    output logic [29:0] data_out,         // Pixel input to VGA
    output logic        startofpacket_out,// Start of packet signal
    output logic        endofpacket_out,  // End of packet signal
    output logic        valid_out,        // Data valid signal
    input  logic        ready_in         // Data ready signal from VGA
);

    // Extract RGB components from 30-bit input
    logic [7:0] r_in, g_in, b_in;
    logic [7:0] r_filtered, g_filtered, b_filtered;

    // Pipeline registers for Avalon-ST signals
    logic sop_out;
    logic eop_out;
    logic valid;
    logic [29:0] data_buffer;

    // Extract RGB components from input
    assign r_in = data_in[29:22];
    assign g_in = data_in[19:12];
    assign b_in = data_in[9:2];

    // Ready signal - we're ready for data (input) when downstream is ready (for our output)
    assign ready_out = ready_in;
    
    // Find horizontal image centre 
    localparam int horizontal_centre =  WIDTH / 2;

    // Assign a threshold to determine if pixel is red 
    logic red_pixel;
    assign red_pixel = (r_in > 8'd120) && (g_in < 8'd70) && (b_in < 8'd70);

//		assign red_pixel = (r_in < 8'd20) && (g_in < 8'd20) && (b_in < 8'd20);	

    // Set up counters and centroid variables 
    logic [$clog2(WIDTH)-1:0]           x_count; 
    logic [$clog2(HEIGHT)-1:0]          y_count; 
    logic [19:0]                        x_sum;  
    logic [19:0]                        y_sum; 
    logic [$clog2(WIDTH*HEIGHT)-1:0]    red_count;
    
    logic [23:0] red_count_reciprocal;
	 
	 logic [19:0] 								test_count; 

    reciprocal_lut u_reciprocal_lut (
        .x(red_count),
        .y(red_count_reciprocal)
    );

    // Counters for pixel locations
    always_ff @(posedge clk) begin 
        if (!reset) begin
            x_count       <= 0;
            y_count       <= 0;
            x_sum         <= 0;
            y_sum         <= 0;
            red_count     <= 0;
				test_count	  <= 0; 
        end 
		  else if (endofpacket_in) begin 
				    x_count       <= 0;
					 y_count       <= 0;
					 x_sum         <= 0;
					 y_sum         <= 0;
					 red_count     <= 0;
					 test_count    <= 0;
		  end 
		  else if (valid_in && ready_in) begin
            if (x_count == WIDTH - 1) begin
                x_count <= 0;
                if (endofpacket_in) begin 
                    y_count <= 0;
                end 
                else begin 
                    y_count <= y_count + 1;
                end 
            end else begin
                x_count <= x_count + 1;
            end
        end

        // Detect red pixels 
        if (red_pixel) begin 
            x_sum <= x_sum + x_count; 
            y_sum <= y_sum + y_count; 
            red_count <= red_count + 1; 
				if ((x_count > 280) && (x_count < 360)) begin 
					test_count <= test_count + 1; 
				end 
        end 
    end
	 

    localparam int HORIZONTAL_LWR_BOUND = (WIDTH/2)-60;
    localparam int HORIZONTAL_UPR_BOUND = (WIDTH/2)+60;

    logic [43:0] mult_x, mult_y;
    logic centroid_check;

    always_comb begin
        mult_x = (x_sum * red_count_reciprocal);
        mult_y = (y_sum * red_count_reciprocal);

//        centroid_flag = (
//            (x_centroid > 50) && (x_centroid < 590)
//        );
		  
		  centroid_flag = ((red_pixel) && (x_count > 280) && (x_count < 360));
		  
//		  
//			centroid_flag = (red_count >= 260000); 
    end

    always_ff @(posedge clk) begin
        if (endofpacket_in) begin
            x_centroid <= mult_x[43:23];
            y_centroid <= mult_y[43:23];
        end
    end



    // Assign outputs
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            data_out <= 0;
            sop_out <= 0;
            eop_out <= 0;
            valid_out <= 0;
        end
        else begin
            if (enable) begin
                data_out <= data_in;
                startofpacket_out <= startofpacket_in;
                endofpacket_out <= endofpacket_in;
                valid_out <= valid_in;
            end
        end
    end 
	 


endmodule