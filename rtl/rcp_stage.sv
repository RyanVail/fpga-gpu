module rcp_stage #(
    parameter width = 16
) (
    input [width-1:0] a_i,
    input [width-1:0] est_i,
    output [width-1:0] est_o
);
    wire [width*2-1:0] est_mul_val = {(width)'(1'b0), a_i} * est_i;
    wire [width*2-1:0] delta = (2 <<< width) - est_mul_val;

    /* verilator lint_off UNUSEDSIGNAL */
    wire [width*2-1:0] mid_est = est_i * delta;
    /* verilator lint_on UNUSEDSIGNAL */

    assign est_o = mid_est[width*2-1:width];
endmodule
