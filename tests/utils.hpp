#pragma once

#include <cstdint>
#include <cstdlib>
#include <iostream>

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

static uint32_t* ns_ptr;
static DUT* tracing_dut;

static void start_trace(DUT* dut, uint32_t* ns) {
    tracing_dut = dut;
    ns_ptr = ns;

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

static void dump_trace() {
    if (tracing_dut->traceCapable) {
        tfp->dump(*ns_ptr);
    }
}

static void stop_trace() {
    if (tracing_dut->traceCapable) {
        tfp->close();
    }
}

#define assert_eql(expected, value) assert_eql_inner( \
    __FILE__, \
    __LINE__, \
    (expected), \
    (value) \
)

static void assert_eql_inner(
    const char* file,
    uint32_t line,
    auto expected,
    auto value
) {
    if (value == expected) {
        return;
    }

    std::cerr << "assert ("
        << file << ":" << line
        << ") failed. Expected: " << expected
        << ", found: " << value
        << std::endl;

    dump_trace();
    stop_trace();
    exit(EXIT_FAILURE);
}
