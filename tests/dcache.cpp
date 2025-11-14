#define DUT Vdcache

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Vdcache.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include "dcache.hpp"
#include <cassert>
#include <cstdint>
#include <random>

using namespace dcache;

static uint32_t ns = 0;
static VerilatedFstC* tfp;

static constexpr uint32_t addr_width = 16;
static constexpr uint32_t line_width = 64;
static constexpr uint32_t depth = 64;

static void init(DUT* dut) {
    dut->clk_i = 0;
}

static void pulse(DUT* dut) {
    if (dut->traceCapable) tfp->dump(ns);
    ns++;

    dut->eval();
    dut->clk_i = 1;

    if (dut->traceCapable) tfp->dump(ns);
    ns++;

    dut->eval();
    dut->clk_i = 0;
}

static void write(
    DUT* dut,
    DataSize size,
    uint16_t addr,
    uint64_t data,
    bool dirty = false
) {
    dut->r_valid_i = 0;
    dut->w_valid_i = 1;
    dut->dirty_i = (uint8_t)dirty;
    dut->w_size_i = size;
    dut->addr_i = addr;
    dut->write_i = data;
    pulse(dut);

    assert(!dut->r_valid_o);
}

static uint64_t read(DUT* dut, DataSize size, uint16_t addr) {
    dut->r_valid_i = 1;
    dut->w_valid_i = 0;
    dut->r_size_i = size;
    dut->addr_i = addr;
    pulse(dut);

    assert(dut->r_valid_o);
    return dut->read_o;
}

static void write_read(DUT* dut) {
    write(dut, DATA_64_BITS, 0, 25);
    assert(read(dut, DATA_64_BITS, 0) == 25);
}

static void dirty_write(DUT* dut) {
    write(dut, DATA_64_BITS, 0, 0, false);

    write(dut, DATA_64_BITS, 0, 5, true);
    assert(!dut->ejected_valid_o);

    write(dut, DATA_64_BITS, 64 * 8, 25, true);
    assert(dut->ejected_valid_o);
    assert(dut->ejected_addr_o == 0);
    assert(dut->ejected_o == 5);

    assert(read(dut, DATA_64_BITS, 64 * 8) == 25);

    assert(read(dut, DATA_64_BITS, 0) == 25);
    assert(dut->ejected_valid_o);
    assert(dut->ejected_addr_o == 64);
    assert(dut->ejected_o = 25);
}

// TODO: This should also be testing for uncached writes and ejections too but
// that would require more simulated state within C++.
static void rand_cached_writes(DUT* dut) {
    static_assert(line_width == 64);
    constexpr uint64_t max_value = UINT64_MAX;
    constexpr size_t max_addr = depth;
    constexpr uint32_t iterations = max_addr * 2;

    // Creating the rng.
    std::mt19937 gen;
    std::uniform_int_distribution<uint64_t> value_dist(0, max_value);
    std::uniform_int_distribution<size_t> addr_dist(0, max_addr);

    dut->w_valid_i = 0;
    dut->r_valid_i = 0;
    dut->dirty_i = 1;

    pulse(dut);

    uint64_t values[max_addr + 1];

    // Initing the values.
    dut->w_valid_i = 1;
    for (size_t i = 0; i < max_addr; i++) {
        const uint64_t value = value_dist(gen);

        values[i] = value;
        write(dut, DATA_64_BITS, i * 8, value);
    }

    // Waiting for the writes to finish.
    dut->w_valid_i = 0;
    pulse(dut);
    pulse(dut);

    for (uint32_t i = 0; i < iterations; i++) {
        const size_t addr = addr_dist(gen);
        const uint64_t value = value_dist(gen);

        assert(!dut->ejected_valid_o);

        values[addr] = value;
        write(dut, DATA_64_BITS, addr * 8, value);
    }

    // Waiting for the writes to finish.
    dut->w_valid_i = 0;
    pulse(dut);
    pulse(dut);

    // Reading back the values.
    for (size_t i = 0; i < max_addr; i++) {
        assert(read(dut, DATA_64_BITS, i * 8) == values[i]);
    }
}

static void mixed_read(DUT* dut) {
    const uint64_t a = 0x9D013E5279D4A96A;
    write(dut, DATA_64_BITS, 0, a);

    assert(read(dut, DATA_16_BITS, 2) == ((a >> 16) & 0xFFFF));
    assert(read(dut, DATA_16_BITS, 4) == ((a >> 32) & 0xFFFF));
    assert(read(dut, DATA_32_BITS, 4) == ((a >> 32) & 0xFFFFFFFF));
}

static void mixed_size_write_read(DUT* dut) {
    const uint16_t first = (3 << 8) | 25;
    const uint8_t second = 61;
    write(dut, DATA_16_BITS, 0, first);
    write(dut, DATA_8_BITS, 2, second);

    assert(read(dut, DATA_16_BITS, 0) == first);
    assert(read(dut, DATA_8_BITS, 0) == (first & 255));
    assert(read(dut, DATA_8_BITS, 1) == (first >> 8));
    assert(read(dut, DATA_8_BITS, 2) == second);
}

static void read_invalid_addr(DUT* dut) {
    init(dut);

    const uint64_t a = 0x32A308CE250F8C76;
    write(dut, DATA_64_BITS, 0, a);

    for (uint16_t i = 0; i < line_width / 8; i++) {
        assert(read(dut, DATA_64_BITS, i) == a);
    }

    assert(read(dut, DATA_32_BITS, 0) == (a & 0xFFFFFFFF));
    assert(read(dut, DATA_32_BITS, 3) == (a & 0xFFFFFFFF));

    assert(read(dut, DATA_16_BITS, 2) == ((a >> 16) & 0xFFFF));
    assert(read(dut, DATA_16_BITS, 3) == ((a >> 16) & 0xFFFF));
}

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    DUT* dut = new DUT{contextp};

    if (dut->traceCapable) {
        Verilated::traceEverOn(true);
        tfp = new VerilatedFstC;
        dut->trace(tfp, -1);
        tfp->open("build/waves/" STR(DUT) ".fst");
    }

    init(dut);
    write_read(dut);
    dirty_write(dut);
    rand_cached_writes(dut);
    mixed_read(dut);
    mixed_size_write_read(dut);
    read_invalid_addr(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
