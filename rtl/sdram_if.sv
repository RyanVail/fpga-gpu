`include "sdram.svh"

interface sdram_if #(
    parameter sdram_if_params p
);
    logic clk_en;

    logic cs;
    logic ras;
    logic cas;
    logic we;

    logic [p.bank_addr_width-1:0] bank;
    logic [p.row_addr_width-1:0] a;
    logic [p.bus_width-1:0] dq;

    modport controller (
        output clk_en,

        output cs,
        output ras,
        output cas,
        output we,

        output bank,
        output a,
        inout dq
    );

    modport device (
        input clk_en,

        input cs,
        input ras,
        input cas,
        input we,

        input bank,
        input a,
        inout dq
    );
endinterface
