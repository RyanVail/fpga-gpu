`include "dcache_if.svh"

module dcache_tb #(
    parameter addr_width = 16,
    parameter line_addr_width = 13,
    parameter line_width = 64,
    parameter depth = 64
) (
    input clk_i,

    input logic [addr_width-1:0] addr_i,
    output logic miss_o,

    input dcache_data_size_e r_size_i,
    input logic r_req_i,
    output logic r_valid_o,
    output logic [line_width-1:0] read_o,

    input dcache_data_size_e w_size_i,
    input logic w_req_i,
    input logic w_dirty_i,
    input logic [line_width-1:0] write_i,

    output logic ejected_valid_o,
    output logic [line_addr_width-1:0] ejected_addr_o,
    output logic [line_width-1:0] ejected_o
);
    dcache_if #(
        .addr_width(addr_width),
        .line_addr_width(line_addr_width),
        .line_width(line_width)
    ) bus();

    assign bus.addr = addr_i;
    assign miss_o = bus.miss;

    assign bus.r_size = r_size_i;
    assign bus.r_req = r_req_i;
    assign r_valid_o = bus.r_valid;
    assign read_o = bus.read;

    assign bus.w_size = w_size_i;
    assign bus.w_req = w_req_i;
    assign bus.w_dirty = w_dirty_i;
    assign bus.write = write_i;
    assign ejected_valid_o = bus.ejected.valid;
    assign ejected_addr_o = bus.ejected.addr;
    assign ejected_o = bus.ejected.data;

    dcache #(
        .addr_width(addr_width),
        .line_addr_width(line_addr_width),
        .line_width(line_width),
        .depth(depth)
    ) cache (
        .clk_i(clk_i),
        .bus(bus)
    );
endmodule
