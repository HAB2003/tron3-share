`timescale 1ns/1ps
module task_fsm_tb;

  localparam CLK_PERIOD = 10;        // 100 MHz
  localparam MAX_SIM_NS = 200_000;   // watchdog

  logic clk, rst;

  // DUT inputs
  logic start, target_reached, inspection_complete;
  logic [1:0] health_status_in;
  logic transmission_complete, finished;

  // DUT outputs
  logic [2:0] state_enc;
  logic [1:0] health_status_out;

  // State encodings (for readability)
  localparam IDLE=3'd0, NAVIGATE=3'd1, INSPECT=3'd2,
             TRANSMIT=3'd3, COMPLETE=3'd4;

  // Instantiate DUT
  task_fsm dut (
    .clk(clk), .rst(rst),
    .start(start),
    .target_reached(target_reached),
    .inspection_complete(inspection_complete),
    .health_status_in(health_status_in),
    .transmission_complete(transmission_complete),
    .finished(finished),
    .state_enc(state_enc),
    .health_status_out(health_status_out)
  );

  // Clock
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Watchdog
  initial #(MAX_SIM_NS) $error("Simulation timed out");

  // Wave dump
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, task_fsm_tb);
  end

  // Stimulus
  initial begin
    // Initial conditions
    rst = 1;
    start = 0;
    target_reached = 0;
    inspection_complete = 0;
    transmission_complete = 0;
    finished = 0;
    health_status_in = 2'b00;

    #(5*CLK_PERIOD);
    rst = 0;
    @(posedge clk);

    $display("[%0t] Released reset, expecting IDLE", $time);

    // --- IDLE → NAVIGATE ---
    start = 1;
    @(posedge clk);
    $display("[%0t] Expect NAVIGATE, state=%0d", $time, state_enc);

    // --- NAVIGATE → INSPECT ---
    target_reached = 1;
    @(posedge clk);
    $display("[%0t] Expect INSPECT, state=%0d", $time, state_enc);

    // --- INSPECT phase ---
    health_status_in = 2'b11;
    inspection_complete = 1;
    @(posedge clk);
    $display("[%0t] Expect TRANSMIT, state=%0d", $time, state_enc);

    // --- TRANSMIT phase ---
    transmission_complete = 1;
    @(posedge clk);
    $display("[%0t] Expect COMPLETE, state=%0d", $time, state_enc);

    // --- COMPLETE → IDLE ---
    finished = 1;
    @(posedge clk);
    $display("[%0t] Expect IDLE, state=%0d", $time, state_enc);

    $display("[%0t] TEST COMPLETE", $time);
    $finish;
  end

endmodule
