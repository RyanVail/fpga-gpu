`include "rcp_stage.sv"

// TODO: This is not an optimal implementation.
module rcp #(
    parameter width = 16,
    parameter iters = 3
) (
    input clk_i,

    input logic v_i,
    input [width-1:0] a_i,

    output logic [width-1:0] r_o,
    output logic ready_o
);
    wire [iters-1:0][width-1:0] ests;

    // Determining the floored log2 of the input.
    logic [$clog2(width)-1:0] log;
    always_comb begin
        log = 0;
        for (int i = 0; i < width; i=i+1) begin
            if (a_i[i]) log = i[$clog2(width)-1:0];
        end
    end

    // Optimized first iteration based on powers of two.
    logic [width:0] first_est;
    assign first_est = 1 <<< (width - log);

    logic [width*2-1:0] first_est_mul_val;
    assign first_est_mul_val = (
        {(width)'(1'b0), a_i} <<< (width - log)
    ) + 1'b1;

    wire [width*2-1:0] first_delta = (2 <<< width) - first_est_mul_val;
    assign ests[0] = {first_est * first_delta}[width*2-1:width];

    // Additional iterations.
    genvar i;
    generate
        for (i = 1; i < iters; i=i+1) begin
            rcp_stage #(
                .width(width)
            ) stage (
                .a_i(a_i),
                .est_i(ests[i-1]),
                .est_o(ests[i])
            );
        end
    endgenerate

    assign r_o = ests[iters-1];

    always_ff @(posedge clk_i) begin
        ready_o <= v_i;
    end

    endmodule
