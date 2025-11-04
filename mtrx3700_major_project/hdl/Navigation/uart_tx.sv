 module uart_tx #(
      parameter CLKS_PER_BIT = (50_000_000/115_200), // E.g. Baud_rate = 115200 with FPGA clk = 50MHz
      parameter BITS_N       = 8, // Number of data bits per UART frame
      parameter PARITY_TYPE  = 0  // 0 for none, 1 for odd parity, 2 for even.
) (
      input clk,
      input rst,
      input [BITS_N-1:0] data_tx,
      output logic uart_out,
      input valid,            // Handshake protocol: valid (when `data_tx` is valid to be sent onto the UART).
      output logic ready      // Handshake protocol: ready (when this UART module is ready to send data).
 );

   logic [BITS_N-1:0] data_tx_temp;
   logic                parity_bit;
   logic [$clog2(BITS_N):0]  bit_n;

   // Baud counter (assume CLKS_PER_BIT >= 2 for real UARTs)
    logic [$clog2(CLKS_PER_BIT)-1:0] baud_cnt;
    logic                            baud_last;  // high when finishing this bit time

   typedef enum logic [2:0] {IDLE, START_BIT, DATA_BITS, PARITY_BIT, STOP_BIT} state_t;

   state_t current_state, next_state;

   assign baud_last = (baud_cnt == CLKS_PER_BIT-1);

   always_comb begin
      next_state = current_state;
      case (current_state)
         IDLE:       next_state = valid ? START_BIT : IDLE;
         START_BIT:  next_state = baud_last ? DATA_BITS : START_BIT;
         DATA_BITS:  if (baud_last && bit_n == BITS_N-1)
                        next_state = (PARITY_TYPE==0) ? STOP_BIT : PARITY_BIT;
                     else if (baud_last)
                        next_state = DATA_BITS;
         PARITY_BIT: next_state = baud_last ? STOP_BIT : PARITY_BIT;
         STOP_BIT:   next_state = baud_last ? IDLE : STOP_BIT;
      endcase
   end
   
   always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
         current_state <= IDLE;
         baud_cnt      <= 0;
         bit_n         <= 0;
         data_tx_temp  <= 0;
         parity_bit    <= 0;
      end else begin
         current_state <= next_state;

         if (current_state != IDLE) begin
            baud_cnt <= baud_last ? 0 : baud_cnt + 1'b1;
         end else begin
            baud_cnt <= 0;
         end

         case (current_state)
            IDLE: if (valid) begin
               data_tx_temp <= data_tx;
               bit_n <= 0;
               // Precompute parity
               case (PARITY_TYPE)
                  1: parity_bit <= ~(^data_tx); // odd
                  2: parity_bit <=  (^data_tx); // even
                  default: parity_bit <= 1'b0;
               endcase
            end

            DATA_BITS: if (baud_last) begin
               bit_n <= bit_n + 1'b1;
            end
         endcase
      end
   end

   always_comb begin
      uart_out = 1'b1; // default line high
      ready    = 1'b0;

      case (current_state)
         IDLE: begin
            ready    = 1'b1;
            uart_out = 1'b1;
         end
         START_BIT: uart_out = 1'b0;
         DATA_BITS: uart_out = data_tx_temp[bit_n];
         PARITY_BIT: uart_out = parity_bit;
         STOP_BIT: uart_out = 1'b1;
      endcase
   end

 endmodule