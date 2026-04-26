// ---------------------------------------------------
// pe.sv – Single Processing Element
// ---------------------------------------------------
`default_nettype none
module pe #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,   // Active‑low async reset
    // Input streams
    input  wire [DATA_WIDTH-1:0]    a_in,
    input  wire [DATA_WIDTH-1:0]    b_in,
    // Output streams (forwarded)
    output wire [DATA_WIDTH-1:0]    a_out,
    output wire [DATA_WIDTH-1:0]    b_out,
    // Accumulator (output to the array)
    output reg  [ACC_WIDTH-1:0]     acc_out,
    // Optional: expose the “valid” flag if you want ready/valid handshake
    input  wire                     en      // Enable (easy to tie to 1'b1)
);
    // -------------------------------------------------
    // Local registers
    // -------------------------------------------------
    logic [DATA_WIDTH-1:0] a_reg, b_reg;

    // Forward the raw inputs (no extra latency)
    assign a_out = a_reg;
    assign b_out = b_reg;

    // -------------------------------------------------
    // Pipeline registers
    // -------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg    <= '0;
            b_reg    <= '0;
            acc_out  <= '0;
        end else if (en) begin
            a_reg    <= a_in;
            b_reg    <= b_in;
            // Multiply‑add: acc = acc + a*b (unsigned for simplicity)
            acc_out  <= acc_out + a_in * b_in;
        end
    end
endmodule
`default_nettype wire
