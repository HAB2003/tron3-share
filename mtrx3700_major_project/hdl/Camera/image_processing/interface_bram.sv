//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name: interface_bram
// Project Name: mtrx3700-major-project
// Target Devices: DE2-115
// Description: 
// 
// Dependencies: 
// 
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module interface_bram #(
    parameter int WIDTH = 320,
    parameter int HEIGHT = 240
)(
    input  logic        clk,             
    input  logic        rst_n,

    // Avalon-ST Source Interface
    output logic [29:0] data,            // Data output to VGA (8 data bits + 2 padding bits for each colour Red, Green and Blue = 30 bits)
    output logic        startofpacket,   // Start of packet signal
    output logic        endofpacket,     // End of packet signal
    output logic        valid,           // Data valid signal
    input  logic        ready            // Data ready signal from VGA Module
);

    localparam NumPixels     = WIDTH * HEIGHT; // Total number of pixels
    localparam NumColourBits = 12;        //

    // Image ROMs:
    (* ram_init_file = "images/aruco-tag.mif" *) logic [NumColourBits-1:0] image_data [NumPixels]; // The ram_init_file is a Quartus-only directive

    `ifdef VERILATOR
    initial begin : memset /* The 'ifdef VERILATOR' means this initial block is ignored in Quartus */
        $readmemh("images/red_centroid_center.hex", image_data);
    end
    `endif
     
    logic [18:0] pixel_index = 0, pixel_index_next; // The pixel counter/index. Set pixel_index_next in an always_comb block.
                                                    // Set pixel_index <= pixel_index_next in an always_ff block.

    logic [NumColourBits-1:0] image_data_q; // Registers for reading from each ROM.
      
    logic read_enable; // Need to have a read enable signal for the BRAM
    assign read_enable = (!rst_n) | (valid & ready); // If reset, read the first pixel value. If valid&ready (handshake), read the next pixel value for the next handshake.

    always_ff @(posedge clk) begin : bram_read // This block is for correctly inferring BRAM in Quartus
        if (read_enable) begin
            image_data_q   <= image_data[pixel_index_next];
        end
    end

    logic [NumColourBits-1:0] current_pixel;
    assign current_pixel = image_data_q;

    assign valid = (rst_n != 0);

    assign startofpacket = pixel_index == 0;           // Start of frame
    assign endofpacket   = pixel_index == NumPixels-1; // End of frame

    logic [3:0] r, g, b;
	 
	 assign r = current_pixel[11:8];
	 assign g = current_pixel[ 7:4];
	 assign b = current_pixel[ 3:0];
	 
    assign data = {
        {r, r, 2'b00},
        {g, g, 2'b00},
        {b, b, 2'b00}
     };

    assign pixel_index_next = (!rst_n) ? 0 : ( endofpacket ? 0 : pixel_index + 1 );

    always_ff @(posedge clk) begin
		  if (!rst_n) begin
		      pixel_index <= 19'd0;
		  end else if (valid && ready) begin
            pixel_index <= pixel_index_next;
        end 
    end

endmodule
