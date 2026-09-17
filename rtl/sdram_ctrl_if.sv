`include "sdram.svh"

interface sdram_ctrl_if #(
    parameter sdram_if_params p
);
    localparam int addr_width = (
        p.bank_addr_width + p.row_addr_width + p.col_addr_width
    );

    // If this unit is ready to take input.
    logic enabled;

    // The address being read from or written to.
    logic [addr_width-1:0] addr;

    // If this unit is ready for another request.
    logic can_req;

    // Set when a read is requested.
    logic r_req;

    // Set when a write is requested.
    logic w_req;

    // Set by the unit when the result of a read is valid and ready to be read
    // by the requester.
    logic r_valid;

    // The output of a read, only valid when `r_valid` is set.
    logic [p.bus_width-1:0] read;

    // The p.value to be written.
    logic [p.bus_width-1:0] write;

    modport controller (
        input enabled,

        output addr,

        input can_req,
        output r_req,
        output w_req,

        input r_valid,
        input read,
        output write
    );

    modport device (
        output enabled,

        input addr,

        output can_req,
        input r_req,
        input w_req,

        output r_valid,
        output read,
        input write
    );
endinterface
