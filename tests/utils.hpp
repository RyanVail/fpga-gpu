#pragma once

#include <cassert>
#include <cstdint>

#define _STR(a) #a
#define STR(a) _STR(a)

#ifndef DUT
    #error "utils.hpp requires DUT to be defined"
#endif

#ifdef WAVE_FST
    #include "verilated_fst_c.h"
    static VerilatedFstC* tfp;
#elif defined(WAVE_VCD)
    #include "verilated_vcd_c.h"
    static VerilatedVcdC* tfp;
#endif

static void start_trace(DUT* dut) {
    if (!dut->traceCapable) {
        return;
    }

    Verilated::traceEverOn(true);

    #ifdef WAVE_FST
        tfp = new VerilatedFstC;
        dut->trace(tfp, -1);
        tfp->open("build/waves/" STR(DUT) ".fst");
    #elif defined(WAVE_VCD)
        tfp = new VerilatedVcdC;
        dut->trace(tfp, -1);
        tfp->open("build/waves/" STR(DUT) ".vcd");
    #endif
}

static void dump_trace(DUT* dut, uint32_t ns) {
    if (dut->traceCapable) {
        tfp->dump(ns);
    }
}

static void stop_trace(DUT* dut) {
    if (dut->traceCapable) {
        tfp->close();
    }
}
