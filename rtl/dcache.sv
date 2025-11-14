`include "dcache.svh"
`include "utils.sv"

`define declare_dcache_line(addr_width, line_width) \
    typedef struct packed { \
        logic dirty; \
        logic [addr_width-1:0] tag; \
        logic [line_width-1:0] data; \
    } dcache_line_s

`define declare_dcache_data(line_width) \
    typedef union packed { \
        logic [line_width/8-1:0][7:0] b8; \
        logic [line_width/16-1:0][15:0] b16; \
        logic [line_width/32-1:0][31:0] b32; \
        logic [line_width/64-1:0][63:0] b64; \
    } dcache_data_s;

module dcache #(
    // The bit width of a byte address.
    parameter addr_width = 16,

    // The bit width of a line address.
    parameter line_addr_width = addr_width - $clog2(line_width / 8),

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

    // If the last read / write was a miss.
    output miss_o,

    // The read cache line.
    output [line_width-1:0] read_o,

    // The size of the data being read.
    input dcache_data_size_e r_size_i,

    // If the cache line is ready to be written.
    input w_valid_i,

    // If the cache line being written is dirty.
    input dirty_i,

    // The cache line data to write.
    input [line_width-1:0] write_i,

    // The size of the data being written.
    input dcache_data_size_e w_size_i,

    // If a dirty cache line was ejected after writing.
    output ejected_valid_o,

    // The address of the cache line being ejected.
    output [line_addr_width-1:0] ejected_addr_o,

    // The data of the cache line being ejected.
    output [line_width-1:0] ejected_o
);
    `declare_dcache_line(line_addr_width, line_width);
    `declare_dcache_data(line_width);

    // Cache line size must be divisible by 64 bits.
    initial `assertEqual(0, line_width % 64);

    // The data of the cache lines.
    dcache_data_s datas [depth-1:0];

    // The tags of the cache lines.
    logic [line_addr_width-1:0] tags [depth-1:0];

    // The dirty flags of the cache lines.
    logic [depth-1:0] dirty_flags;

    // The address of the cache line being accessed.
    wire [line_addr_width-1:0] line_addr = addr_i[
        addr_width - 1
        : addr_width - line_addr_width
    ];

    // The set this cache line falls within.
    localparam set_width = $clog2(depth);
    wire [set_width-1:0] set = line_addr[set_width-1:0];

    logic [line_addr_width-1:0] last_addr;

    // The line being read or ejected.
    dcache_line_s line;
    assign read_o = line.data;
    assign miss_o = (line.tag != last_addr) & (write_done | r_valid_o);

    // Set one cycle after a write is issued.
    logic write_done;

    // The line being ejected when writing.
    assign ejected_addr_o = line.tag;
    assign ejected_o = line.data;
    assign ejected_valid_o = miss_o & line.dirty;

    always_ff @(posedge clk_i) begin
        last_addr <= line_addr;
        r_valid_o <= r_valid_i;
        write_done <= !r_valid_i && w_valid_i;
    end

    localparam addr_width_8bit = $clog2(line_width / 8);
    localparam addr_width_16bit = $clog2(line_width / 16);
    localparam addr_width_32bit = $clog2(line_width / 32);
    localparam addr_width_64bit = $clog2(line_width / 64);

    wire [addr_width_8bit:0] addr_8bit = addr_i[addr_width_8bit:0];
    wire [addr_width_16bit:0] addr_16bit = addr_i[addr_width_16bit:0];
    wire [addr_width_32bit:0] addr_32bit = addr_i[addr_width_32bit:0];
    wire [addr_width_64bit:0] addr_64bit = addr_i[addr_width_64bit:0];

    // Reading the line or reading the ejected line.
    always_ff @(posedge clk_i) begin
        if (r_valid_i || w_valid_i) begin
            line.dirty <= dirty_flags[set];
            line.tag <= tags[set];

            casez (r_size_i)
                DCACHE_DATA_8_BITS:
                    line.data <= line_width'(datas[set].b8[addr_8bit]);
                DCACHE_DATA_16_BITS:
                    line.data <= line_width'(datas[set].b16[addr_16bit]);
                DCACHE_DATA_32_BITS:
                    line.data <= line_width'(datas[set].b32[addr_32bit]);
                DCACHE_DATA_64_BITS:
                    line.data <= line_width'(datas[set].b64[addr_64bit]);
            endcase
        end
    end

    // Writing the line.
    always_ff @(posedge clk_i) begin
        if (w_valid_i) begin
            dirty_flags[set] <= dirty_i;
            tags[set] <= line_addr;

            casez (w_size_i)
                DCACHE_DATA_8_BITS:
                    datas[set].b8[addr_8bit] <= write_i[7:0];
                DCACHE_DATA_16_BITS:
                    datas[set].b16[addr_16bit] <= write_i[15:0];
                DCACHE_DATA_32_BITS:
                    datas[set].b32[addr_32bit] <= write_i[31:0];
                DCACHE_DATA_64_BITS:
                    datas[set].b64[addr_64bit] <= write_i[63:0];
            endcase
        end
    end
endmodule
