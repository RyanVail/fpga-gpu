`ifndef DCACHE_SVH
`define DCACHE_SVH

typedef enum logic [1:0] {
    DCACHE_DATA_8_BITS = 2'b00,
    DCACHE_DATA_16_BITS = 2'b01,
    DCACHE_DATA_32_BITS = 2'b10,
    DCACHE_DATA_64_BITS = 2'b11
} dcache_data_size_e;

`endif
