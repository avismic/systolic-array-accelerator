// ---------------------------------------------------
// systolic_array.sv – N × N array of PEs
// ---------------------------------------------------
`default_nettype none
module systolic_array #(
    parameter int N          = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,
    // ONE flattened vector per whole row   (N rows × N elements)
    input  wire [N*N*DATA_WIDTH-1:0] a_row_flat,
    // ONE flattened vector per whole column (N cols × N elements)
    input  wire [N*N*DATA_WIDTH-1:0] b_col_flat,
    // Flattened row‑major result matrix C
    output wire [N*N*ACC_WIDTH-1:0] c_out
);
    // -----------------------------------------------------------------
    // Unpack the flattened inputs into per‑PE wires
    // -----------------------------------------------------------------
    // a_src[i][j] = a_row_flat[(i*N + j)*DATA_WIDTH +: DATA_WIDTH]
    // b_src[i][j] = b_col_flat[(j*N + i)*DATA_WIDTH +: DATA_WIDTH]
    // (notice the transpose for the column input)
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] a_src [0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] b_src [0:N-1][0:N-1];

    genvar i,j;
    generate
        for (i=0; i<N; i=i+1) begin : unpack_row
            for (j=0; j<N; j=j+1) begin : unpack_col
                localparam int A_IDX = (i*N + j) * DATA_WIDTH;
                localparam int B_IDX = (j*N + i) * DATA_WIDTH;
                assign a_src[i][j] = a_row_flat[A_IDX +: DATA_WIDTH];
                assign b_src[i][j] = b_col_flat[B_IDX +: DATA_WIDTH];
            end
        end
    endgenerate

    // -----------------------------------------------------------------
    // Forwarding wires (values that move to the next PE each cycle)
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] a_fwd [0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] b_fwd [0:N-1][0:N-1];
    wire [ACC_WIDTH-1:0]  acc   [0:N-1][0:N-1];

    // -----------------------------------------------------------------
    // Generate the grid of PEs
    // -----------------------------------------------------------------
    generate
        for (i=0; i<N; i=i+1) begin : row
            for (j=0; j<N; j=j+1) begin : col
                // For the left‑most column the A input comes directly from a_src,
                // otherwise it comes from the neighbour on the left.
                wire [DATA_WIDTH-1:0] a_input;
                if (j == 0) assign a_input = a_src[i][j];
                else        assign a_input = a_fwd[i][j-1];

                // For the top‑most row the B input comes directly from b_src,
                // otherwise it comes from the neighbour above.
                wire [DATA_WIDTH-1:0] b_input;
                if (i == 0) assign b_input = b_src[i][j];
                else        assign b_input = b_fwd[i-1][j];

                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_pe (
                    .clk     (clk),
                    .rst_n   (rst_n),
                    .en      (1'b1),
                    .a_in    (a_input),
                    .b_in    (b_input),
                    .a_out   (a_fwd[i][j]),
                    .b_out   (b_fwd[i][j]),
                    .acc_out (acc[i][j])
                );
            end
        end
    endgenerate

    // -----------------------------------------------------------------
    // Pack the accumulator matrix into the single flattened output
    // -----------------------------------------------------------------
    generate
        for (i=0; i<N; i=i+1) begin : pack_rows
            for (j=0; j<N; j=j+1) begin : pack_cols
                localparam int IDX = (i*N + j) * ACC_WIDTH;
                assign c_out[IDX +: ACC_WIDTH] = acc[i][j];
            end
        end
    endgenerate
endmodule
`default_nettype wire
