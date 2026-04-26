// ---------------------------------------------------
// skew_buffer.sv – Parameterizable delay line (any width)
// ---------------------------------------------------
`default_nettype none
module skew_buffer #(
    parameter int WIDTH = 8,   // <-- generic width (can be N*DATA_WIDTH)
    parameter int DEPTH = 1
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [WIDTH-1:0]     din,
    output wire [WIDTH-1:0]     dout
);
    // -------------------------------------------------
    // 0‑delay shortcut
    // -------------------------------------------------
    if (DEPTH == 0) begin : gen_no_delay
        assign dout = din;
    end else begin : gen_delay
        logic [WIDTH-1:0] shift_reg [0:DEPTH-1];
        assign dout = shift_reg[DEPTH-1];

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (int i = 0; i < DEPTH; i++) shift_reg[i] <= '0;
            end else begin
                shift_reg[0] <= din;
                for (int i = 1; i < DEPTH; i++) shift_reg[i] <= shift_reg[i-1];
            end
        end
    end
endmodule
`default_nettype wire
