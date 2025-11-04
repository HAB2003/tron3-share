// prox_flag.sv
// One-file ultrasonic proximity: drives TRIG, measures ECHO, outputs wall_close only.
// - Auto-measures every PING_INTERVAL_MS
// - wall_close = 1 when distance <= THRESH_CM (else 0)

`timescale 1ns/1ps

module prox_flag #(
    parameter int unsigned CLK_HZ            = 50_000_000,
    parameter int unsigned THRESH_CM         = 20,   // threshold in cm
    parameter int unsigned PING_INTERVAL_MS  = 250   // repeat period
)(
    input  logic clk,
    input  logic rst,        // active-high sync reset

    // Sensor pins
    input  logic echo_in,    // from sensor ECHO
    output logic trig,       // to sensor TRIG

    // Output
    output logic wall_close  // 1 when distance <= THRESH_CM
);

    // ---- Timing/derived constants ----
    // 10us trigger pulse
    localparam int unsigned TEN_US_TICKS  = (CLK_HZ / 100_000); // ~10us

    // Wait timeout (max time waiting for echo rising) ~25ms
    localparam int unsigned WAIT_TIMEOUT_US = 25_000;
    localparam int unsigned WAIT_TIMEOUT_T  = (CLK_HZ / 1_000_000) * WAIT_TIMEOUT_US;

    // Auto-ping interval
    localparam int unsigned PING_TICKS = (CLK_HZ / 1000) * PING_INTERVAL_MS;

    // Ticks-per-cm = CLK_HZ / 17_000  (340 m/s -> 34,000 cm/s; divide by 2 for round trip)
    // Compare ticks to a precomputed threshold: THRESH_TICKS = ceil(THRESH_CM * CLK_HZ / 17000)
    localparam int unsigned THRESH_TICKS =
        (THRESH_CM * CLK_HZ + 17_000 - 1) / 17_000;

    // ---- Synchronize ECHO (2FF) ----
    logic echo_meta, echo_sync;
    always_ff @(posedge clk) begin
        echo_meta <= echo_in;
        echo_sync <= echo_meta;
    end

    // ---- FSM ----
    typedef enum logic [2:0] { S_IDLE, S_TRIGGER, S_WAIT, S_COUNTECHO, S_DECIDE } state_e;
    state_e state_q, state_d;

    // Counters
    logic [$clog2(TEN_US_TICKS  )-1:0] trig_cnt_q, trig_cnt_d;
    logic [$clog2(WAIT_TIMEOUT_T)-1:0] wait_cnt_q, wait_cnt_d;
    logic [$clog2(PING_TICKS    )-1:0] ping_cnt_q, ping_cnt_d;

    // Echo high-time ticks
    logic [21:0] echo_ticks_q, echo_ticks_d;

    // Flags
    logic no_echo_q, no_echo_d;

    // TRIG output: high only during S_TRIGGER
    assign trig = (state_q == S_TRIGGER);

    // Auto-measure tick
    wire ping_fire = (ping_cnt_q == PING_TICKS-1);

    // Next-state & counters
    always_comb begin
        state_d      = state_q;
        trig_cnt_d   = trig_cnt_q;
        wait_cnt_d   = wait_cnt_q;
        ping_cnt_d   = ping_cnt_q;
        echo_ticks_d = echo_ticks_q;
        no_echo_d    = no_echo_q;

        // default counter handling
        if (state_q != S_TRIGGER) trig_cnt_d = '0;
        if (state_q != S_WAIT)    wait_cnt_d = '0;

        // auto-ping only advances in IDLE
        if (state_q == S_IDLE)
            ping_cnt_d = ping_fire ? '0 : ping_cnt_q + 1'b1;

        unique case (state_q)
            S_IDLE: begin
                echo_ticks_d = '0;
                if (ping_fire) begin
                    state_d   = S_TRIGGER;
                    no_echo_d = 1'b1;
                end
            end

            S_TRIGGER: begin
                trig_cnt_d = trig_cnt_q + 1'b1;
                if (trig_cnt_q == TEN_US_TICKS-1)
                    state_d = S_WAIT;
            end

            S_WAIT: begin
                wait_cnt_d = wait_cnt_q + 1'b1;
                if (echo_sync) begin
                    state_d   = S_COUNTECHO;
                    no_echo_d = 1'b0;
                end else if (wait_cnt_q == WAIT_TIMEOUT_T-1) begin
                    state_d   = S_DECIDE; // timeout
                    no_echo_d = 1'b1;
                end
            end

            S_COUNTECHO: begin
                // count while echo high
                echo_ticks_d = echo_ticks_q + (echo_sync ? 22'd1 : 22'd0);
                if (!echo_sync)
                    state_d = S_DECIDE;
            end

            S_DECIDE: begin
                // decide wall_close and return to idle (registered below)
                state_d = S_IDLE;
            end
            default: state_d = S_IDLE;
        endcase
    end

    // Registers
    always_ff @(posedge clk) begin
        if (rst) begin
            state_q      <= S_IDLE;
            trig_cnt_q   <= '0;
            wait_cnt_q   <= '0;
            ping_cnt_q   <= '0;
            echo_ticks_q <= '0;
            no_echo_q    <= 1'b1;
            wall_close   <= 1'b0;
        end else begin
            state_q      <= state_d;
            trig_cnt_q   <= trig_cnt_d;
            wait_cnt_q   <= wait_cnt_d;
            ping_cnt_q   <= ping_cnt_d;
            echo_ticks_q <= echo_ticks_d;
            no_echo_q    <= no_echo_d;

            // Latch decision once per measurement
            if (state_q == S_DECIDE) begin
                if (no_echo_q)
                    wall_close <= 1'b0;              // treat no-echo as "far"
                else
                    wall_close <= (echo_ticks_q <= THRESH_TICKS);
            end
        end
    end

endmodule
