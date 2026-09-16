`include "dcache.svh"

interface dcache_if #(
    parameter dcache_if_params p
);
    typedef struct packed {
        // If a dirty cache line was ejected after writing.
        logic valid;

        // The address of the line being ejected.
        logic [p.line_addr_width-1:0] addr;

        // The data of the line being ejected.
        logic [p.line_width-1:0] data;
    } ejected_s;

    // The address to read or write to.
    logic [p.addr_width-1:0] addr;

    // If the last read / write was a miss.
    logic miss;

    // The size of the data being read.
    dcache_data_size_e r_size;

    // If a read is requested.
    logic r_req;

    // If the read is finished, might be a miss.
    logic r_valid;

    // The read cache line.
    logic [p.line_width-1:0] read;

    // The size of the data being written.
    dcache_data_size_e w_size;

    // If a write is requested.
    logic w_req;

    // If the line being written is dirty.
    logic w_dirty;

    // The cache line data to write.
    logic [p.line_width-1:0] write;

    // Holds the information of ejected cache lines.
    ejected_s ejected;

    modport controller (
        output addr,
        input miss,

        output r_size,
        output r_req,
        input r_valid,
        input read,

        output w_size,
        output w_req,
        output w_dirty,
        output write,
        input ejected
    );

    modport device (
        input addr,
        output miss,

        input r_size,
        input r_req,
        output r_valid,
        output read,

        input w_size,
        input w_req,
        input w_dirty,
        input write,
        output ejected
    );
endinterface
