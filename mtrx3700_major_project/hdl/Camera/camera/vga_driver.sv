`timescale 1ns/1ns
module vga_driver (
    input clk, // vga clock: assume 25.175 MHz
    input rst,
	input [11:0] pixel,
   output logic hsync,
   output logic vsync,
   output logic [7:0] r,
   output logic [7:0] g,
   output logic [7:0] b,
	output logic VGA_BLANK_N,
	output logic VGA_SYNC_N,
	output logic ready
);

    /* Horizontal Line (clock cycles) */
    localparam HVisibleArea  = 640;
    localparam HFrontPorch   = 16;
    localparam HSyncPulse    = 96;
    localparam HBackPorch    = 48;
    localparam HWholeLine    = HVisibleArea + HFrontPorch + HSyncPulse + HBackPorch;
    /* Vertical (lines) */
    localparam VVisibleArea  = 480;
    localparam VFrontPorch   = 10;
    localparam VSyncPulse    = 2;
    localparam VBackPorch    = 33;
    localparam VTotalLines    = VVisibleArea + VFrontPorch + VSyncPulse + VBackPorch;
    localparam TotalPixels   = HWholeLine*VTotalLines;

    logic [$clog2(TotalPixels-1)+1:0]   pixel_count;
    logic [$clog2(VTotalLines-1)+1 :0]  line_count;

    typedef enum {HSYNC, HBACKPORCH, DISPLAY, HFRONTPORCH} states_t;

    states_t state, next_state;

    always_ff @(posedge clk) begin : sequential_logic
        if (rst) begin
            state <= HSYNC;
            pixel_count <= '0;
            line_count  <= '0;
        end
        else begin
            state       <= next_state;
            pixel_count <= (pixel_count != HWholeLine-1) ? (pixel_count + 1) : (0);
            line_count  <= (line_count != VTotalLines-1) ? ((pixel_count == HWholeLine-1) ? (line_count + 1) : (line_count)) : 0;
				
				
        end
    end : sequential_logic

    always_comb begin : next_state_logic
        case (state)
            HSYNC:       next_state = (pixel_count == HSyncPulse-1) ? (HBACKPORCH) : HSYNC;
            HBACKPORCH:  next_state = (pixel_count == (HBackPorch + HSyncPulse-1)) ? (DISPLAY) : (HBACKPORCH);
            DISPLAY:     next_state = (pixel_count == (HBackPorch + HSyncPulse + HVisibleArea-1)) ? (HFRONTPORCH) : (DISPLAY);
            HFRONTPORCH: next_state = (pixel_count == HWholeLine-1) ? (HSYNC) : (HFRONTPORCH);
            default: next_state = state;
        endcase
    end : next_state_logic

    always_comb begin : output_logic
        hsync = 1;
        r = '0;
        g = '0;
        b = '0;
        case (state)
            HSYNC:       begin
                hsync = 0;
            end
            DISPLAY:     begin
                r = {2{pixel[11:8]}}; 
                g = {2{pixel[7:4]}};
                b = {2{pixel[3:0]}};
            end
        endcase
    end : output_logic
	 
	 // Vertical outputs:

	 assign vsync = ((line_count >= (VVisibleArea + VFrontPorch))   && (line_count < (VVisibleArea + VFrontPorch + VSyncPulse))) ? 0 : 1;
	 
	 //Subtract 2 because the image buffer has a delay of 1 cycle
	 wire HDISPLAY = (pixel_count >= (HBackPorch + HSyncPulse-2))   && (pixel_count <= (HBackPorch + HSyncPulse + HVisibleArea-3)); 
	 wire VDISPLAY = line_count >= (VSyncPulse+VBackPorch)          && line_count < (VSyncPulse+VBackPorch+VVisibleArea);
	 assign ready       = HDISPLAY && VDISPLAY;
	 assign VGA_BLANK_N = ready;
	 assign VGA_SYNC_N  = 1'b0;
	
endmodule