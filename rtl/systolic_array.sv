module systolic_array #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  logic clk,
    input  logic rst_n,
    // Flat buses: N elements packed together
    input  logic [N*DATA_WIDTH-1:0] a_in_flat,
    input  logic [N*DATA_WIDTH-1:0] b_in_flat,
    output logic [N*N*ACC_WIDTH-1:0] c_out_flat
);
    // Internal wires: a_wire[row][col], b_wire[row][col]
    wire [DATA_WIDTH-1:0] a_wire [0:N-1][0:N];
    wire [DATA_WIDTH-1:0] b_wire [0:N][0:N-1];

    genvar i,j;
    generate
        for (i=0;i<N;i++) begin : conn_a
            assign a_wire[i][0] = a_in_flat[i*DATA_WIDTH +: DATA_WIDTH];
        end
        for (j=0;j<N;j++) begin : conn_b
            assign b_wire[0][j] = b_in_flat[j*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    wire [ACC_WIDTH-1:0] c_grid [0:N-1][0:N-1];

    generate
        for (i=0;i<N;i++) begin : row
            for (j=0;j<N;j++) begin : col
                pe #(.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) u_pe (
                    .clk   (clk),
                    .rst_n (rst_n),
                    .a_in  (a_wire[i][j]),
                    .b_in  (b_wire[i][j]),
                    .a_out (a_wire[i][j+1]),
                    .b_out (b_wire[i+1][j]),
                    .c_out (c_grid[i][j])
                );
                assign c_out_flat[(i*N+j)*ACC_WIDTH +: ACC_WIDTH] = c_grid[i][j];
            end
        end
    endgenerate
endmodule