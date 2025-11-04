

module image_to_avalon_wrapper (
    input  logic        clk,
    input  logic        rst,

    // Interface to image_buffer
    input  logic [11:0] data_out,
    input  logic        image_start,
    input  logic        image_end,
    output logic        ready,             // to image_buffer

    // Avalon-ST Output
    output logic [29:0] data_out_avalon,
    output logic        startofpacket_out,
    output logic        endofpacket_out,
    output logic        valid_out,
    input  logic        ready_in           // from downstream
);

    // FSM states
    typedef enum logic [1:0] {IDLE, STREAMING} state_t;
    state_t state, next_state;

    // Registered outputs
    logic [29:0] data_reg;
    logic sop_reg, eop_reg, valid_reg;

    // RGB expansion (12-bit -> 30-bit)
    logic [7:0] r, g, b;
    always_comb begin
        r = {data_out[11:8], 4'b0000};
        g = {data_out[7:4],  4'b0000};
        b = {data_out[3:0],  4'b0000};
    end
	 
    logic [29:0] expanded_data;
    assign expanded_data = {r, 2'b00, g, 2'b00, b, 2'b00};

    // Sequential FSM and output register
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            data_reg <= 0;
            sop_reg <= 0;
            eop_reg <= 0;
            valid_reg <= 0;
        end else begin
            state <= next_state;

            // Only latch data if downstream is ready
            if (state == STREAMING && ready_in) begin
                data_reg <= expanded_data;
                sop_reg <= image_start;
                eop_reg <= image_end;
                valid_reg <= 1;
            end else if (state == IDLE) begin
                valid_reg <= 0;
                sop_reg <= 0;
                eop_reg <= 0;
            end
        end
    end

    // Combinational next-state logic and ready signal
    always_comb begin
        next_state = state;
        ready = 0; // default

        case (state)
            IDLE: begin
                if (image_start) begin
                    next_state = STREAMING;
                    ready = 1; // can accept first pixel
                end
            end

            STREAMING: begin
                ready = ready_in; // only accept pixel if downstream ready
                if (image_end && ready_in) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Output assignments
    assign data_out_avalon      = data_reg;
    assign startofpacket_out    = sop_reg;
    assign endofpacket_out      = eop_reg;
    assign valid_out            = valid_reg;

endmodule
