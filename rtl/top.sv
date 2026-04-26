module top #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [N*DATA_WIDTH-1:0] a_in_flat,
    input  logic [N*DATA_WIDTH-1:0] b_in_flat,
    output logic [N*N*ACC_WIDTH-1:0] c_out_flat
);
    wire [N*DATA_WIDTH-1:0] a_skewed, b_skewed;

    skew_buffer #(.N(N),.DATA_WIDTH(DATA_WIDTH)) u_skew (
        .clk(clk), .rst_n(rst_n),
        .a_in_flat(a_in_flat), .b_in_flat(b_in_flat),
        .a_skewed(a_skewed),   .b_skewed(b_skewed)
    );

    systolic_array #(.N(N),.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) u_array (
        .clk(clk), .rst_n(rst_n),
        .a_in_flat(a_skewed), .b_in_flat(b_skewed),
        .c_out_flat(c_out_flat)
    );
endmodule