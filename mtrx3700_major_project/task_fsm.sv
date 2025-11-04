`timescale 1ns/1ps

module task_fsm (
  input logic clk,
  input logic rst,

  // Kickoff
  input logic start,

  // From navigation
  input logic target_reached,         // close enough to object

  // From inspection & comms
  input logic inspection_complete,    // inspection finished
  input logic [1:0] health_status,      // 2-bit health status

  // From comms
  input logic data_ready,              // uart ready to receive
  input logic transmission_complete,  // data upload finished

  input logic finished,               // mission done 

  // Observability
  output logic [2:0] state_enc,
  output logic [1:0] health_out,    // latched health status
  output logic data_valid,        // 1-cycle pulse when data is ready to send
  output logic done               // 1-cycle pulse on entry to COMPLETE
);

  typedef enum logic [2:0] {
    IDLE = 3'd0,
    NAVIGATE = 3'd1,
    INSPECT = 3'd2,
    TRANSMIT = 3'd3,
    COMPLETE = 3'd4
  } state_t;

  state_t current_state, next_state, prev_state;

  // Next-state logic
  always_comb begin
    next_state = current_state;
    unique case (current_state)
      IDLE:      next_state = start ? NAVIGATE : IDLE;

      NAVIGATE:  next_state = object_reached ? INSPECT : NAVIGATE;

      INSPECT:   next_state = inspection_complete ? TRANSMIT : INSPECT;

      TRANSMIT:  next_state = transmission_complete ? COMPLETE : TRANSMIT;

      COMPLETE:  next_state = finished ? IDLE : COMPLETE; ;
      default:   next_state = IDLE;
    endcase
  end

  // State registers
  always_ff @(posedge clk) begin
    if (rst) begin
      current_state <= IDLE;
      prev_state <= IDLE;
    end else begin
      prev_state <= current_state;
      current_state <= next_state;
    end
  end

  // Outputs
  always_comb begin
    state_enc = current_state;
    done = (current_state == COMPLETE);

    unique case (current_state)
      IDLE: begin
        health_out = 2'b00;
        data_valid = 1'b0;
      end
      
      INSPECT, TRANSMIT: busy = 1'b1;
      COMPLETE: busy = 1'b0;
    endcase
  end

endmodule
