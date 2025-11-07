#define DUT Vmem_ctrl_IS42S16160G_7TL

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Vmem_ctrl_IS42S16160G_7TL.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <cassert>
#include <cstdint>
#include <random>

static uint32_t ns = 0;
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
}

static void write_read(DUT* dut) {
    init(dut);

    dut->addr_i = 0;
    dut->r_valid_i = 0;
    dut->w_valid_i = 0;

    pulse(dut);

    assert(dut->data_ready_o);
    assert(!dut->r_valid_o);
    dut->w_valid_i = 1;
    dut->write_i = 0x42C07E72A7229C12;
    dut->addr_i = 0;

    pulse(dut);

    assert(!dut->data_ready_o);
    dut->w_valid_i = 0;
    dut->addr_i = 0;

    while (!dut->data_ready_o) pulse(dut);
    dut->r_valid_i = 1;

    pulse(dut);
    assert(!dut->data_ready_o);
    dut->r_valid_i = 0;

    while (!dut->r_valid_o) pulse(dut);
    assert(dut->read_o == 0x42C07E72A7229C12);

    while (!dut->data_ready_o) pulse(dut);

    dut->w_valid_i = 1;
    dut->write_i = 0xA5162A2A539D0FCB;
    dut->addr_i = 64;

    pulse(dut);
    assert(!dut->data_ready_o);
    dut->w_valid_i = 0;

    while (!dut->data_ready_o) pulse(dut);
    dut->addr_i = 0;
    dut->r_valid_i = 1;

    pulse(dut);
    assert(!dut->data_ready_o);
    dut->r_valid_i = 0;

    while (!dut->r_valid_o) pulse(dut);
    assert(dut->read_o == 0x42C07E72A7229C12);

    while (!dut->data_ready_o) pulse(dut);
    dut->addr_i = 64;
    dut->r_valid_i = 1;

    pulse(dut);
    assert(!dut->data_ready_o);
    dut->r_valid_i = 0;

    while (!dut->r_valid_o) pulse(dut);
    assert(dut->read_o == 0xA5162A2A539D0FCB);
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

        dut->w_valid_i = 1;

        values[i] = value;
        dut->addr_i = i * 8;
        dut->write_i = value;

        pulse(dut);
        dut->w_valid_i = 0;

        while (!dut->data_ready_o) pulse(dut);
    }

    dut->w_valid_i = 0;

    // Randomly reading or writing.
    for (size_t i = 0; i < iterations; i++) {
        const size_t addr = addr_dist(gen);
        const uint8_t rw = rw_dist(gen);

        // Reading.
        if (rw == 0) {
            dut->addr_i = addr * 8;
            dut->r_valid_i = 1;

            pulse(dut);
            dut->r_valid_i = 0;

            while (!dut->r_valid_o) pulse(dut);
            assert(dut->read_o == values[addr]);
        }

        // Writing.
        if (rw == 1) {
            const uint64_t value = value_dist(gen);
            values[addr] = value;

            dut->w_valid_i = 1;
            dut->addr_i = addr * 8;
            dut->write_i = value;

            pulse(dut);
            dut->w_valid_i = 0;
        }

        while (!dut->data_ready_o) pulse(dut);
    }

    dut->w_valid_i = 0;

    // Reading back the values.
    for (size_t i = 0; i <= max_addr; i++) {
        dut->addr_i = i * 8;
        dut->r_valid_i = 1;

        pulse(dut);
        dut->r_valid_i = 0;

        while (!dut->r_valid_o) pulse(dut);
        assert(dut->read_o == values[i]);

        while (!dut->data_ready_o) pulse(dut);
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
    rand_read_writes(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
