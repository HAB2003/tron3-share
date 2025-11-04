module motor_controller (
    input  logic        CLOCK_50,
    input  logic  [1:0] state,     // 0=Analyse, 1=Scan, 2=Drive
    inout  logic [35:0] GPIO
    //output logic [17:0] LEDR
);

    // === Parameters ===
    localparam MAX_JSON_LEN = 27;           // pad shorter strings
    localparam PERIOD = 25_000_000;         // 0.5 s @ 50 MHz

    // === UART handshake ===
    logic tx_valid = 0;
    logic tx_ready;
    logic [7:0] byte_to_send;
    integer char_index = 0;
    integer counter = 0;

    // === JSON COMMANDS ===
    // {"T":0,"L":0,"R":0}\n
    logic [7:0] json_stop [27] = '{
         8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h30,8'h2C,
         8'h22,8'h4C,8'h22,8'h3A,8'h30,8'h2C,
         8'h22,8'h52,8'h22,8'h3A,8'h30,8'h7D,8'h0A,
         8'h00,8'h00,8'h00,8'h00,8'h00, 8'h00, 8'h00
    };

    // {"T":1,"L":0.05,"R":0.05}\n → Drive forward slowly
    logic [7:0] json_drive [27] = '{
         8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,
         8'h22,8'h4C,8'h22,8'h3A,8'h30,8'h2E,8'h30,8'h35,8'h2C,
         8'h22,8'h52,8'h22,8'h3A,8'h30,8'h2E,8'h30,8'h35,8'h7D,8'h0A,
         8'h00
    };

    // {"T":1,"L":0.05,"R":-0.05}\n → Scan (turn right slowly)
    logic [7:0] json_scan [27] = '{
         8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,
         8'h22,8'h4C,8'h22,8'h3A,8'h30,8'h2E,8'h30,8'h35,8'h2C,
         8'h22,8'h52,8'h22,8'h3A,8'h2D,8'h30,8'h2E,8'h30,8'h35,8'h7D,8'h0A
    };

    // === JSON Selector ===
    logic [7:0] current_json [MAX_JSON_LEN];
    always_comb begin
        case (state)
            2'd0: current_json = json_stop;   // Analyse (stop)
            2'd1: current_json = json_scan;   // Scan (slow right)
            2'd2: current_json = json_drive;  // Drive (slow forward)
            default: current_json = json_stop;
        endcase
    end

    // === UART Transmitter ===
    uart_tx #(
        .CLKS_PER_BIT(50_000_000/115200),
        .BITS_N(8),
        .PARITY_TYPE(0)
    ) uart_tx_u (
        .clk(CLOCK_50),
        .rst(1'b0),
        .data_tx(byte_to_send),
        .valid(tx_valid),
        .uart_out(GPIO[31]),
        .ready(tx_ready)
    );

    // === Main Loop ===
    always_ff @(posedge CLOCK_50) begin
        // Periodic trigger every 0.5 s
        if (counter >= PERIOD) begin
            counter <= 0;
            tx_valid <= 1'b1;
            byte_to_send <= current_json[0];
            char_index <= 1;
        end else if (!tx_valid) begin
            counter <= counter + 1;
        end

        // Send bytes when UART ready
        if (tx_valid && tx_ready) begin
            if (char_index < MAX_JSON_LEN && current_json[char_index] != 8'h00) begin
                byte_to_send <= current_json[char_index];
                char_index <= char_index + 1;
            end else begin
                tx_valid <= 1'b0; // finished sending
            end
        end
    end

    // Debug LEDs
    //assign LEDR[2:0] = state;
    //assign LEDR[8] = tx_valid;

endmodule
