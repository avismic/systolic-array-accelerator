// ---------------------------------------------------
// top.sv – System integration: skew buffers + systolic array
// ---------------------------------------------------
`default_nettype none
module top #(
    parameter int N          = 4,
    parameter int DATA_WIDTH = 8,
    // Safe accumulator width: 2*DATA + log2(N) + 2
    parameter int ACC_WIDTH  = 2*DATA_WIDTH + $clog2(N) + 2
) (
    // Global clock & reset
    input  wire                     clk,
    input  wire                     rst_n,

    // Simple streaming input interface
    input  wire                     a_valid,
    input  wire [DATA_WIDTH-1:0]    a_data,
    input  wire                     b_valid,
    input  wire [DATA_WIDTH-1:0]    b_data,

    // Output interface
    output wire                     c_valid,
    output wire [ACC_WIDTH-1:0]    c_data
);
    // -------------------------------------------------
    // Capture matrices A (row‑major) and B (column‑major)
    // -------------------------------------------------
    logic [DATA_WIDTH-1:0] a_mat [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] b_mat [0:N-1][0:N-1];

    // Row/column pointers for the streaming interface
    integer a_row_ptr, a_col_ptr;
    integer b_row_ptr, b_col_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_row_ptr <= 0; a_col_ptr <= 0;
            b_row_ptr <= 0; b_col_ptr <= 0;
        end else begin
            // ----- A (row‑major) -----
            if (a_valid) begin
                a_mat[a_row_ptr][a_col_ptr] <= a_data;
                a_col_ptr <= a_col_ptr + 1;
                if (a_col_ptr == N-1) begin
                    a_col_ptr <= 0;
                    a_row_ptr <= a_row_ptr + 1;
                    if (a_row_ptr == N-1) a_row_ptr <= 0;
                end
            end
            // ----- B (column‑major) -----
            if (b_valid) begin
                b_mat[b_row_ptr][b_col_ptr] <= b_data;
                b_row_ptr <= b_row_ptr + 1;
                if (b_row_ptr == N-1) begin
                    b_row_ptr <= 0;
                    b_col_ptr <= b_col_ptr + 1;
                    if (b_col_ptr == N-1) b_col_ptr <= 0;
                end
            end
        end
    end

    // -------------------------------------------------
    // Pack rows of A and columns of B into N‑wide vectors
    // -------------------------------------------------
    wire [N*DATA_WIDTH-1:0] a_row_vectors [0:N-1];
    wire [N*DATA_WIDTH-1:0] b_col_vectors [0:N-1];

    genvar r, c;
    generate
        // ---- rows of A ----
        for (r = 0; r < N; r = r + 1) begin : pack_A_rows
            for (c = 0; c < N; c = c + 1) begin : pack_bits
                assign a_row_vectors[r][(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] = a_mat[r][c];
            end
        end
        // ---- columns of B ----
        for (c = 0; c < N; c = c + 1) begin : pack_B_cols
            for (r = 0; r < N; r = r + 1) begin : pack_bits
                assign b_col_vectors[c][(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] = b_mat[r][c];
            end
        end
    endgenerate

    // -------------------------------------------------
    // Skew buffers: row i delayed by i cycles, column j delayed by j cycles
    // -------------------------------------------------
    wire [N*DATA_WIDTH-1:0] a_skewed_rows [0:N-1];
    wire [N*DATA_WIDTH-1:0] b_skewed_cols [0:N-1];

    generate
        for (r = 0; r < N; r = r + 1) begin : gen_row_skew
            skew_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEPTH(r)                     // row‑i delay = i
            ) u_row_skew (
                .clk   (clk),
                .rst_n (rst_n),
                .din   (a_row_vectors[r]),
                .dout  (a_skewed_rows[r])
            );
        end
        for (c = 0; c < N; c = c + 1) begin : gen_col_skew
            skew_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEPTH(c)                     // column‑j delay = j
            ) u_col_skew (
                .clk   (clk),
                .rst_n (rst_n),
                .din   (b_col_vectors[c]),
                .dout  (b_skewed_cols[c])
            );
        end
    endgenerate

    // -------------------------------------------------
    // Concatenate the N skewed vectors into the single
    // wide vectors expected by the systolic_array module
    // -------------------------------------------------
    wire [N*N*DATA_WIDTH-1:0] a_skewed_vec;
    wire [N*N*DATA_WIDTH-1:0] b_skewed_vec;

    generate
        for (r = 0; r < N; r = r + 1) begin : pack_a
            assign a_skewed_vec[(r+1)*N*DATA_WIDTH-1 -: N*DATA_WIDTH] = a_skewed_rows[r];
        end
        for (c = 0; c < N; c = c + 1) begin : pack_b
            assign b_skewed_vec[(c+1)*N*DATA_WIDTH-1 -: N*DATA_WIDTH] = b_skewed_cols[c];
        end
    endgenerate

    // -------------------------------------------------
    // Instantiate the systolic array
    // -------------------------------------------------
    wire [N*N*ACC_WIDTH-1:0] c_flat;
    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_array (
        .clk       (clk),
        .rst_n     (rst_n),
        .a_row_in  (a_skewed_vec),
        .b_col_in  (b_skewed_vec),
        .c_out     (c_flat)
    );

    // -------------------------------------------------
    // Serialize the result matrix back to a stream
    // -------------------------------------------------
    localparam int TOTAL_LATENCY = 3*N - 2;
    reg [$clog2(N*N+TOTAL_LATENCY)-1:0] cycle_cnt;
    reg result_phase;                     // 0 = waiting, 1 = streaming result

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt   <= 0;
            result_phase <= 1'b0;
        end else if (!result_phase) begin
            // Wait for the deterministic latency
            if (cycle_cnt == TOTAL_LATENCY) begin
                cycle_cnt   <= 0;
                result_phase <= 1'b1;
            end else begin
                cycle_cnt <= cycle_cnt + 1;
            end
        end else begin
            // Stream N×N accumulator values
            if (cycle_cnt == N*N-1) begin
                result_phase <= 1'b0;        // back to idle (repeatable)
                cycle_cnt   <= 0;
            end else begin
                cycle_cnt <= cycle_cnt + 1;
            end
        end
    end

    // Output multiplexor
    assign c_valid = result_phase;
    assign c_data  = c_flat[ACC_WIDTH*cycle_cnt +: ACC_WIDTH];
endmodule
`default_nettype wire
