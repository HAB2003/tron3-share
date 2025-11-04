/*  OV7670 Pixel Capture
 *  Author: T. Holland
 *
 *  Takes data inputs from OV7670 camera and scales image down from 640x480 -> 320x240.
 *
 *
 *  Notes: 
 *  - Requires OV7670 to be configured to RGB444 data (using register 0x8C).
 *  - IMPORTANT!! Will NOT work on DE1 unless timing contraints are configured correctly for PCLK, which is 50MHz.
 */ 

module ov7670_pixel_capture(
  input wire pclk,
  input wire vsync,
  input wire href,
  input wire [7:0] d,
  output wire [16:0] addr,
  output wire [11:0] pixel,
  output wire we
);


reg [3:0] red     = 4'b0;
reg [3:0] blue    = 4'b0;
reg [3:0] green   = 4'b0;
assign pixel = {red,green,blue}; 

reg [16:0] address = 17'b0;
assign addr = address;

reg pixel_phase    =     0;
reg pixel_ready    =  1'b0;


//Used to sample every second pixel on every second line (downscaling to fit into BRAM)
reg x_downscaler   = 1'b0;
reg y_downscaler   = 1'b0;

reg href_last = 1'b0;

// Refer to datasheet here for cycle information
// https://web.mit.edu/6.111/www/f2016/tools/OV7670_2006.pdf
//
// Using RGB444  (Figure13) 
//
// First  Byte (pixel_phase == 0): XXXXRRRR
// Second Byte (pixel_phase == 1): GGGGBBBB
//
always_ff @(posedge pclk ) begin 
    pixel_ready <= 1'b0;
    href_last   <= href;
	 
    if (vsync) begin
        address     <= 17'b0;
        pixel_phase <=  1'b0;
        x_downscaler<=  1'b0;
        y_downscaler<=  1'b0;
    end 
    else if (href) begin
		pixel_phase <= ~pixel_phase;
        if (href_last != href ) begin
            y_downscaler <= ~y_downscaler;
        end
        if (pixel_phase == 1'b0) begin //First Byte
            red <= d[3:0];
        end
        else begin //Second Byte
            blue  <= d[3:0];
            green <= d[7:4];
            pixel_ready <= 1'b1;
            x_downscaler <= ~x_downscaler;
        end
    end
	 if (we) begin 
		address<= address+1;
	 end
end


assign we = x_downscaler & y_downscaler & pixel_ready;
    

endmodule