// ---------------------------------------------------
// skew_buffer.sv – Parameterizable delay line
// ---------------------------------------------------
`default_nettype none
module skew_buffer #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 1      // Number of cycle delays
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [DATA_WIDTH-1:0]    din,
    output wire [DATA_WIDTH-1:0]    dout
);
    // -------------------------------------------------
    // Internal shift register
    // -------------------------------------------------
    if (DEPTH == 0) begin : gen_no_delay
        assign dout = din;
    end else begin : gen_delay
        logic [DATA_WIDTH-1:0] shift_reg [0:DEPTH-1];
        // Output is the last element
        assign dout = shift_reg[DEPTH-1];

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                shift_reg[0] <= '0;
                for (int i = 1; i < DEPTH; i++) shift_reg[i] <= '0;
            end else begin
                shift_reg[0] <= din;
                for (int i = 1; i < DEPTH; i++) shift_reg[i] <= shift_reg[i-1];
            end
        end
    end
endmodule
`default_nettype wire
