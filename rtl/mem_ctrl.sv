`include "utils.svh"

module mem_ctrl #(
    parameter addr_width,
    parameter line_addr_width,
    parameter line_width,

    parameter sdram_addr_width,
    parameter bank_addr_width,
    parameter row_addr_width,
    parameter col_addr_width,
    parameter bus_width,

    parameter refresh_interval,
    parameter init_cycles,
    parameter t_cas_lat,
    parameter t_rc_lat,
    parameter t_ras_lat,
    parameter t_rp_lat
) (
    input clk_i,

    // If this memory is enabled yet.
    output enabled_o,

    // The address to read or write to.
    input [addr_width-1:0] addr_i,

    // If this controller is ready for another command.
    output data_ready_o,

    // If a read should be issued.
    input r_valid_i,

    // The size of the read to perform.
    dcache_data_size_e r_size_i,

    // If the value is done being read.
    output r_valid_o,

    // The read value.
    output [line_width-1:0] read_o,

    // If a write should be issued.
    input w_valid_i,

    // The value to write.
    input [line_width-1:0] write_i,

    // The size of the value to write.
    dcache_data_size_e w_size_i,

    dcache_if.controller dcache,

    // External SDRAM interface.
	output clk_en_o,
    output cs_o,
    output ras_o,
    output cas_o,
    output we_o,

    output [bank_addr_width-1:0] bank_o,
    output [row_addr_width-1:0] sdram_a_o,
    inout [bus_width-1:0] dq_io
);
    initial `assertEqual(0, line_width % bus_width);
    localparam blocks_per_line = line_width / bus_width;

    initial `assertEqual(1 << $clog2(blocks_per_line), blocks_per_line);

    // Mark the data in the dcache dirty only when a write is issued to this
    // unit not when loading from SDRAM.
    assign dcache.w_dirty = w_valid_i | (reading_sdram_done & writing_dcache);

    localparam bus_bytes = bus_width / 8;

    assign dcache.addr = (r_valid_i | w_valid_i) ? addr_i : {
        missed_line_addr,
        (addr_width - line_addr_width)'(block_index * bus_bytes)
    };

    assign dcache.r_size = r_size_i;
    assign dcache.w_size = w_size_i;

    wire [blocks_per_line-1:0][
        bus_width-1:0
    ] dcache_ejected_blocks = dcache.ejected.data;

    assign dcache.r_req = (!busy & r_valid_i) | reading_sdram_done;

    wire [line_addr_width-1:0] sdram_base_addr = (reading_sdram)
        ? missed_line_addr
        : ejected_line_addr;

    wire [sdram_addr_width-1:0] sdram_addr = (
        sdram_base_addr * blocks_per_line
    ) + sdram_addr_width'(block_index);

    logic sdram_data_ready;
    logic sdram_r_valid_i;
    logic sdram_r_valid_o;
    logic [bus_width-1:0]sdram_read;

    wire [bus_width-1:0]sdram_write = (dcache.ejected.valid)
        ? dcache_ejected_blocks[0]
        : ejected_line[block_index];

    wire sdram_w_valid_i = writing_sdram
        & !writing_sdram_done
        & sdram_data_ready;

    sdram_ctrl #(
        .bank_addr_width(bank_addr_width),
        .row_addr_width(row_addr_width),
        .col_addr_width(col_addr_width),
        .bus_width(bus_width),
        .addr_width(sdram_addr_width),
        .refresh_interval(refresh_interval),
        .init_cycles(init_cycles),
        .t_cas_lat(t_cas_lat),
        .t_rc_lat(t_rc_lat),
        .t_ras_lat(t_ras_lat),
        .t_rp_lat(t_rp_lat)
    ) sdram (
        .clk_i(clk_i),
        .enabled_o(enabled_o),
        .addr_i(sdram_addr),
        .data_ready_o(sdram_data_ready),
        .r_valid_i(sdram_r_valid_i),
        .w_valid_i(sdram_w_valid_i),
        .r_valid_o(sdram_r_valid_o),
        .read_o(sdram_read),
        .write_i(sdram_write),
        .clk_en_o(clk_en_o),
        .cs_o(cs_o),
        .ras_o(ras_o),
        .cas_o(cas_o),
        .we_o(we_o),
        .bank_o(bank_o),
        .sdram_a_o(sdram_a_o),
        .dq_io(dq_io)
    );

    // The saved addr being read / written to when a miss occurs.
    logic [line_addr_width-1:0] missed_line_addr;

    // If the command currently issued is a write to the dcache.
    logic writing_dcache;

    // The saved data of a missed write.
    logic [line_width-1:0] saved_write;

    // The saved size of a missed write.
    dcache_data_size_e saved_w_size;

    // The data of the ejected line.
    logic [blocks_per_line-1:0][bus_width-1:0] ejected_line;

    // The address of the ejected line.
    logic [line_addr_width-1:0] ejected_line_addr;

    // If an ejected line is being written to the SDRAM.
    logic writing_sdram;
    wire writing_sdram_done = writing_sdram && sdram_done;

    // If a write should be started to the SDRAM.
    wire start_sdram_write = dcache.ejected.valid & !reading_sdram;

    // If a missed line is being read from the SDRAM.
    logic reading_sdram;
    wire reading_sdram_done = reading_sdram && sdram_done;

    assign sdram_r_valid_i = reading_sdram & sdram_data_ready;

    // If a read should be started from the SDRAM.
    wire start_sdram_read = (writing_sdram & writing_sdram_done)
        | (!dcache.ejected.valid & dcache.miss);

    always_comb begin
        if (reading_sdram_done & writing_dcache) begin
            dcache.w_req = 1;
            dcache.write = saved_write;
            dcache.w_size = saved_w_size;
        end else if (reading_sdram) begin
            dcache.w_req = sdram_r_valid_o;
            dcache.write = line_width'(sdram_read);
            dcache.w_size = dcache_data_size_of(bus_width);
        end else begin
            dcache.w_req = w_valid_i;
            dcache.write = write_i;
            dcache.w_size = w_size_i;
        end
    end

    // If the current operation on the SDRAM is done.
    logic sdram_done = 0;

    // The current SDRAM data block being written or read from the cache line.
    logic [$clog2(blocks_per_line)-1:0] block_index;

    // If the block index should be incremented.
    wire move_next_block = sdram_r_valid_o | (
        writing_sdram & sdram_w_valid_i
    );

    wire r_valid_no_miss = dcache.r_valid & !dcache.miss;
    assign r_valid_o = r_valid_no_miss & !writing_dcache;

    assign read_o = dcache.read;

    // If this controller is busy.
    logic busy = 0;

    wire w_valid_no_miss = writing_dcache & !dcache.miss
        & !reading_sdram & !writing_sdram;

    assign data_ready_o = !r_valid_i & !w_valid_i & !busy;

    always_ff @(posedge clk_i) begin
        if (!busy) begin
            busy <= r_valid_i | w_valid_i;
            writing_dcache <= w_valid_i;
            missed_line_addr <= addr_i[
                addr_width - 1
                : addr_width - line_addr_width
            ];
        end else begin
            if (w_valid_no_miss | r_valid_no_miss) begin
                busy <= 0;
            end else begin
                busy <= !reading_sdram_done;
            end
        end
    end

    always_ff @(posedge clk_i) begin
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

        if (!busy & w_valid_i) begin
            saved_write <= write_i;
            saved_w_size <= w_size_i;
        end
    end

    // Sanity checks.
    always_ff @(posedge clk_i) begin
        assert (!(reading_sdram & writing_sdram));
        assert (!(data_ready_o & (reading_sdram | writing_sdram)));
    end
endmodule
