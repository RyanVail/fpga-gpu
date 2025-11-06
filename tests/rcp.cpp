#define DUT Vrcp

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Vrcp.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <cassert>
#include <cstdint>
#include <random>

static uint32_t ns = 0;
static VerilatedFstC* tfp;

static constexpr uint32_t addr_width = 16;
static constexpr uint32_t line_width = 64;
static constexpr uint32_t depth = 64;

static constexpr uint64_t one = 65535;

// Max delta in units of one.
static constexpr uint64_t max_delta = 5;

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

static constexpr uint32_t test_values[] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18,
    19, 20, 21, 22, 23, 24, 25, 26,
    27, 28, 29, 30, 31, 32, 33, 34,
    50,
    100,
    500,
    3200,
    8192,
    10000,
    16384,
    24000,
    32767,
};

// Tests the deltas of test_values.
static void deltas(DUT* dut) {
    for (size_t i = 0; i < sizeof(test_values) / sizeof(test_values[0]); i++) {
        dut->v_i = 1;
        dut->a_i = test_values[i];

        pulse(dut);
        dut->v_i = 0;

        assert(dut->ready_o);

        const uint64_t expected = one / dut->a_i;
        assert(abs(expected - dut->r_o) <= max_delta);
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

    deltas(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
