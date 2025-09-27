#define DUT Vsdram_IS42S16160G_7TL

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Vsdram_IS42S16160G_7TL.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <cassert>
#include <cstdint>

typedef DUT Vsdram;

static uint32_t ns = 0;
static VerilatedFstC* tfp;

constexpr uint32_t init_delay_cycles = (uint32_t)(100000 / 7.5);

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

void write_read(Vsdram* dut) {
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

    while (dut->data_ready_o == 0) {
        pulse(dut);
    }

    dut->r_valid_i = 1;

    while (dut->r_valid_o == 0) {
        pulse(dut);
    }

    assert(dut->read_o == 123);
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

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
