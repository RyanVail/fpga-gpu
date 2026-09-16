`ifndef DCACHE_SVH
`define DCACHE_SVH

typedef enum logic [1:0] {
    DCACHE_DATA_8_BITS = 2'b00,
    DCACHE_DATA_16_BITS = 2'b01,
    DCACHE_DATA_32_BITS = 2'b10,
    DCACHE_DATA_64_BITS = 2'b11
} dcache_data_size_e;

function dcache_data_size_e dcache_data_size_of(int size);
    casez (size)
        8: begin
            return DCACHE_DATA_8_BITS;
        end 16: begin
            return DCACHE_DATA_16_BITS;
        end 32: begin
            return DCACHE_DATA_32_BITS;
        end 64: begin
            return DCACHE_DATA_64_BITS;
        end
    endcase
endfunction

typedef struct {
    // The bit width of a byte address.
    int addr_width;

    // The bit width of a line address.
    int line_addr_width;

    // The bit width of a cache line.
    int line_width;
} dcache_if_params;

`endif
