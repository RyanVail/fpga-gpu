#define DUT Valu

#define _STR(a) #a
#define STR(a) _STR(a)

#include "Valu.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include "inst.hpp"
#include <cassert>
#include <cstdint>

using namespace inst;

static uint32_t ns = 0;
static VerilatedFstC* tfp;

static constexpr uint32_t addr_width = 16;
static constexpr uint32_t line_width = 64;
static constexpr uint32_t depth = 64;

static constexpr uint64_t one = 65536;

// Max delta in units of one.
static constexpr uint64_t max_delta = 1000;

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

static void eqz_flag(DUT* dut) {
    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;

    // TODO: Enum for this.
    const uint32_t zero_mask = 1;

    assert((dut->flags & zero_mask) == 0);

    dut->inst_i = load(10); pulse(dut);
    dut->inst_i = load(10); pulse(dut);
    assert((dut->flags & zero_mask) == 0);

    // (R0 + R1) -> 10 + 10
    dut->inst_i = dual(Op::ADD, Reg::R0, Reg::R1, false, true);
    pulse(dut);
    assert((dut->flags & zero_mask) == 0);

    // (R0 - R1 - R2) -> (20 - 10 - 10) = 0
    dut->inst_i = triple(Op::SUB, Reg::R0, Reg::R1, Reg::R2, false, true);
    pulse(dut);
    assert((dut->flags & zero_mask) != 0);
}

static void neg_flag(DUT* dut) {
    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;

    // TODO: Enum for this.
    const uint32_t neg_mask = 2;

    assert((dut->flags & neg_mask) == 0);

    dut->inst_i = load(10); pulse(dut);
    assert((dut->flags & neg_mask) == 0);

    dut->inst_i = neg(Reg::R0, false, true);
    pulse(dut);
    assert((dut->flags & neg_mask) != 0);

    dut->inst_i = neg(Reg::R0, false, true);
    pulse(dut);
    assert((dut->flags & neg_mask) == 0);

    dut->inst_i = neg(Reg::R0, false, true);
    pulse(dut);
    assert((dut->flags & neg_mask) != 0);

    Shift shift = { .right = true, .bits = 0 };
    dut->inst_i = triple(
        Op::ADD,
        Reg::R0, Reg::ZERO, Reg::ZERO,
        false, true,
        shift
    );
    pulse(dut);
    assert((dut->flags & neg_mask) != 0);

    shift.bits = 32;
    dut->inst_i = triple(
        Op::ADD,
        Reg::R0, Reg::ZERO, Reg::ZERO,
        false, true,
        shift
    );
    pulse(dut);
    assert((dut->flags & neg_mask) == 0);
}

static void cond_branch(DUT* dut) {
    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;

    assert(dut->pc == 0);

    dut->inst_i = dual(Op::ADD, Reg::ZERO, Reg::ZERO, false, true);
    pulse(dut);

    dut->inst_i = branch(Cond::EQZ, 100);
    pulse(dut);
    assert(dut->pc == 1 + 100);

    dut->inst_i = load(10);
    pulse(dut);

    dut->inst_i = dual(Op::ADD, Reg::ZERO, Reg::R0, false, true);
    pulse(dut);

    dut->inst_i = branch(Cond::EQZ, 20, true);
    pulse(dut);
    assert(dut->pc == 1 + 100 + 3);

    dut->inst_i = branch(Cond::NEZ, 20, true);
    pulse(dut);
    assert(dut->pc == 1 + 100 + 3 - 20);
}

static void fmadd(DUT* dut) {
    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;

    const uint32_t a = 0xA9C;
    const uint32_t b = 0x6;
    const uint32_t c = 0xFA6;

    dut->inst_i = load(a); pulse(dut);
    dut->inst_i = load(b); pulse(dut);
    dut->inst_i = load(c); pulse(dut);

    const Shift shift = { .right = true, .bits = 2 };
    dut->inst_i = triple(
        Op::MUL,
        Reg::R2, Reg::R1, Reg::R0,
        false, false,
        shift
    );
    pulse(dut);

    dut->inst_i = write(Reg::ZERO, Reg::R0);
    pulse(dut);

    const uint64_t expected = (uint64_t)a * (uint64_t)b + (uint64_t)c;
    assert(dut->w_valid_o);
    assert(dut->w_write == expected >> 2);
}

static void mul_high(DUT* dut) {
    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;

    const uint32_t value = 0xEC6C09;
    dut->inst_i = load(value);
    pulse(dut);

    const Shift shift = { .right = true, .bits = 32 };
    dut->inst_i = dual(Op::MUL, Reg::R0, Reg::R0, shift);
    pulse(dut);

    dut->inst_i = write(Reg::ZERO, Reg::R0);
    pulse(dut);

    const uint64_t expected = (uint64_t)value * (uint64_t)value;
    assert(dut->w_valid_o);
    assert(dut->w_write == expected >> 32);
}

static void write_offset(DUT* dut) {
    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;

    const uint32_t addr = 123;
    const uint32_t value = 0x6E8891;
    dut->inst_i = load(addr); pulse(dut);
    dut->inst_i = load(value); pulse(dut);

    const uint32_t offset = 500;
    dut->inst_i = write(Reg::R1, Reg::R0, offset);
    pulse(dut);

    assert(dut->w_valid_o);
    assert(dut->w_addr == addr + offset);
    assert(dut->w_write == value); 
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

    eqz_flag(dut);
    neg_flag(dut);
    cond_branch(dut);
    fmadd(dut);
    mul_high(dut);
    write_offset(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
