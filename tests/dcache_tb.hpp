#ifndef DCACHE_HPP
#define DCACHE_HPP

namespace dcache {

enum DataSize : uint8_t {
    DATA_8_BITS = 0b00,
    DATA_16_BITS = 0b01,
    DATA_32_BITS = 0b10,
    DATA_64_BITS = 0b11,
};

}

#endif
