#define DUT Vctrl_unit

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Vctrl_unit.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include "inst.hpp"
#include <cassert>
#include <cstdint>

using namespace inst;

static uint32_t ns = 0;
static VerilatedFstC* tfp;

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

static void reset(DUT* dut) {
    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;
}

static void load_inst(DUT* dut, Inst inst) {
    dut->load_i = 1;
    dut->load_inst_i = inst;
    pulse(dut);
    dut->load_i = 0;
}

// Runs a program until in interrupt is raised in which case the interrupt arg
// is returned.
#define run(dut, program) run_intern( \
    (dut), \
    (program), \
    sizeof(program) / sizeof((program)[0]) \
)

static uint32_t run_intern(DUT* dut, const Inst* program, size_t len) {
    reset(dut);

    dut->load_i = 1;
    for (size_t i = 0; i < len; i++) {
        dut->load_inst_i = program[i];
        pulse(dut);
    }
    dut->load_i = 0;

    while (!dut->iupt_o) pulse(dut);
    return dut->iupt_arg_o;
}

static void load_and_iupt(DUT* dut) {
    load_inst(dut, load(294));
    load_inst(dut, load(406));
    load_inst(dut, load(738));
    load_inst(dut, load(2500));
    load_inst(dut, load(6024));
    load_inst(dut, load(406));
    load_inst(dut, iupt(Reg::R5));

    for (uint32_t i = 0; i < 6; i++) {
        assert(!dut->iupt_o);
        pulse(dut);
    }

    pulse(dut);
    assert(dut->iupt_o);
    assert(dut->iupt_arg_o == 294);
}

static void simple_add(DUT* dut) {
    const Inst program[] = {
        load(294),
        load(6),
        dual(Op::ADD, Reg::R0, Reg::R1, false),
        iupt(Reg::R0),
    };

    assert(run(dut, program) == 294 + 6);
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

    load_and_iupt(dut);
    simple_add(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
