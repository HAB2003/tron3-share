`timescale 1ns/1ps

module task_fsm (
  input logic clk,
  input logic rst,

  // From GUI
  input logic start,

  // From navigation
  input logic target_reached,         // close enough to object

  // From inspection & comms
  input logic inspection_complete,    // inspection finished
  input logic [1:0] health_status_in,      // 2-bit health status

  // From comms
  input logic transmission_complete,  // data upload finished

  input logic finished,               // mission done 

  // Observability
  output logic [2:0] state_enc,
  output logic [1:0] health_status_out    // latched health status
);

  typedef enum logic [2:0] {
    IDLE = 3'd0,
    NAVIGATE = 3'd1,
    INSPECT = 3'd2,
    TRANSMIT = 3'd3,
    COMPLETE = 3'd4
  } state_t;

  state_t current_state, next_state;

  // Next-state logic
  always_comb begin
    next_state = current_state;
    unique case (current_state)
      IDLE:      next_state = start ? NAVIGATE : IDLE;

      NAVIGATE:  next_state = target_reached ? INSPECT : NAVIGATE;

      INSPECT:   next_state = inspection_complete ? TRANSMIT : INSPECT;

      TRANSMIT:  next_state = transmission_complete ? COMPLETE : TRANSMIT;

      COMPLETE:  next_state = finished ? IDLE : COMPLETE;
      default:   next_state = IDLE;
    endcase
  end

  // State registers
  always_ff @(posedge clk) begin
    if (rst) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Outputs
    // Keep the state encoding purely combinational (no latches)
    always_comb begin
    state_enc = current_state;
    end

    // Latch the health exactly when we leave INSPECT for TRANSMIT; clear in reset/IDLE
    always_ff @(posedge clk) begin
    if (rst) begin
        health_status_out <= 2'b00;
    end else if (current_state == IDLE) begin
        health_status_out <= 2'b00;
    end else if (current_state == INSPECT && next_state == TRANSMIT) begin
        health_status_out <= health_status_in;
    end
    // else: hold value
    end
endmodule
