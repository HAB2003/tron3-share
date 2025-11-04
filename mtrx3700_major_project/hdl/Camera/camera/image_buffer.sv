module image_buffer
(
	input  logic [11:0] data_in,
	input  logic rd_clk,
	input  logic wr_clk,
	input  logic ready, 
	input  logic rst,
	input  logic wren,
	input  logic [16:0]wraddress, 
	output logic image_start,
	output logic image_end,
	output logic [11:0] data_out
);
  localparam int N_COLS_VGA = 640;
  localparam int N_ROWS_VGA = 480;
  logic [16:0] rdaddress = 0;
  logic [9:0]  x_vga;
  logic [8:0]  y_vga;
  logic [8:0]  x_src;
  logic [7:0]  y_src;

  always_ff @(posedge rd_clk) begin
    if (rst) begin
       rdaddress   <= '0;
       x_vga       <= '0;
       y_vga       <= '0;
	end else begin
		if (ready) begin
				if(x_vga < N_COLS_VGA-1) begin
					x_vga <= x_vga+1;
				end
				else begin
					x_vga <=0;
					if (y_vga < N_ROWS_VGA-1) begin
						y_vga <= y_vga+1;
					end
					else begin
						y_vga <= 0;
					end
				end
			
				if (rdaddress == '0) begin
					image_start <= 1'b1;
				end
				if (rdaddress == N_COLS_VGA*N_ROWS_VGA-1) begin
					image_end <= 1'b1;
				end
				//Dodgy Manoeuvre to scale the VGA
				x_src = x_vga[9:1]; //Divide by two
				y_src = y_vga[8:1];
				rdaddress <= ({9'd0, y_src} << 8) + ({9'd0, y_src} << 6) + {8'd0, x_src};
			end
		end
  end


	logic [11:0] q;
	wire [11:0] q_top;
	wire [11:0] q_bottom;
	reg wren_top;
	reg wren_bottom;
	
	assign data_out = q;


	image_RAM Inst_buffer_top(
		.data(data_in[11:0]),
		.rdaddress(rdaddress[15:0]),
		.rdclock(rd_clk),
		.wraddress(wraddress[15:0]),
		.wrclock(wr_clk),
		.wren(wren_top),
		.q(q_top)
	);

	image_RAM Inst_buffer_bottom(
		.data(data_in[11:0]),
		.rdaddress(rdaddress[15:0]),
		.rdclock(rd_clk),
		.wraddress(wraddress[15:0]),
		.wrclock(wr_clk),
		.wren(wren_bottom),
		.q(q_bottom)
	);

	always @(wraddress[16], wren) begin
	case(wraddress[16])
	1'b0 : begin
		wren_top <= wren;
		wren_bottom <= 1'b0;
	end
	1'b1 : begin
		wren_top <= 1'b0;
		wren_bottom <= wren;
	end
	default : begin
		wren_top <= 1'b0;
		wren_bottom <= 1'b0;
	end
	endcase
	end

	always @(rdaddress[16], q_top, q_bottom) begin
	case(rdaddress[16])
	1'b0 : begin
		q <= q_top;
	end
	1'b1 : begin
		q <= q_bottom;
	end
	default : begin
		q <= 12'b000000000000;
	end
	endcase
	end


endmodule