#include "Vdcache.h"
#include "verilated.h"
#include <cassert>
#include <cstdint>
#include <random>

static constexpr uint32_t addr_width = 16;
static constexpr uint32_t line_width = 64;
static constexpr uint32_t depth = 64;

static void init(Vdcache* dut) {
    dut->clk_i = 0;
}

static void pulse(Vdcache* dut) {
    dut->eval();
    dut->clk_i = 1;
    dut->eval();
    dut->clk_i = 0;
}

static void write_read(VerilatedContext* contextp, Vdcache* dut) {
    init(dut);

    dut->r_valid_i = 0;

    dut->w_valid_i = 1;
    dut->addr_i = 0;
    dut->write_i = 25;

    pulse(dut);
    dut->w_valid_i = 0;
    pulse(dut);

    dut->w_valid_i = 0;
    dut->r_valid_i = 1;

    pulse(dut);
    assert(dut->r_valid_o == 1);
    assert(dut->read_o == 25);

    dut->final();
}

static void dirty_write(VerilatedContext* contextp, Vdcache* dut) {
    init(dut);

    dut->r_valid_i = 0;
    dut->w_valid_i = 1;
    dut->addr_i = 0;
    dut->write_i = 5;
    dut->dirty_i = 1;

    pulse(dut);

    dut->addr_i = 64;
    dut->write_i = 25;
    dut->dirty_i = 0;

    assert(dut->ejected_valid_o == 0);

    pulse(dut);

    dut->w_valid_i = 0;

    assert(dut->ejected_valid_o == 1);
    assert(dut->ejected_addr_o == 0);
    assert(dut->ejected_o == 5);
}

// TODO: This should also be testing for uncached writes and ejections too but
// that would require more simulated state within C++.
static void rand_cached_writes(VerilatedContext* contextp, Vdcache* dut) {
    init(dut);

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

    uint64_t values[max_addr];

    // Initing the values.
    dut->w_valid_i = 1;
    for (size_t i = 0; i < max_addr; i++) {
        const uint64_t value = value_dist(gen);

        values[i] = value;
        dut->addr_i = i;
        dut->write_i = value;
        pulse(dut);
    }

    // Waiting for the writes to finish.
    dut->w_valid_i = 0;
    pulse(dut);
    pulse(dut);

    for (uint32_t i = 0; i < iterations; i++) {
        const size_t addr = addr_dist(gen);
        const uint64_t value = value_dist(gen);

        assert(dut->ejected_valid_o == 0);

        values[addr] = value;

        dut->w_valid_i = 1;
        dut->addr_i = addr;
        dut->write_i = value;

        pulse(dut);

        dut->w_valid_i = 0;
    }

    // Waiting for the writes to finish.
    dut->w_valid_i = 0;
    pulse(dut);
    pulse(dut);

    // Reading back the values.
    for (size_t i = 0; i < max_addr; i++) {
        dut->addr_i = i;
        dut->r_valid_i = 1;

        pulse(dut);
        dut->r_valid_i = 0;

        assert(dut->r_valid_o == 1);
        assert(dut->read_o == values[i]);
    }
}

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vdcache* dut = new Vdcache{contextp};
    write_read(contextp, dut);
    dirty_write(contextp, dut);
    rand_cached_writes(contextp, dut);

    delete dut;
    delete contextp;
    return 0;
}
