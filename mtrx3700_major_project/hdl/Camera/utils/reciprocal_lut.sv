//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name: reciprocal_lut
// Project Name: mtrx3700-assignment-2
// Target Devices: DE2-115
// Description: 
// 
// Dependencies: 
// 
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module reciprocal_lut #(
    parameter int WIDTH_IN  = 17,   // param: input value width
    parameter int WIDTH_OUT = 24,   // param: output value width
    parameter int LUT_SIZE  = 1024  // param: lut depth
)(
    input  logic [WIDTH_IN-1:0]  x,
    output logic [WIDTH_OUT-1:0] y
);

    localparam int X_MAX = 76800;
    logic [$clog2(LUT_SIZE)-1:0] addr;

    // Map x range [0, X_MAX] --> [0, LUT_SIZE-1]
    always_comb begin
        if (x <= 1)
            addr = LUT_SIZE - 1;          // handle divide-by-zero safely
        else if (x >= X_MAX)
            addr = 0;                     // saturate to smallest reciprocal
        else
            addr = (x * (LUT_SIZE - 1)) / X_MAX;
    end

    // 24-bit wide ROM
    logic [WIDTH_OUT-1:0] lut_mem [0:LUT_SIZE-1];

    initial begin
        $readmemh("mem/reciprocal_table.hex", lut_mem);
    end

    assign y = (x <= 1) ? 24'h800000 : lut_mem[addr];

endmodule
