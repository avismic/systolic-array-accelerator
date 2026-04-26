module skew_buffer #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [N*DATA_WIDTH-1:0] a_in_flat,
    input  logic [N*DATA_WIDTH-1:0] b_in_flat,
    output logic [N*DATA_WIDTH-1:0] a_skewed,
    output logic [N*DATA_WIDTH-1:0] b_skewed
);
    // shift registers per lane
    logic [DATA_WIDTH-1:0] a_sr [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] b_sr [0:N-1][0:N-1];

    genvar i, s;
    generate
        for (i=0;i<N;i++) begin : lane
            for (s=0;s<N;s++) begin : stage
                always_ff @(posedge clk) begin
                    if (!rst_n) begin
                        a_sr[i][s] <= '0;
                        b_sr[i][s] <= '0;
                    end else begin
                        if (s==0) begin
                            a_sr[i][0] <= a_in_flat[i*DATA_WIDTH +: DATA_WIDTH];
                            b_sr[i][0] <= b_in_flat[i*DATA_WIDTH +: DATA_WIDTH];
                        end else begin
                            a_sr[i][s] <= a_sr[i][s-1];
                            b_sr[i][s] <= b_sr[i][s-1];
                        end
                    end
                end
            end
            // lane 0: no delay; lane i: i register stages
            if (i==0) begin : tap0
                assign a_skewed[i*DATA_WIDTH +: DATA_WIDTH] = a_in_flat[i*DATA_WIDTH +: DATA_WIDTH];
                assign b_skewed[i*DATA_WIDTH +: DATA_WIDTH] = b_in_flat[i*DATA_WIDTH +: DATA_WIDTH];
            end else begin : tapi
                assign a_skewed[i*DATA_WIDTH +: DATA_WIDTH] = a_sr[i][i-1];
                assign b_skewed[i*DATA_WIDTH +: DATA_WIDTH] = b_sr[i][i-1];
            end
        end
    endgenerate
endmodule