module ov7670_controller(
    input wire clk,
    input wire resend,
    output wire config_finished,
    output wire sioc,
    inout wire siod,
    output wire reset,
    output wire pwdn,
    output wire xclk
);

reg sys_clk = 1'b0;
wire [15:0] command;
wire finished;
wire taken;
wire send_active;

parameter camera_address = 8'h42;

// 100 ms delay counter (50 MHz → 5,000,000 cycles)
localparam integer DELAY_CYCLES = 5_000_000;
reg [22:0] delay_counter = 0;
reg delay_done = 0;


always @(posedge clk) begin
    if (!delay_done) begin
        if (delay_counter < DELAY_CYCLES - 1)
            delay_counter <= delay_counter + 1;
        else
            delay_done <= 1;
    end
end

assign config_finished = finished;

assign send_active = delay_done && ~finished;

i2c_sender Inst_i2c_sender(
    .clk(clk),
    .taken(taken),
    .siod(siod),
    .sioc(sioc),
    .send(send_active),
    .id(camera_address),
    .reg_(command[15:8]),
    .value(command[7:0])
);

assign reset = 1'b1;  // Normal mode
assign pwdn  = 1'b0;  // Power up
assign xclk  = sys_clk;

ov7670_registers Inst_ov7670_registers(
    .clk(clk),
    .advance(taken),
    .command(command),
    .finished(finished),
    .resend(resend)
);

always @(posedge clk) begin
    sys_clk <= ~sys_clk;
end

endmodule
