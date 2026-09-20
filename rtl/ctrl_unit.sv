`include "utils.svh"
`include "dcache.svh"
`include "alu.svh"

module ctrl_unit #(
    // The maximum number of instructions that can be loaded into a single
    // program.
    parameter inst_limit = 1024,

    // The width of a memory address.
    parameter mem_addr_width = 16,

    parameter dcache_if_params dcache_params
) (
    input clk_i,
    input reset_i,

    // Stop execution and load in the program's instructions.
    // Should only be done after a reset.
    input load_i,

    // The current instruction being loaded in.
    input [`INST_WIDTH-1:0] load_inst_i,

    // TODO: This is tmp for testing.
    output iupt_o,
    output [`REG_WIDTH-1:0] iupt_arg_o,

    mem_ctrl_if mem_ctrl_bus
);
    localparam inst_index_width = $clog2(inst_limit);

    logic [`INST_WIDTH-1:0] inst;
    logic [inst_index_width-1:0] pc;

    /* verilator lint_off UNUSEDSIGNAL */
    alu_flags_s alu_flags;
    /* verilator lint_on UNUSEDSIGNAL */

    alu #(
        .pc_width(inst_index_width),
        .mem_addr_width(mem_addr_width),
        .dcache_params(dcache_params)
    ) alu (
        .clk_i(clk_i),
        .reset_i(reset_i || load_i),
        .inst_i(inst),
        .pc_o(pc),
        .flags_o(alu_flags),
        .mem_bus(mem_ctrl_bus),
        .iupt_o(iupt_o),
        .iupt_arg_o(iupt_arg_o)
    );

    logic [inst_index_width-1:0] load_index;

    logic [inst_limit-1:0][`INST_WIDTH-1:0] insts;
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            insts <= 0;
            load_index <= 0;
        end else if (load_i) begin
            insts[load_index] <= load_inst_i;
            load_index <= load_index + 1;
        end
    end

    // TODO: This should try to do memory loading too.
    always_ff @(posedge clk_i) begin
        inst <= insts[pc];
    end
endmodule
