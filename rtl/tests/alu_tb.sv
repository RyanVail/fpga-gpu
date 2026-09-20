`include "alu.svh"

module alu_tb #(
    parameter int mem_addr_width = 16,
    parameter int pc_width = 10,

    parameter dcache_if_params dcache_params = '{
        addr_width: mem_addr_width,
        line_addr_width: mem_addr_width - 3,
        line_width: 64
    }
) (
    input clk_i,
    input reset_i,

    input [`INST_WIDTH-1:0] inst_i,

    output logic [pc_width-1:0] pc_o,

    output alu_flags_s flags_o,

    output logic w_req_o,
    output logic [mem_addr_width-1:0] w_addr_o,
    output logic [dcache_params.line_width-1:0] write_o,
    output dcache_data_size_e w_size_o,

    output logic r_req_o,
    output logic [mem_addr_width-1:0] r_addr_o,
    output dcache_data_size_e r_size_o,

    // High when an interrupt is raised.
    output iupt_o,

    // The argument supplied to the interrupt handler.
    output [`REG_WIDTH-1:0] iupt_arg_o
);
    mem_ctrl_if #(dcache_params) mem_ctrl_bus();

    assign mem_ctrl_bus.enabled = 1;
    assign mem_ctrl_bus.can_req = 1;
    assign mem_ctrl_bus.r_valid = 0;
    assign mem_ctrl_bus.read = 'X;

    assign r_addr_o = mem_ctrl_bus.addr;
    assign w_addr_o = mem_ctrl_bus.addr;

    assign r_req_o = mem_ctrl_bus.r_req;
    assign r_size_o = mem_ctrl_bus.r_size;

    assign w_req_o = mem_ctrl_bus.w_req;
    assign w_size_o = mem_ctrl_bus.w_size;
    assign write_o = mem_ctrl_bus.write;

    /* verilator lint_off UNUSEDSIGNAL */
    wire a = mem_ctrl_bus.enabled
        && mem_ctrl_bus.can_req
        && mem_ctrl_bus.r_valid
        && (mem_ctrl_bus.read == 0);
    /* verilator lint_on UNUSEDSIGNAL */

    alu #(
        .mem_addr_width(mem_addr_width),
        .pc_width(pc_width),
        .dcache_params(dcache_params)
    ) alu_impl (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .inst_i(inst_i),
        .pc_o(pc_o),
        .flags_o(flags_o),
        .mem_bus(mem_ctrl_bus),
        .iupt_o(iupt_o),
        .iupt_arg_o(iupt_arg_o)
    );
endmodule
