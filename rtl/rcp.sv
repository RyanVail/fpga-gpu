`include "rcp_stage.sv"
`include "utils.sv"

// Approximates a reciprocal function.
//
// Two lookup tables are used.
//
// The first lookup table stores full `width` sized entries for all RCP results
// until the first value in the second lookup table.
//
// The second lookup table starts at `lut_first` and spans till `lut_end` with
// a configurable width `lut_entry_width`. The number of the entries in this
// table is determined by `lut_precision`.
//
// If the value doesn't fall into the two lookup tables an approximate value is
// returned using the log2 of the value.
module rcp #(
    parameter width = 16,
    parameter iters = 2,

    // The precision of the lookup table.
    // The number of entries in the lut will be (1 << precision).
    parameter lut_precision = 4,

    // The width of the entries in the lookup table.
    parameter lut_entry_width = 3,

    // The first value in the lookup table.
    parameter lut_first = 1 << 6,

    // The last value in the lookup table.
    parameter lut_end = 1 << 9
) (
    input clk_i,

    input v_i,
    input [width-1:0] a_i,

    output logic [width-1:0] r_o,
    output logic ready_o
);
    /* verilator lint_off UNUSEDPARAM */
    // The latency of this module in cycles.
    localparam lat = 1;
    /* verilator lint_on UNUSEDPARAM */

    localparam lut_entries = 1 << lut_precision;
    localparam lut_step = 1 << $clog2((lut_end - lut_first) / lut_entries);
    function [lut_entries-1:0][lut_entry_width-1:0] gen_lut();
        logic [lut_entries-1:0][lut_entry_width-1:0] arr;
        for (int i = 0; i < lut_entries; i++) begin
            arr[i] = lut_entry_width'(
                {lut_entry_width + $clog2(lut_first){'1}} / (
                    lut_first + (lut_step * i)
                )
            );
        end
        return arr;
    endfunction

    function [lut_first-1:0][width-1:0] gen_flut();
        logic [lut_first-1:0][width-1:0] arr;
        arr[0] = 'x;
        for (int i = 1; i < lut_first; i=i+1) begin
            arr[i] = width'(
                ({width{1'b1}} / i)
            );
        end
        return arr;
    endfunction

    // The bits to left shift the values in the lut by to get the true rough
    // estimations.
    localparam lut_scale = (width - $clog2(lut_first)) - lut_entry_width;

    /* verilator lint_off UNUSEDSIGNAL */
    localparam logic [lut_first-1:0][width-1:0] flut = gen_flut();
    localparam logic [lut_entries-1:0][lut_entry_width-1:0] lut = gen_lut();
    /* verilator lint_off UNUSEDSIGNAL */

    wire [iters-1:0][width-1:0] ests;

    // TODO: Replace the log2 with something better.
    // Determining the floored log2 of the input.
    logic [$clog2(width)-1:0] log;
    always_comb begin
        log = 0;
        for (int i = 0; i < width; i=i+1) begin
            if (a_i[i]) log = i[$clog2(width)-1:0];
        end
    end

    logic [width-1:0] first_est;
    always_comb begin
        if (a_i < lut_first) begin
            first_est = flut[a_i];
        end else if (a_i > lut_end) begin
            first_est = (1 <<< (width - log)) - 1;
        end else begin
            first_est = width'(lut[(a_i - lut_first) / lut_step]) <<< lut_scale;
        end
    end

    assign ests[0] = first_est;

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

    always_ff @(posedge clk_i) begin
        r_o <= ests[iters-1];
        ready_o <= v_i;
    end

    endmodule
