`include "utils.svh"
`include "dcache.svh"
`include "dcache_if.sv"
`include "sdram.svh"

module mem_ctrl_IS42S16160G_7TL #(
    // The number of rows to simulate. Used to keep the simulation time down.
    // The real hardware has 8192 rows.
    parameter int rows = 16,

    parameter int line_width = 64,
    parameter int dcache_depth = 64
) (
    input clk_i,
    output enabled_o,

    input [addr_width-1:0] addr_i,

    output can_req_o,

    input r_req_i,
    dcache_data_size_e r_size_i,

    input w_req_i,
    dcache_data_size_e w_size_i,

    output r_valid_o,

    output [line_width-1:0] read_o,
    input [line_width-1:0] write_i
);
    localparam banks = 4;

    localparam bank_addr_width = 2;
    localparam row_addr_width = 13;
    localparam col_addr_width = 9;
    localparam bus_width = 16;
    localparam col_width = 512;

    localparam init_delay_ns = 100000;
    localparam clk_cycle_ns = 7.5;

    // 8192 refreshes per 64ms
    localparam refreshes_per_sec = $rtoi(
        $ceil(1 / 64e-3) * 8192
    );

    localparam sdram_if_params sdram_params = '{
        banks: banks,
        rows: rows,
        bus_width: bus_width,
        col_width: col_width,
        bank_addr_width: bank_addr_width,
        row_addr_width: row_addr_width,
        col_addr_width: col_addr_width,
        clk_cycle_ns: clk_cycle_ns,
        init_delay_ns: init_delay_ns,
        refreshes_per_sec: refreshes_per_sec,
        t_cas_lat: 2,
        t_ccd_lat: 1,
        t_rcd_lat: 2,
        t_rc_lat: 8,
        t_ras_lat: 6,
        t_rp_lat: 2,
        t_mrd_lat: 2
    };

    sdram_if #(sdram_params) sdram_bus();
    sdram_sim #(sdram_params) sim (
        .clk_i(clk_i),
        .bus(sdram_bus)
    );

    sdram_ctrl_if #(sdram_params) sdram_ctrl_bus();
    sdram_ctrl #(sdram_params) sdram_controller (
        .clk_i(clk_i),
        .ctrl_bus(sdram_ctrl_bus),
        .bus(sdram_bus)
    );

    localparam sdram_addr_width = bank_addr_width + row_addr_width + col_addr_width;
    localparam addr_width = sdram_addr_width - (line_width / bus_width);
    localparam line_addr_width = addr_width - $clog2(line_width / 8);

    localparam dcache_if_params dcache_params = '{
        addr_width: addr_width,
        line_addr_width: line_addr_width,
        line_width: line_width
    };

    dcache_if #(dcache_params) dcache_bus();
    dcache #(
        .p(dcache_params),
        .depth(dcache_depth)
    ) cache (
        .clk_i(clk_i),
        .bus(dcache_bus)
    );

    mem_ctrl_if #(dcache_params) mem_ctrl_bus();

    assign enabled_o = mem_ctrl_bus.enabled;
    assign mem_ctrl_bus.addr = addr_i;
    assign can_req_o = mem_ctrl_bus.can_req;

    assign mem_ctrl_bus.r_req = r_req_i;
    assign mem_ctrl_bus.r_size = r_size_i;
    assign mem_ctrl_bus.w_req = w_req_i;
    assign mem_ctrl_bus.w_size = w_size_i;

    assign r_valid_o = mem_ctrl_bus.r_valid;
    assign read_o = mem_ctrl_bus.read;
    assign mem_ctrl_bus.write = write_i;

    mem_ctrl #(
        .dcache_params(dcache_params),
        .sdram_params(sdram_params)
    ) ctrl (
        .clk_i(clk_i),

        .dcache(dcache_bus),
        .sdram(sdram_ctrl_bus),
        .bus(mem_ctrl_bus)
    );
endmodule
