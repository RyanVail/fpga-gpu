`include "utils.svh"
`include "sdram.svh"

module sdram_IS42S16160G_7TL #(
    // The number of rows to simulate. Used to keep the simulation time down.
    // The real hardware has 8192 rows.
    parameter rows = 16
) (
    input clk_i,
    output enabled_o,

    input [addr_width-1:0] addr_i,

    output can_req_o,

    input r_req_i,
    input w_req_i,

    output r_valid_o,

    output [bus_width-1:0] read_o,
    input [bus_width-1:0] write_i
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

    localparam addr_width = bank_addr_width + row_addr_width + col_addr_width;

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

    sdram_if #(sdram_params) bus();
    sdram_sim #(sdram_params) sim (
        .clk_i(clk_i),
        .bus(bus)
    );

    sdram_ctrl_if #(sdram_params) ctrl_bus ();
    assign enabled_o = ctrl_bus.enabled;
    assign ctrl_bus.addr = addr_i;
    assign can_req_o = ctrl_bus.can_req;
    assign ctrl_bus.r_req = r_req_i;
    assign ctrl_bus.w_req = w_req_i;
    assign r_valid_o = ctrl_bus.r_valid;
    assign read_o = ctrl_bus.read;
    assign ctrl_bus.write = write_i;

    sdram_ctrl #(sdram_params) sdram_ctrl (
        .clk_i(clk_i),
        .ctrl_bus(ctrl_bus),
        .bus(bus)
    );
endmodule
