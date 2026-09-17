`include "utils.svh"

module mem_ctrl #(
    parameter dcache_if_params dcache_params,
    parameter sdram_if_params sdram_params
) (
    input clk_i,

    // If this memory is enabled yet.
    output enabled_o,

    // The address to read or write to.
    input [dcache_params.addr_width-1:0] addr_i,

    // If this controller is ready for another command.
    output can_req_o,

    // If a read should be issued.
    input r_req_i,

    // The size of the read to perform.
    dcache_data_size_e r_size_i,

    // If the value is done being read.
    output r_valid_o,

    // The read value.
    output [dcache_params.line_width-1:0] read_o,

    // If a write should be issued.
    input w_req_i,

    // The value to write.
    input [dcache_params.line_width-1:0] write_i,

    // The size of the value to write.
    dcache_data_size_e w_size_i,

    dcache_if.controller dcache,
    sdram_ctrl_if.controller sdram
);
    initial `assertEqual(0, dcache_params.line_width % sdram_params.bus_width);
    localparam int blocks_per_line = (
        dcache_params.line_width / sdram_params.bus_width
    );

    initial `assertEqual(1 << $clog2(blocks_per_line), blocks_per_line);

    localparam int sdram_addr_width = sdram_params.bank_addr_width
        + sdram_params.row_addr_width
        + sdram_params.col_addr_width;

    assign enabled_o = sdram.enabled;

    // Mark the data in the dcache dirty only when a write is issued to this
    // unit not when loading from SDRAM.
    assign dcache.w_dirty = w_req_i | (reading_sdram_done & writing_dcache);

    localparam int bus_bytes = sdram_params.bus_width / 8;

    assign dcache.addr = (r_req_i | w_req_i) ? addr_i : {
        missed_line_addr,
        (dcache_params.addr_width - dcache_params.line_addr_width)'(
            block_index * bus_bytes
        )
    };

    assign dcache.r_size = r_size_i;
    assign dcache.w_size = w_size_i;

    wire [blocks_per_line-1:0][
        sdram_params.bus_width-1:0
    ] dcache_ejected_blocks = dcache.ejected.data;

    assign dcache.r_req = (!busy & r_req_i) | reading_sdram_done;

    wire [dcache_params.line_addr_width-1:0] sdram_base_addr = (reading_sdram)
        ? missed_line_addr
        : ejected_line_addr;

    // The saved addr being read / written to when a miss occurs.
    logic [dcache_params.line_addr_width-1:0] missed_line_addr;

    // If the command currently issued is a write to the dcache.
    logic writing_dcache;

    // The saved data of a missed write.
    logic [dcache_params.line_width-1:0] saved_write;

    // The saved size of a missed write.
    dcache_data_size_e saved_w_size;

    // The data of the ejected line.
    logic [blocks_per_line-1:0][sdram_params.bus_width-1:0] ejected_line;

    // The address of the ejected line.
    logic [dcache_params.line_addr_width-1:0] ejected_line_addr;

    // If an ejected line is being written to the SDRAM.
    logic writing_sdram;
    wire writing_sdram_done = writing_sdram && sdram_done;

    // If a write should be started to the SDRAM.
    wire start_sdram_write = dcache.ejected.valid & !reading_sdram;

    // If a missed line is being read from the SDRAM.
    logic reading_sdram;
    wire reading_sdram_done = reading_sdram && sdram_done;

    // If a read should be started from the SDRAM.
    wire start_sdram_read = (writing_sdram & writing_sdram_done)
        | (!dcache.ejected.valid & dcache.miss);

    assign sdram.addr = sdram_addr_width'(
        sdram_base_addr * blocks_per_line + block_index
    );

    assign sdram.write = (dcache.ejected.valid)
        ? dcache_ejected_blocks[0]
        : ejected_line[block_index];

    assign sdram.r_req = reading_sdram & sdram.can_req;

    assign sdram.w_req = writing_sdram
        & !writing_sdram_done
        & sdram.can_req;

    always_comb begin
        if (reading_sdram_done & writing_dcache) begin
            dcache.w_req = 1;
            dcache.write = saved_write;
            dcache.w_size = saved_w_size;
        end else if (reading_sdram) begin
            dcache.w_req = sdram.r_valid;
            dcache.write = dcache_params.line_width'(sdram.read);
            dcache.w_size = dcache_data_size_of(sdram_params.bus_width);
        end else begin
            dcache.w_req = w_req_i;
            dcache.write = write_i;
            dcache.w_size = w_size_i;
        end
    end

    // If the current operation on the SDRAM is done.
    logic sdram_done = 0;

    // The current SDRAM data block being written or read from the cache line.
    logic [$clog2(blocks_per_line)-1:0] block_index;

    // If the block index should be incremented.
    wire move_next_block = sdram.r_valid | (
        writing_sdram & sdram.w_req
    );

    wire r_valid_no_miss = dcache.r_valid & !dcache.miss;
    assign r_valid_o = r_valid_no_miss & !writing_dcache;

    assign read_o = dcache.read;

    // If this controller is busy.
    logic busy = 0;

    wire w_valid_no_miss = writing_dcache & !dcache.miss
        & !reading_sdram & !writing_sdram;

    assign can_req_o = !r_req_i & !w_req_i & !busy;

    always_ff @(posedge clk_i) begin
        if (!busy) begin
            busy <= r_req_i | w_req_i;
            writing_dcache <= w_req_i;
            missed_line_addr <= addr_i[
                dcache_params.addr_width - 1
                : dcache_params.addr_width - dcache_params.line_addr_width
            ];
        end else begin
            if (w_valid_no_miss | r_valid_no_miss) begin
                busy <= 0;
            end else begin
                busy <= !reading_sdram_done;
            end
        end

        // Going to the next block when a block read is finished or a block
        // write is issued to the SDRAM.
        block_index <= block_index + move_next_block;

        // Saving ejected lines.
        if (dcache.ejected.valid & !reading_sdram) begin
            ejected_line <= dcache_ejected_blocks;
            ejected_line_addr <= dcache.ejected.addr;
        end

        reading_sdram <= (!reading_sdram_done & reading_sdram)
            | start_sdram_read;

        writing_sdram <= (!writing_sdram_done & writing_sdram)
            | start_sdram_write;

        sdram_done <= (block_index == '1) & move_next_block;

        if (!busy & w_req_i) begin
            saved_write <= write_i;
            saved_w_size <= w_size_i;
        end
    end

    // Sanity checks.
    always_ff @(posedge clk_i) begin
        assert (!(reading_sdram & writing_sdram));
        assert (!(can_req_o & (reading_sdram | writing_sdram)));
    end
endmodule
