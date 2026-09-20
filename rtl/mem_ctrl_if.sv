`include "dcache.svh"
`include "sdram.svh"

interface mem_ctrl_if #(
    parameter dcache_if_params dcache_params
);
    // If this unit is ready to take input.
    logic enabled;

    // The address being read from or written to.
    logic [dcache_params.addr_width-1:0] addr;

    // If this controller is ready for another command.
    logic can_req;

    // Set when a read is requested.
    logic r_req;

    // Set when a write is requested.
    logic w_req;

    // The size of the read to perform.
    dcache_data_size_e r_size;

    // The size of the value to write.
    dcache_data_size_e w_size;

    // Set by the unit when the result of a read is valid and ready to be read
    // by the requester.
    logic r_valid;

    // The output of a read, only valid when `r_valid` is set.
    logic [dcache_params.line_width-1:0] read;

    // The value to write.
    logic [dcache_params.line_width-1:0] write;

    modport controller (
        input enabled,

        output addr,

        input can_req,
        output r_req,
        output w_req,

        output r_size,
        output w_size,

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

        input r_size,
        input w_size,

        output r_valid,
        output read,
        input write
    );
endinterface;
