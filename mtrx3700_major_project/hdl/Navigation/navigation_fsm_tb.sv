`timescale 1ns/1ps
module navigation_fsm_tb;

  // -------------------------
  // Clocking & timing
  // -------------------------
  localparam int CLK_PERIOD = 10;        // 100 MHz
  localparam int MAX_SIM_NS = 200_000;   // watchdog

  logic clk, rst;

  // -------------------------
  // DUT I/O
  // -------------------------
  // task_fsm state encoding: IDLE=0, NAVIGATE=1, INSPECT=2, TRANSMIT=3, COMPLETE=4
  localparam logic [2:0] IDLE=3'd0, NAVIGATE=3'd1, INSPECT=3'd2;

  logic [2:0] state_enc;

  logic target_centered;
  logic target_arrived;

  logic [2:0] nav_state;        // observe local nav state
  logic       target_reached;   // level in STOP
  logic       task_complete;    // level in STOP
  logic [1:0] action_req;
  logic       action_valid;

  // -------------------------
  // DUT
  // -------------------------
  navigation_fsm dut (
    .clk(clk),
    .rst(rst),
    .state_enc(state_enc),
    .target_centered(target_centered),
    .target_arrived(target_arrived),
    .nav_state(nav_state),
    .target_reached(target_reached),
    .task_complete(task_complete),
    .action_req(action_req),
    .action_valid(action_valid)
  );

  // -------------------------
  // Clock + watchdog + waves
  // -------------------------
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  initial #(MAX_SIM_NS) $error("Simulation timed out");

  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, navigation_fsm_tb);
  end

  // -------------------------
  // Helpers
  // -------------------------
  task automatic expect_state(input [2:0] exp, input string tag);
    begin
      @(posedge clk); #1;
      if (nav_state !== exp) begin
        $error("[%0t] %s: expected nav_state=%0d, got %0d", $time, tag, exp, nav_state);
        $fatal(1);
      end else
        $display("[%0t] %s: nav_state=%0d OK", $time, tag, nav_state);
    end
  endtask

  // -------------------------
  // Stimulus
  // -------------------------
  initial begin
    // init
    rst = 1;
    state_enc = IDLE;
    target_centered = 0;
    target_arrived  = 0;

    repeat (5) @(posedge clk);
    rst = 0;
    @(posedge clk); #1;

    // In IDLE (task_fsm not in NAVIGATE) -> nav should be IDLE
    expect_state(3'd0, "After reset (expect IDLE)");

    // Drive task_fsm to NAVIGATE -> nav_fsm should start: IDLE -> SCAN
    state_enc = NAVIGATE;
    expect_state(3'd1, "Entered NAVIGATE -> expect SCAN");

    // Provide centering -> SCAN -> DRIVE
    target_centered = 1;
    expect_state(3'd2, "target_centered=1 -> expect DRIVE");

    // Provide arrival -> DRIVE -> STOP ; target_reached/task_complete should assert (level)
    target_arrived = 1;
    expect_state(3'd3, "target_arrived=1 -> expect STOP");
    if (!(target_reached && task_complete))
      $fatal(1, "[%0t] In STOP expected target_reached=1 & task_complete=1, got %0b %0b",
                 $time, target_reached, task_complete);
    else
      $display("[%0t] STOP flags asserted: target_reached=%0b task_complete=%0b",
               $time, target_reached, task_complete);

    // While still in NAVIGATE, STOP should hold and flags stay high
    @(posedge clk); #1;
    if (!(target_reached && task_complete))
      $fatal(1, "[%0t] STOP flags should still be high", $time);

    // Now simulate task_fsm consuming and leaving NAVIGATE -> INSPECT
    state_enc = INSPECT;
    @(posedge clk); #1;
    // nav_fsm forces IDLE and clears flags on leaving NAVIGATE
    if (nav_state !== 3'd0)
      $fatal(1, "[%0t] After leaving NAVIGATE expect nav_state=IDLE(0), got %0d", $time, nav_state);
    if (target_reached || task_complete)
      $fatal(1, "[%0t] After leaving NAVIGATE flags should clear (0), got tr=%0b tc=%0b",
                 $time, target_reached, task_complete);

    $display("[%0t] TEST PASS", $time);
    $finish;
  end

  // Optional: print action changes for visibility
  always @(posedge clk) if (action_valid)
    $display("[%0t] action_req -> %0d (valid)", $time, action_req);

endmodule
