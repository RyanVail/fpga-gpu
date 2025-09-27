#define DUT Vsdram_IS42S16160G_7TL

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Vsdram_IS42S16160G_7TL.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <cassert>
#include <cstdint>
#include <random>

typedef DUT Vsdram;

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

static void write_read(Vsdram* dut) {
    init(dut);

    dut->addr_i = 0;
    dut->r_valid_i = 0;
    dut->w_valid_i = 0;

    pulse(dut);

    assert(dut->data_ready_o == 1);
    assert(dut->r_valid_o == 0);
    dut->w_valid_i = 1;
    dut->write_i = 123;
    dut->addr_i = 0;

    pulse(dut);

    assert(dut->data_ready_o == 0);
    dut->w_valid_i = 0;
    dut->addr_i = 0;

    while (dut->data_ready_o == 0) pulse(dut);
    dut->r_valid_i = 1;

    pulse(dut);
    assert(dut->data_ready_o == 0);
    dut->r_valid_i = 0;

    while (dut->r_valid_o == 0) pulse(dut);
    assert(dut->read_o == 123);

    while (!dut->data_ready_o) pulse(dut);
}

static void rand_writes(Vsdram* dut) {
    init(dut);

    constexpr uint16_t max_value = UINT16_MAX;
    constexpr size_t max_addr = 256;
    constexpr uint32_t iterations = max_addr * 2;

    // Creating the rng.
    std::mt19937 gen;
    std::uniform_int_distribution<uint16_t> value_dist(0, max_value);
    std::uniform_int_distribution<size_t> addr_dist(0, max_addr);

    dut->w_valid_i = 0;
    dut->r_valid_i = 0;
    pulse(dut);

    uint16_t values[max_addr + 1];

    // Initing the values.
    for (size_t i = 0; i < max_addr; i++) {
        const uint16_t value = value_dist(gen);

        dut->w_valid_i = 1;

        values[i] = value;
        dut->addr_i = i;
        dut->write_i = value;

        pulse(dut);
        dut->w_valid_i = 0;

        while (dut->data_ready_o == 0) pulse(dut);
    }

    dut->w_valid_i = 0;

    // Randomly writing.
    for (uint32_t i = 0; i < iterations; i++) {
        const size_t addr = addr_dist(gen);
        const uint16_t value = value_dist(gen);

        values[addr] = value;

        dut->w_valid_i = 1;
        dut->addr_i = addr;
        dut->write_i = value;

        pulse(dut);
        dut->w_valid_i = 0;

        while (dut->data_ready_o == 0) pulse(dut);
    }

    dut->w_valid_i = 0;

    // Reading back the values.
    for (size_t i = 0; i < max_addr; i++) {
        dut->addr_i = i;
        dut->r_valid_i = 1;

        pulse(dut);
        dut->r_valid_i = 0;

        while (!dut->r_valid_o) pulse(dut);
        assert(dut->read_o == values[i]);

        while (dut->data_ready_o == 0) pulse(dut);
    }
}

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vsdram* dut = new Vsdram{contextp};

    if (dut->traceCapable) {
        Verilated::traceEverOn(true);
        tfp = new VerilatedFstC;
        dut->trace(tfp, -1);
        tfp->open("build/waves/" STR(DUT) ".fst");
    }

    assert(dut->enabled_o == 0);
    while (dut->enabled_o == 0) pulse(dut);
    while (!dut->data_ready_o) pulse(dut);

    write_read(dut);
    rand_writes(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
