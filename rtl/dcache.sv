`include "utils.svh"

module dcache #(
    parameter addr_width,
    parameter line_addr_width,
    parameter line_width,

    // The number of cache lines in this dcache.
    parameter depth
) (
    input clk_i,
    dcache_if.device bus
);
    typedef struct packed {
        logic dirty;
        logic [line_addr_width-1:0] tag;
        logic [line_width-1:0] data;
    } line_s;

    typedef union packed {
        logic [line_width/8-1:0][7:0] b8;
        logic [line_width/16-1:0][15:0] b16;
        logic [line_width/32-1:0][31:0] b32;
        logic [line_width/64-1:0][63:0] b64;
    } dcache_data_s;

    // Cache line size must be divisible by 64 bits.
    initial `assertEqual(0, line_width % 64);

    // The data of the cache lines.
    dcache_data_s datas [depth-1:0];

    // The tags of the cache lines.
    logic [line_addr_width-1:0] tags [depth-1:0];

    // The dirty flags of the cache lines.
    logic [depth-1:0] dirty_flags;

    // The address of the cache line being accessed.
    wire [line_addr_width-1:0] line_addr = bus.addr[
        addr_width - 1
        : addr_width - line_addr_width
    ];

    // The set this cache line falls within.
    localparam set_width = $clog2(depth);
    wire [set_width-1:0] set = line_addr[set_width-1:0];

    logic [line_addr_width-1:0] last_addr;

    // The line being read or ejected.
    line_s line;
    assign bus.read = line.data;
    assign bus.miss = (line.tag != last_addr) & (write_done | bus.r_valid);

    // Set one cycle after a write is issued.
    logic write_done;

    // The line being ejected when writing.
    assign bus.ejected.addr = line.tag;
    assign bus.ejected.data = line.data;
    assign bus.ejected.valid = bus.miss & line.dirty;

    always_ff @(posedge clk_i) begin
        last_addr <= line_addr;
        bus.r_valid <= bus.r_req;
        write_done <= !bus.r_req && bus.w_req;
    end

    localparam addr_width_8bit = $clog2(line_width / 8);
    localparam addr_width_16bit = $clog2(line_width / 16);
    localparam addr_width_32bit = $clog2(line_width / 32);
    localparam addr_width_64bit = $clog2(line_width / 64);

    wire [addr_width_8bit:0] addr_8bit = bus.addr[addr_width_8bit:0];
    wire [addr_width_16bit:0] addr_16bit = bus.addr[addr_width_8bit:1];
    wire [addr_width_32bit:0] addr_32bit = bus.addr[addr_width_8bit:2];
    wire [addr_width_64bit:0] addr_64bit = bus.addr[addr_width_8bit:3];

    // Reading the line or reading the ejected line.
    always_ff @(posedge clk_i) begin
        if (bus.r_req || bus.w_req) begin
            line.dirty <= dirty_flags[set];
            line.tag <= tags[set];

            if (line_addr_width'(tags[set]) != line_addr) begin
                line.data <= datas[set];
            end else casez (bus.r_size)
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
        if (bus.w_req) begin
            dirty_flags[set] <= bus.w_dirty;
            tags[set] <= line_addr;

            casez (bus.w_size)
                DCACHE_DATA_8_BITS:
                    datas[set].b8[addr_8bit] <= bus.write[7:0];
                DCACHE_DATA_16_BITS:
                    datas[set].b16[addr_16bit] <= bus.write[15:0];
                DCACHE_DATA_32_BITS:
                    datas[set].b32[addr_32bit] <= bus.write[31:0];
                DCACHE_DATA_64_BITS:
                    datas[set].b64[addr_64bit] <= bus.write[63:0];
            endcase
        end
    end
endmodule
