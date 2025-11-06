`define declare_dcache_line(addr_width, line_width) \
    typedef struct packed { \
        logic dirty; \
        logic [addr_width-1:0] tag; \
        logic [line_width-1:0] data; \
    } dcache_line_s

module dcache #(
    // The bit width of an address.
    parameter addr_width = 16,

    // The bit width of a cache line.
    parameter line_width = 64,

    // The number of lines.
    parameter depth = 64
) (
    input clk_i,

    // The address to read or write to.
    input [addr_width-1:0] addr_i,

    // If the cache line is ready to be read.
    input r_valid_i,

    // If the cache line is done being read, might be a miss.
    output logic r_valid_o,

    // If the read was a miss.
    output r_miss_o,

    // The read cache line.
    output [line_width-1:0] read_o,

    // If the cache line is ready to be written.
    input w_valid_i,

    // If the cache line being written is dirty.
    input dirty_i,

    // The cache line data to write.
    input [line_width-1:0] write_i,

    // If a dirty cache line was ejected after writing.
    output ejected_valid_o,

    // The address of the cache line being ejected.
    output [addr_width-1:0] ejected_addr_o,

    // The data of the cache line being ejected.
    output [line_width-1:0] ejected_o
);
    `declare_dcache_line(addr_width, line_width);

    // The data of the cache lines.
    logic [line_width-1:0] datas [depth-1:0];

    // The tags of the cache lines.
    logic [addr_width-1:0] tags [depth-1:0];

    /// The dirty flags of the cache lines.
    logic [depth-1:0] dirty_flags;

    // The set this cache line falls within.
    localparam set_width = $clog2(depth);
    wire [set_width-1:0] set = addr_i[set_width-1:0];

    logic [addr_width-1:0] last_addr;

    // The line being read or ejected.
    dcache_line_s line;
    assign read_o = line.data;
    assign r_miss_o = line.tag != last_addr;

    // The line being ejected when writing.
    logic write_done;
    assign ejected_addr_o = line.tag;
    assign ejected_o = line.data;
    assign ejected_valid_o = write_done
        && line.dirty
        && line.tag != last_addr;

    always_ff @(posedge clk_i) begin
        last_addr <= addr_i;
        r_valid_o <= r_valid_i;
        write_done <= !r_valid_i && w_valid_i;
    end

    // Reading the line or reading the ejected line.
    always_ff @(posedge clk_i) begin
        if (r_valid_i || w_valid_i) begin
            line.dirty <= dirty_flags[set];
            line.tag <= tags[set];
            line.data <= datas[set];
        end
    end

    // Writing the line.
    always_ff @(posedge clk_i) begin
        if (w_valid_i) begin
            dirty_flags[set] <= dirty_i;
            tags[set] <= addr_i;
            datas[set] <= write_i;
        end
    end
endmodule
