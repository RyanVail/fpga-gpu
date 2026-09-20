`include "utils.svh"
`include "dcache.svh"
`include "sdram.svh"

module mem_ctrl #(
    parameter dcache_if_params dcache_params,
    parameter sdram_if_params sdram_params
) (
    input clk_i,

    dcache_if.controller dcache,
    sdram_ctrl_if.controller sdram,
    mem_ctrl_if.device bus
);
    initial `assertEqual(0, dcache_params.line_width % sdram_params.bus_width);
    localparam int blocks_per_line = (
        dcache_params.line_width / sdram_params.bus_width
    );

    initial `assertEqual(1 << $clog2(blocks_per_line), blocks_per_line);

    localparam int sdram_addr_width = sdram_params.bank_addr_width
        + sdram_params.row_addr_width
        + sdram_params.col_addr_width;

    assign bus.enabled = sdram.enabled;

    // Mark the data in the dcache dirty only when a write is issued to this
    // unit not when loading from SDRAM.
    assign dcache.w_dirty = bus.w_req
        | (reading_sdram_done & writing_dcache);

    localparam int bus_bytes = sdram_params.bus_width / 8;

    assign dcache.addr = (bus.r_req | bus.w_req) ? bus.addr : {
        missed_line_addr,
        (dcache_params.addr_width - dcache_params.line_addr_width)'(
            block_index * bus_bytes
        )
    };

    assign dcache.r_size = bus.r_size;
    assign dcache.w_size = bus.w_size;

    wire [blocks_per_line-1:0][
        sdram_params.bus_width-1:0
    ] dcache_ejected_blocks = dcache.ejected.data;

    assign dcache.r_req = (!busy & bus.r_req) | reading_sdram_done;

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
            dcache.w_req = bus.w_req;
            dcache.write = bus.write;
            dcache.w_size = bus.w_size;
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
    assign bus.r_valid = r_valid_no_miss & !writing_dcache;

    assign bus.read = dcache.read;

    // If this controller is busy.
    logic busy = 0;

    wire w_valid_no_miss = writing_dcache & !dcache.miss
        & !reading_sdram & !writing_sdram;

    assign bus.can_req = !bus.r_req & !bus.w_req & !busy;

    always_ff @(posedge clk_i) begin
        if (!busy) begin
            busy <= bus.r_req | bus.w_req;
            writing_dcache <= bus.w_req;
            missed_line_addr <= bus.addr[
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

        if (!busy & bus.w_req) begin
            saved_write <= bus.write;
            saved_w_size <= bus.w_size;
        end
    end

    // Sanity checks.
    always_ff @(posedge clk_i) begin
        assert (!(reading_sdram & writing_sdram));
        assert (!(bus.can_req & (reading_sdram | writing_sdram)));
    end
endmodule
