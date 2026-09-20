`include "alu.svh"

module ctrl_unit_tb #(
    parameter mem_addr_width = 16,

    parameter dcache_if_params dcache_params = '{
        addr_width: mem_addr_width,
        line_addr_width: mem_addr_width - 3,
        line_width: 64
    }
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
    output [`REG_WIDTH-1:0] iupt_arg_o
);
    mem_ctrl_if #(dcache_params) mem_ctrl_bus();

    assign mem_ctrl_bus.enabled = 1;
    assign mem_ctrl_bus.can_req = 1;
    assign mem_ctrl_bus.r_valid = 0;
    assign mem_ctrl_bus.read = 'X;

    /* verilator lint_off UNUSEDSIGNAL */
    wire a = mem_ctrl_bus.enabled
        && mem_ctrl_bus.can_req
        && mem_ctrl_bus.r_req
        && mem_ctrl_bus.w_req
        && (mem_ctrl_bus.r_size == DCACHE_DATA_8_BITS)
        && (mem_ctrl_bus.w_size == DCACHE_DATA_8_BITS)
        && mem_ctrl_bus.r_valid
        && (mem_ctrl_bus.read == 0)
        && (mem_ctrl_bus.write == 0);
    /* verilator lint_on UNUSEDSIGNAL */

    ctrl_unit #(
        .mem_addr_width(mem_addr_width),
        .dcache_params(dcache_params)
    ) unit (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .load_i(load_i),
        .load_inst_i(load_inst_i),
        .iupt_o(iupt_o),
        .iupt_arg_o(iupt_arg_o),
        .mem_ctrl_bus(mem_ctrl_bus)
    );
endmodule
