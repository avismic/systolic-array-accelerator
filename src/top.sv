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
    output wire [ACC_WIDTH-1:0]    c_data,

    // -----------------------------------------------------------------
    // DEBUG ONLY – expose the flattened row / column vectors
    // -----------------------------------------------------------------
    output wire [N*N*DATA_WIDTH-1:0] debug_a_flat,
    output wire [N*N*DATA_WIDTH-1:0] debug_b_flat
);
    // -----------------------------------------------------------------
    // 0) Parameters used for the result‑phase controller
    // -----------------------------------------------------------------
    localparam int TOTAL_LATENCY   = 3*N - 2;                 // pipeline latency
    localparam int RESULT_COUNT    = N*N;                     // number of output words
    localparam int RESULT_CNT_W   = $clog2(RESULT_COUNT)+1;   // width for result counter
    localparam int LATENCY_CNT_W  = $clog2(TOTAL_LATENCY)+1;   // width for latency counter

    // -----------------------------------------------------------------
    // 1) Capture matrices A (row‑major) and B (column‑major) in RAM
    // -----------------------------------------------------------------
    logic [DATA_WIDTH-1:0] a_mat [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] b_mat [0:N-1][0:N-1];

    // write‑pointer state
    integer a_row_ptr, a_col_ptr;
    integer b_row_ptr, b_col_ptr;
    // flags that indicate the whole matrix has been received
    logic   a_done,   b_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_row_ptr <= 0; a_col_ptr <= 0; a_done <= 0;
            b_row_ptr <= 0; b_col_ptr <= 0; b_done <= 0;
        end else begin
            // ----- A (row‑major) -----
            if (a_valid && !a_done) begin
                a_mat[a_row_ptr][a_col_ptr] <= a_data;
                if (a_col_ptr == N-1) begin
                    a_col_ptr <= 0;
                    if (a_row_ptr == N-1) a_done <= 1;
                    else                 a_row_ptr <= a_row_ptr + 1;
                end else begin
                    a_col_ptr <= a_col_ptr + 1;
                end
            end
            // ----- B (column‑major) -----
            if (b_valid && !b_done) begin
                b_mat[b_row_ptr][b_col_ptr] <= b_data;
                if (b_row_ptr == N-1) begin
                    b_row_ptr <= 0;
                    if (b_col_ptr == N-1) b_done <= 1;
                    else                  b_col_ptr <= b_col_ptr + 1;
                end else begin
                    b_row_ptr <= b_row_ptr + 1;
                end
            end
        end
    end

    // -----------------------------------------------------------------
    // 2) Pack the RAM contents into vector‑wide buses for the skew buffers
    // -----------------------------------------------------------------
    wire [N*DATA_WIDTH-1:0] a_row_vectors [0:N-1];
    wire [N*DATA_WIDTH-1:0] b_col_vectors [0:N-1];

    genvar r, c;
    generate
        // ---- rows of A (row‑major) ----
        for (r = 0; r < N; r = r + 1) begin : pack_A_rows
            for (c = 0; c < N; c = c + 1) begin : pack_bits
                assign a_row_vectors[r][(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] = a_mat[r][c];
            end
        end
        // ---- columns of B (column‑major) ----
        for (c = 0; c < N; c = c + 1) begin : pack_B_cols
            for (r = 0; r < N; r = r + 1) begin : pack_bits
                assign b_col_vectors[c][(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] = b_mat[r][c];
            end
        end
    endgenerate

    // -----------------------------------------------------------------
    // 3) Skew buffers – one per row and one per column
    // -----------------------------------------------------------------
    wire [N*DATA_WIDTH-1:0] a_skewed_rows [0:N-1];
    wire [N*DATA_WIDTH-1:0] b_skewed_cols [0:N-1];

    generate
        for (r = 0; r < N; r = r + 1) begin : gen_row_skew
            skew_buffer #(
                .WIDTH (N*DATA_WIDTH),
                .DEPTH (r)                 // row i delayed by i cycles
            ) u_row_skew (
                .clk   (clk),
                .rst_n (rst_n),
                .din   (a_row_vectors[r]),
                .dout  (a_skewed_rows[r])
            );
        end
        for (c = 0; c < N; c = c + 1) begin : gen_col_skew
            skew_buffer #(
                .WIDTH (N*DATA_WIDTH),
                .DEPTH (c)                 // column j delayed by j cycles
            ) u_col_skew (
                .clk   (clk),
                .rst_n (rst_n),
                .din   (b_col_vectors[c]),
                .dout  (b_skewed_cols[c])
            );
        end
    endgenerate

    // -----------------------------------------------------------------
    // 4) Flatten the whole set of rows / columns so the array can receive them
    // -----------------------------------------------------------------
    wire [N*N*DATA_WIDTH-1:0] a_flat;
    wire [N*N*DATA_WIDTH-1:0] b_flat;

    generate
        for (r = 0; r < N; r = r + 1) begin : flatten_rows
            assign a_flat[(r+1)*N*DATA_WIDTH-1 -: N*DATA_WIDTH] = a_skewed_rows[r];
        end
        for (c = 0; c < N; c = c + 1) begin : flatten_cols
            assign b_flat[(c+1)*N*DATA_WIDTH-1 -: N*DATA_WIDTH] = b_skewed_cols[c];
        end
    endgenerate

    // expose the flatten vectors for debugging (they are just wires)
    assign debug_a_flat = a_flat;
    assign debug_b_flat = b_flat;

    // -----------------------------------------------------------------
    // 5) Instantiate the systolic array (now it receives flattened data)
    // -----------------------------------------------------------------
    wire [N*N*ACC_WIDTH-1:0] c_flat;
    systolic_array #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) u_array (
        .clk            (clk),
        .rst_n          (rst_n),
        .a_row_flat     (a_flat),
        .b_col_flat     (b_flat),
        .c_out          (c_flat)
    );

    // -----------------------------------------------------------------
    // 6) Result‑phase controller: generate c_valid and serialize c_flat
    // -----------------------------------------------------------------
    reg [LATENCY_CNT_W-1:0] latency_cnt;
    reg [RESULT_CNT_W-1:0]  result_cnt;
    reg                     result_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latency_cnt  <= 0;
            result_cnt   <= 0;
            result_phase <= 0;
        end else begin
            // ----- wait until both matrices have been stored -----
            if (!result_phase) begin
                if (a_done && b_done) begin
                    if (latency_cnt == TOTAL_LATENCY-1) begin
                        result_phase <= 1'b1;
                        latency_cnt <= 0;
                    end else begin
                        latency_cnt <= latency_cnt + 1'b1;
                    end
                end
            end else begin
                // ----- stream the N*N results -----
                if (result_cnt == RESULT_COUNT-1) begin
                    result_phase <= 1'b0;
                    result_cnt   <= 0;
                end else begin
                    result_cnt <= result_cnt + 1'b1;
                end
            end
        end
    end

    // c_valid is asserted only while we are streaming results
    assign c_valid = result_phase;
    // Serialize the flattened result vector using the current output index
    assign c_data  = c_flat[ACC_WIDTH*result_cnt +: ACC_WIDTH];
endmodule
`default_nettype wire
