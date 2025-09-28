`include "sdram_ctrl.sv"
`include "dcache.sv"
`include "utils.sv"

module mem_ctrl #(
    // The bit width of an address of a cache line.
    parameter addr_width,

    // The bit width of a cache line.
    parameter line_width,

    // The number of cache lines the dcache should have.
    parameter dcache_depth,

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
    output enabled_o,

    input [addr_width-1:0] addr_i,

    output data_ready_o,

    input r_valid_i,

    output r_valid_o,

    output [line_width-1:0] read_o,

    input w_valid_i,

    input [line_width-1:0] write_i,

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
    logic dcache_r_valid;
    logic dcache_r_miss;
    logic [line_width-1:0] dcache_read;

    // TODO: Finish this.
    wire dcache_dirty = 1;

    wire [addr_width-1:0] dcache_addr = (r_valid_i | w_valid_i)
        ? addr_i
        : saved_addr;

    wire dcache_write_valid = w_valid_i | (reading & read_finished);

    wire [line_width-1:0] dcache_write;
    assign dcache_write = w_valid_i ? write_i : saved_line;

    logic ejected_valid;
    logic [addr_width-1:0] ejected_addr;
    logic [line_width-1:0] ejected_data;

    dcache #(
        .addr_width(addr_width),
        .line_width(line_width),
        .depth(dcache_depth)
    ) dcache (
        .clk_i(clk_i),
        .addr_i(dcache_addr),
        .r_valid_i(r_valid_i),
        .r_valid_o(dcache_r_valid),
        .r_miss_o(dcache_r_miss),
        .read_o(dcache_read),
        .w_valid_i(dcache_write_valid),
        .write_i(dcache_write),
        .dirty_i(dcache_dirty),
        .ejected_valid_o(ejected_valid),
        .ejected_addr_o(ejected_addr),
        .ejected_o(ejected_data)
    );

    wire enabled;
    assign enabled_o = enabled;

    wire [sdram_addr_width-1:0] sdram_addr = (saved_addr * blocks_per_line)
        + sdram_addr_width'(block_index);

    logic sdram_data_ready;
    logic sdram_r_valid_i;
    logic sdram_r_valid_o;
    logic [bus_width-1:0]sdram_read;

    wire [bus_width-1:0]sdram_write = saved_line[block_index];
    wire sdram_w_valid_i = writing & !write_finished & sdram_data_ready;

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
        .enabled_o(enabled),
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

    initial `assertEqual(0, line_width % bus_width);
    localparam blocks_per_line = line_width / bus_width;

    initial `assertEqual(1 << $clog2(blocks_per_line), blocks_per_line);
    logic [$clog2(blocks_per_line)-1:0] block_index;

    // If this controller is writing to the SDRAM.
    logic writing;
    logic started_writing;
    wire write_finished = started_writing && block_index == 0;

    // If this controller is reading to the SDRAM.
    logic reading;
    logic started_reading;
    wire read_finished = started_reading && block_index == 0;

    logic [blocks_per_line-1:0][bus_width-1:0] saved_line;
    logic [addr_width-1:0] saved_addr;

    wire r_valid_non_miss = dcache_r_valid & !dcache_r_miss;
    assign r_valid_o = r_valid_non_miss | (reading & read_finished);

    assign read_o = (reading & read_finished) ? saved_line : dcache_read;

    // If a command has been issued to this controller.
    logic issued;
    initial issued = 0;

    // TODO: This should be explicitly based on the lat of the dcache.
    logic write_issued;
    initial write_issued = 0;

    wire w_non_eject_done = write_issued & !ejected_valid;

    assign data_ready_o = !r_valid_i & !w_valid_i
        & !writing & !reading
        & !issued;

    always_ff @(posedge clk_i) begin
        if (r_valid_i | w_valid_i) issued <= 1;
        if (issued & (read_finished | write_finished)) issued <= 0;

        write_issued <= w_valid_i;
        if (w_non_eject_done | r_valid_non_miss) issued <= 0;
    end

    always_ff @(posedge clk_i) begin
        // Automatically going to the next block when a read is finished or a
        // write is issued to the SDRAM.
        block_index <= block_index + (sdram_r_valid_o || (writing & sdram_w_valid_i));

        // Reading from the SDRAM when a cache line read is missed.
        if (reading | (dcache_r_miss & dcache_r_valid)) begin
            if (sdram_r_valid_o) begin
                saved_line[block_index] <= sdram_read;
            end

            started_reading <= started_reading | sdram_r_valid_o;
            sdram_r_valid_i <= !read_finished & sdram_data_ready;
            reading <= !read_finished | dcache_r_miss;

            // A dcache write overriding the old line with the new one will be
            // started when the reading is finished.
        end else begin
            started_reading <= 0;
        end

        if (ejected_valid) begin
            saved_line <= ejected_data;
            saved_addr <= ejected_addr;
        end

        // Writing ejected lines back to the SDRAM. Writing to the SDRAM is
        // delayed by one cycle to wait for *saved_line* to be updated.
        if (writing | ejected_valid) begin
            started_writing <= started_writing | (writing & sdram_data_ready);
            writing <= !write_finished | ejected_valid;
        end else begin
            started_writing <= 0;
        end

        if (r_valid_i) begin
            saved_addr <= addr_i;
        end
    end
endmodule
