//module navigation_fsm (
//    input logic clk,
//	 input logic rst,
//	 input logic [2:0] state_enc,
//	 input logic target_acquired,
//	 input logic target_arrived_in,
//    output logic [1:0] state,
//	 output logic target_arrived_out
//);
//
//	 localparam logic [2:0] MODE_NAVIGATE = 3'd1;
//	 
//    wire nav_mode = (state_enc == MODE_NAVIGATE);
//    wire start    = nav_mode;
//
//	    // Local NAV states
//    typedef enum logic [2:0] {
//        IDLE  = 3'd0,
//        SCAN  = 3'd1,
//        DRIVE = 3'd2,
//        STOP  = 3'd3
//    } nav_t;
//	 
//	 nav_t current_state, next_state;
//	 
//	 // Next-state logic
//    always_comb begin
//        next_state = current_state;
//            unique case (current_state)
//                IDLE:   next_state = start            ? SCAN  : IDLE;
//                SCAN:   next_state = target_acquired  ? DRIVE : SCAN;
//                DRIVE:  next_state = target_arrived_in   ? STOP  : DRIVE;
//                STOP:   next_state = STOP;  
//                default:next_state = IDLE;
//            endcase
////        end
//    end
//	 
//	 always_ff @(posedge clk) begin
//        if (rst) current_state <= IDLE;
//        else     current_state <= next_state;
//    end
//	 
//	     // Action selection (from current state)
//    always_comb begin
//        unique case (current_state)
//            IDLE, STOP: state = STOP;
//            SCAN:       state = SCAN;
//            DRIVE:      state = DRIVE;
//            default:    state = STOP;
//        endcase
//    end
//endmodule

module navigation_fsm (
    input  logic       clk,
    input  logic       rst,
    input  logic [2:0] state_enc,
    input  logic       target_acquired,
    input  logic       target_arrived_in,
    output logic [1:0] state,
    output logic       target_arrived_out
);

  localparam logic [2:0] MODE_NAVIGATE = 3'd1;
  wire start = (state_enc == MODE_NAVIGATE);		//changed this
//  wire start    = nav_mode;

  typedef enum logic [2:0] { IDLE=3'd0, SCAN=3'd1, DRIVE=3'd2, STOP=3'd3 } nav_t;
  nav_t current_state, next_state;

  // Next-state logic
  always_comb begin
    next_state = current_state;
    unique case (current_state)
      IDLE:   next_state = start             ? SCAN  : IDLE;
      SCAN:   next_state = target_acquired   ? DRIVE : SCAN;
      DRIVE:  next_state = target_arrived_in ? STOP  : DRIVE;
      // Hold in STOP while nav_mode is asserted; go back to IDLE when parent releases it
      STOP:   next_state = start ? STOP : IDLE;
      default:next_state = IDLE;
    endcase
  end

  // State register
  always_ff @(posedge clk or posedge rst) begin
    if (rst) current_state <= IDLE;
    else     current_state <= next_state;
  end

  // One-cycle pulse on STOP entry (to notify parent)
  always_ff @(posedge clk or posedge rst) begin
    if (rst) target_arrived_out <= 1'b0;
    else     target_arrived_out <= (current_state != STOP) && (next_state == STOP);
  end

  // Output mapping
  always_comb begin
    unique case (current_state)
      IDLE, STOP: state = STOP;
      SCAN:       state = SCAN;
      DRIVE:      state = DRIVE;
      default:    state = STOP;
    endcase
  end

endmodule

