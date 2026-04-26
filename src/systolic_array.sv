// ---------------------------------------------------
// systolic_array.sv – N × N array of PEs
// ---------------------------------------------------
`default_nettype none
module systolic_array #(
    parameter int N          = 4,   // Grid size (rows = columns)
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,
    // Input streams after skewing
    input  wire [N*DATA_WIDTH-1:0]  a_row_in,   // Concatenated: a[0]..a[N-1] for a given row
    input  wire [N*DATA_WIDTH-1:0]  b_col_in,   // Concatenated: b[0]..b[N-1] for a given column
    // Output accumulators (matrix C) – flattened row‑major
    output wire [N*N*ACC_WIDTH-1:0] c_out
);
    // -------------------------------------------------
    // Unpack the vectorised inputs into per‑PE wires
    // -------------------------------------------------
    wire [DATA_WIDTH-1:0] a_in_matrix [0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] b_in_matrix [0:N-1][0:N-1];
    wire [ACC_WIDTH-1:0]  acc_matrix   [0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] a_fwd_matrix [0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] b_fwd_matrix [0:N-1][0:N-1];

    // ----------------------------------------------------------------
    // Generate the grid of PEs
    // ----------------------------------------------------------------
    genvar i,j;
    generate
        for (i=0; i<N; i=i+1) begin : row
            for (j=0; j<N; j=j+1) begin : col
                // Inputs to each PE:
                //  – a comes from either the global a_row_in (first column) or left neighbor's a_out
                //  – b comes from either the global b_col_in (first row) or top neighbor's b_out
                localparam int PE_IDX   = i*N + j;

                // Determine source of 'A' for this PE
                wire [DATA_WIDTH-1:0] a_src;
                if (j == 0) begin
                    // First column – connect directly to row skew output (a_row_in)
                    assign a_src = a_row_in[ DATA_WIDTH*(i+1)-1 -: DATA_WIDTH ];
                end else begin
                    // Take from left neighbor's forward output
                    assign a_src = a_fwd_matrix[i][j-1];
                end

                // Determine source of 'B' for this PE
                wire [DATA_WIDTH-1:0] b_src;
                if (i == 0) begin
                    // First row – connect directly to column skew output (b_col_in)
                    assign b_src = b_col_in[ DATA_WIDTH*(j+1)-1 -: DATA_WIDTH ];
                end else begin
                    // Take from top neighbor's forward output
                    assign b_src = b_fwd_matrix[i-1][j];
                end

                // Instantiate the PE
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_pe (
                    .clk      (clk),
                    .rst_n    (rst_n),
                    .en       (1'b1),
                    .a_in     (a_src),
                    .b_in     (b_src),
                    .a_out    (a_fwd_matrix[i][j]),
                    .b_out    (b_fwd_matrix[i][j]),
                    .acc_out  (acc_matrix[i][j])
                );
            end
        end
    endgenerate

    // ----------------------------------------------------------------
    // Pack the accumulator results into a single flattened vector
    // ----------------------------------------------------------------
    generate
        for (i=0; i<N; i=i+1) begin : pack_rows
            for (j=0; j<N; j=j+1) begin : pack_cols
                localparam int IDX = (i*N + j) * ACC_WIDTH;
                assign c_out[IDX +: ACC_WIDTH] = acc_matrix[i][j];
            end
        end
    endgenerate
endmodule
`default_nettype wire
