#define DUT Vmem_ctrl_IS42S16160G_7TL

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Vmem_ctrl_IS42S16160G_7TL.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include "dcache_tb.hpp"
#include <cassert>
#include <cstdint>
#include <random>

using namespace dcache;

static uint32_t ns = 0;
static constexpr uint32_t max_ns = 10000000;
static VerilatedFstC* tfp;

static constexpr uint32_t init_delay_cycles = (uint32_t)(100000 / 7.5);
static constexpr size_t addr_width = 16;
static constexpr size_t bus_width = 16;

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

    if (ns > max_ns) {
        tfp->close();
        fprintf(stderr, "=== Reached max time ===\n");
        exit(-1);
    }
}

static void write(DUT* dut, DataSize size, uint16_t addr, uint64_t data) {
    dut->r_valid_i = 0;
    dut->w_valid_i = 1;
    dut->w_size_i = size;
    dut->addr_i = addr;
    dut->write_i = data;

    pulse(dut);
    assert(!dut->data_ready_o);

    dut->w_valid_i = 0;
    while (!dut->data_ready_o) pulse(dut);
}

static uint64_t read(DUT* dut, DataSize size, uint16_t addr) {
    dut->r_valid_i = 1;
    dut->w_valid_i = 0;
    dut->r_size_i = size;
    dut->addr_i = addr;

    pulse(dut);
    assert(!dut->data_ready_o);

    dut->r_valid_i = 0;
    while (!dut->r_valid_o) {
        pulse(dut);
        assert(!dut->data_ready_o || dut->r_valid_o);
    }

    while (!dut->data_ready_o) {
        pulse(dut);
        assert(!dut->r_valid_o);
    }

    return dut->read_o;
}

static void write_read(DUT* dut) {
    init(dut);

    const uint64_t a = 0x598CCE2C946487A5;
    const uint64_t b = 0xFCDA8DC80282068E;

    write(dut, DATA_64_BITS, 0, a);
    write(dut, DATA_64_BITS, 8, b);

    assert(read(dut, DATA_64_BITS, 0) == a);
    assert(read(dut, DATA_64_BITS, 8) == b);
}

static void write_read_eject(DUT* dut) {
    init(dut);

    const uint64_t a = 0x42C07E72A7229C12;
    const uint64_t b = 0xA5162A2A539D0FCB;

    write(dut, DATA_64_BITS, 64 * 8, a);
    assert(read(dut, DATA_64_BITS, 64 * 8) == a);

    write(dut, DATA_64_BITS, 0, b);

    assert(read(dut, DATA_64_BITS, 0) == b);
    const auto value = read(dut, DATA_64_BITS, 64 * 8);
    assert(read(dut, DATA_64_BITS, 64 * 8) == a);
}

static void mixed_size_write_read(DUT* dut) {
    init(dut);

    write(dut, DATA_64_BITS, 0, 0x42C07E72A7229C12);
    write(dut, DATA_64_BITS, 64 * 8, 0xA5162A2A539D0FCB);
    write(dut, DATA_8_BITS, 0, 0);

    const auto result = read(dut, DATA_64_BITS, 0);
    assert(
        read(dut, DATA_64_BITS, 0) == (0x42C07E72A7229C12 & ~(uint64_t)0xFF)
    );
}

static void mixed_size_read(DUT* dut) {
    init(dut);

    const uint64_t a = 0x2A965A3BE4207209;
    write(dut, DATA_64_BITS, 8, a);

    assert(read(dut, DATA_8_BITS, 8) == (a & 0xFF));
    assert(read(dut, DATA_16_BITS, 8) == (a & 0xFFFF));
    assert(read(dut, DATA_32_BITS, 8) == (a & 0xFFFFFFFF));

    assert(read(dut, DATA_8_BITS, 9) == ((a >> 8) & 0xFF));
    assert(read(dut, DATA_8_BITS, 15) == ((a >> 56) & 0xFF));

    assert(read(dut, DATA_16_BITS, 10) == ((a >> 16) & 0xFFFF));
}

static void mixed_size_read_on_load(DUT* dut) {
    init(dut);

    const uint64_t a = 0x2A965A3BE4207209;
    const uint64_t b = 0x63EEBFB282B7C71F;
    write(dut, DATA_64_BITS, 0, a);
    write(dut, DATA_64_BITS, 64 * 8, b);

    //assert(read(dut, DATA_8_BITS, 0) == (a & 0xFF));
    assert(read(dut, DATA_16_BITS, 64 * 8 + 2) == ((b >> 16) & 0xFFFF));
}

static void ordered_read_writes(DUT* dut) {
    init(dut);

    constexpr uint64_t max_value = UINT64_MAX;
    constexpr size_t max_addr = 511;

    // Creating the rng.
    std::mt19937 gen;
    std::uniform_int_distribution<uint64_t> value_dist(0, max_value);
    std::uniform_int_distribution<size_t> addr_dist(0, max_addr);
    std::uniform_int_distribution<uint8_t> rw_dist(0, 1);

    dut->w_valid_i = 0;
    dut->r_valid_i = 0;
    pulse(dut);

    uint64_t values[max_addr + 1];

    // Initing the values.
    for (size_t i = 0; i <= max_addr; i++) {
        const uint64_t value = value_dist(gen);
        write(dut, DATA_64_BITS, i * 8, value);
        values[i] = value;

        while (!dut->data_ready_o) pulse(dut);
    }

    for (size_t i = 0; i <= max_addr; i++) {
        const uint64_t value = read(dut, DATA_64_BITS, i * 8);
        assert(value == values[i]);
        while (!dut->data_ready_o) pulse(dut);
    }
}

static void rand_read_writes(DUT* dut) {
    init(dut);

    constexpr uint64_t max_value = UINT64_MAX;
    constexpr size_t max_addr = 511;
    constexpr size_t iterations = max_addr * 2;

    // Creating the rng.
    std::mt19937 gen;
    std::uniform_int_distribution<uint64_t> value_dist(0, max_value);
    std::uniform_int_distribution<size_t> addr_dist(0, max_addr);
    std::uniform_int_distribution<uint8_t> rw_dist(0, 1);

    dut->w_valid_i = 0;
    dut->r_valid_i = 0;
    pulse(dut);

    uint64_t values[max_addr + 1];

    // Initing the values.
    for (size_t i = 0; i <= max_addr; i++) {
        const uint64_t value = value_dist(gen);
        write(dut, DATA_64_BITS, i * 8, value);
        values[i] = value;
    }

    // Randomly reading or writing.
    for (size_t i = 0; i < iterations; i++) {
        const size_t addr = addr_dist(gen);
        const uint8_t rw = rw_dist(gen);

        if (rw == 0) {
            const uint64_t value = read(dut, DATA_64_BITS, addr * 8);
            assert(value == values[addr]);
        } else if (rw == 1) {
            const uint64_t value = value_dist(gen);
            write(dut, DATA_64_BITS, addr * 8, value);
            values[addr] = value;
        }
    }

    // Reading back the values.
    for (size_t i = 0; i <= max_addr; i++) {
        const uint64_t value = read(dut, DATA_64_BITS, i * 8);
        assert(value == values[i]);
    }
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

    assert(!dut->enabled_o);
    while (!dut->enabled_o) pulse(dut);
    while (!dut->data_ready_o) pulse(dut);

    write_read(dut);
    write_read_eject(dut);
    mixed_size_write_read(dut);
    mixed_size_read(dut);
    mixed_size_read_on_load(dut);

    ordered_read_writes(dut);
    rand_read_writes(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
