module navigation_top_level (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,          // KEY0 -> NAVIGATE, KEY1 -> target_acquired, KEY2 -> LED only, KEY3 -> reset (active-low)
    inout        [35:0] GPIO,
    output logic [17:0] LEDR
);

    // ------------------------
    // Declarations
    // ------------------------
    logic [1:0] motion_state;

    // Reset from KEY3 (active-low)
    logic reset;
    assign reset = ~KEY[3];

    // Raw keys (DE boards: pressed = 0)
    wire  key_nav_n    = KEY[0];
    wire  key_acq_n    = KEY[1];
    wire  key_reach_n  = KEY[2];

    // Synchronized, active-high signals
    logic nav_meta,     nav_sync;          // replaces "start"
    logic acq_meta,     target_acquired_sync;
    logic reach_meta,   target_reached_sync;

    always_ff @(posedge CLOCK_50) begin
        nav_meta               <= ~key_nav_n;
        nav_sync               <= nav_meta;

        acq_meta               <= ~key_acq_n;
        target_acquired_sync   <= acq_meta;

        reach_meta             <= ~key_reach_n;
        target_reached_sync    <= reach_meta;    // NOTE: drives LED2 only
    end

    // Build state_enc: == 3'd1 when KEY0 pressed (nav_sync==1), else 3'd0
    logic [2:0] state_enc;
    assign state_enc = nav_sync ? 3'd1 : 3'd0;

    // ------------------------
    // Prox sensor: feeds target_arrived into nav FSM
    // ------------------------
    logic target_arrived;
    logic trig;                 // <— declare TRIG
    assign GPIO[27] = trig;

    prox_sensor #(
        .CLK_HZ           (50_000_000),
        .THRESH_CM        (20),
        .PING_INTERVAL_MS (250)
    ) u_prox (
        .clk            (CLOCK_50),
        .rst            (reset),        // now reset by KEY3
        .echo_in        (GPIO[29]),
        .trig           (trig),
        .target_reached (target_arrived)
    );

    // ------------------------
    // Navigation FSM
    // ------------------------
    logic target_arrived_out;

    navigation_fsm u_test_state (
        .clk                 (CLOCK_50),
        .rst                 (reset),            // now reset by KEY3
        .state_enc           (state_enc),
        .target_acquired     (target_acquired_sync),
        .target_arrived_in   (target_arrived),   // from prox_sensor
        .target_arrived_out  (target_arrived_out),
        .state               (motion_state)
    );

    // ------------------------
    // Motor controller (unchanged)
    // ------------------------
    motor_controller u_motor (
        .CLOCK_50 (CLOCK_50),
        .state    (motion_state),
        .GPIO     (GPIO)
        // .LEDR   ( ... )   // intentionally not connected
    );

    // ------------------------
    // LED17 latch: set on target_arrived_out pulse, clear on reset or leaving NAV
    // ------------------------
    logic led17_latch;
    always_ff @(posedge CLOCK_50 or posedge reset) begin
        if (reset)           led17_latch <= 1'b0;
        else if (!nav_sync)  led17_latch <= 1'b0;              // clear when NAV mode released
        else if (target_arrived_out)
                             led17_latch <= 1'b1;              // latch on arrival pulse
    end

    // ------------------------
    // LEDs (single driver from top)
    // ------------------------
    always_comb begin
        LEDR[0]      = nav_sync;
        LEDR[1]      = target_acquired_sync;
        LEDR[2]      = target_reached_sync;   // KEY2 indicator only
        LEDR[16:3]   = '0;
        LEDR[17]     = led17_latch;           // latched display of arrival
    end

endmodule
