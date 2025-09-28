`include "sim/sdram.sv"
`include "mem_ctrl.sv"
`include "utils.sv"

module mem_ctrl_IS42S16160G_7TL #(
    // The number of rows to simulate. Used to keep the simulation time down.
    // The real hardware has 8192 rows.
    parameter rows = 16
) (
    input clk_i,
    output enabled_o,

    input [addr_width-1:0] addr_i,

    output data_ready_o,

    input r_valid_i,
    input w_valid_i,

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
    localparam refresh_interval = $rtoi(
        $ceil((64 * 1e6) / 8192 / clk_cycle_ns)
    );

    localparam init_cycles = $rtoi($ceil(init_delay_ns / clk_cycle_ns));
    localparam t_cas_lat = 2;
    localparam t_ccd_lat = 1;
    localparam t_rcd_lat = 2;
    localparam t_rc_lat = 8;
    localparam t_ras_lat = 6;
    localparam t_rp_lat = 2;
    localparam t_mrd_lat = 2;

    logic clk_en;
    logic cs;
    logic ras;
    logic cas;
    logic we;
    logic [bank_addr_width-1:0] bank;
    logic [row_addr_width-1:0] sdram_a;
    logic [bus_width-1:0] dq_io;

    sdram_sim #(
        .banks(banks),
        .rows(rows),
        .bus_width(bus_width),
        .col_width(col_width),
        .bank_addr_width(bank_addr_width),
        .row_addr_width(row_addr_width),
        .col_addr_width(col_addr_width),
        .init_delay_cycles(init_cycles),
        .t_cas_lat(t_cas_lat),
        .t_ccd_lat(t_ccd_lat),
        .t_rcd_lat(t_rcd_lat),
        .t_rc_lat(t_rc_lat),
        .t_ras_lat(t_ras_lat),
        .t_rp_lat(t_rp_lat),
        .t_mrd_lat(t_mrd_lat)
    ) sim (
        .clk_i(clk_i),
        .clk_en_i(clk_en),
        .cs_i(cs),
        .ras_i(ras),
        .cas_i(cas),
        .we_i(we),
        .bank_i(bank),
        .sdram_a_i(sdram_a),
        .dq_io(dq_io)
    );

    localparam sdram_addr_width = bank_addr_width + row_addr_width + col_addr_width;
    localparam addr_width = sdram_addr_width - (line_width / bus_width);
    localparam line_width = 64;
    localparam dcache_depth = 64;

    mem_ctrl #(
        .addr_width(addr_width),
        .line_width(line_width),
        .dcache_depth(dcache_depth),
        .sdram_addr_width(sdram_addr_width),
        .bank_addr_width(bank_addr_width),
        .row_addr_width(row_addr_width),
        .col_addr_width(col_addr_width),
        .bus_width(bus_width),
        .refresh_interval(refresh_interval),
        .init_cycles(init_cycles),
        .t_cas_lat(t_cas_lat),
        .t_rc_lat(t_rc_lat),
        .t_ras_lat(t_ras_lat),
        .t_rp_lat(t_rp_lat)
    ) ctrl (
        .clk_i(clk_i),
        .addr_i(addr_i),
        .data_ready_o(data_ready_o),
        .r_valid_i(r_valid_i),
        .w_valid_i(w_valid_i),
        .r_valid_o(r_valid_o),
        .read_o(read_o),
        .write_i(write_i),
        .clk_en_o(clk_en),
        .cs_o(cs),
        .ras_o(ras),
        .cas_o(cas),
        .we_o(we),
        .bank_o(bank),
        .sdram_a_o(sdram_a),
        .dq_io(dq_io),
        .enabled_o(enabled_o)
    );
endmodule
