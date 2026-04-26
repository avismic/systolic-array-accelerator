module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic [DATA_WIDTH-1:0] a_in,
    input  logic [DATA_WIDTH-1:0] b_in,
    output logic [DATA_WIDTH-1:0] a_out,
    output logic [DATA_WIDTH-1:0] b_out,
    output logic [ACC_WIDTH-1:0]  c_out
);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            a_out <= '0; b_out <= '0; c_out <= '0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            c_out <= c_out + ({{(ACC_WIDTH-DATA_WIDTH){1'b0}},a_in} *
                              {{(ACC_WIDTH-DATA_WIDTH){1'b0}},b_in});
        end
    end
endmodule