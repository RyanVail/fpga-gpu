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
    dut->inst_i = nop();

    dut->reset_i = 1;
    pulse(dut);
    dut->reset_i = 0;

    assert(!dut->w_valid_o);
    assert(dut->pc_o == 0);
    assert(!dut->iupt_o);
}

static void exec(DUT* dut, Inst inst) {
    dut->inst_i = inst;
    pulse(dut);
}

#define assert_reg(dut, reg, expected) ({ \
    exec(dut, iupt(reg)); \
    assert(dut->iupt_o); \
    assert(dut->iupt_arg_o == expected); \
})

#define assert_flag(dut, flag, expected) assert( \
    (bool)(dut->flags_o & flag) == expected \
)

#define assert_pc(dut, expected) ({ \
    const Inst old = dut->inst_i; \
    dut->inst_i = nop(); \
    dut->eval(); \
    assert(dut->pc_o == (expected) + 1); \
    dut->inst_i = old; \
    dut->eval(); \
})

static void load_and_iupt(DUT* dut) {
    reset(dut);

    exec(dut, load(26));
    exec(dut, iupt(Reg::R0));

    for (uint32_t i = 0; i < 8; i++) {
        assert(dut->iupt_o);
        assert(dut->iupt_arg_o == 26);
        assert_pc(dut, 1);
    }

    exec(dut, load(2));
    assert(!dut->iupt_o);
    assert_pc(dut, 2);
}

static void cond_iupt(DUT* dut) {
    reset(dut);

    exec(dut, load(64820));
    exec(dut, dual(Op::ADD, Reg::R0, Reg::ZERO, true));
    exec(dut, iupt(Cond::EQZ, Reg::R0));
    assert(!dut->iupt_o);
    assert_pc(dut, 3);

    exec(dut, load(0));
    exec(dut, dual(Op::ADD, Reg::ZERO, Reg::R0, true));
    exec(dut, iupt(Cond::EQZ, Reg::R2));
    for (uint32_t i = 0; i < 3; i++) {
        assert(dut->iupt_o);
        assert(dut->iupt_arg_o == 64820);
        assert_pc(dut, 5);
    }
}

static void eqz_flag(DUT* dut) {
    reset(dut);
    assert_flag(dut, Flag::Z, false);

    exec(dut, load(10));
    exec(dut, load(10));
    assert_flag(dut, Flag::Z, false);

    // (R0 + R1) -> 10 + 10
    exec(dut, dual(Op::ADD, Reg::R0, Reg::R1, true));
    assert_flag(dut, Flag::Z, false);

    // (R0 - (R1 << 1)) -> (20 - 20) = 0
    exec(dut, dual(
        Op::SUB,
        Reg::R0, Reg::R1,
        Shift(false, 1),
        true
    ));
    assert_flag(dut, Flag::Z, true);
}

static void neg_flag(DUT* dut) {
    reset(dut);
    assert_flag(dut, Flag::N, false);

    exec(dut, load(10));
    assert_flag(dut, Flag::N, false);

    exec(dut, neg(Reg::R0, true));
    assert_flag(dut, Flag::N, true);

    exec(dut, neg(Reg::R0, true));
    assert_flag(dut, Flag::N, false);

    exec(dut, neg(Reg::R0, true));
    assert_flag(dut, Flag::N, true);

    exec(dut, dual(Op::ADD, Reg::R0, Reg::ZERO, true));
    assert_flag(dut, Flag::N, true);

    exec(dut, dual(Op::ADD, Reg::R0, Reg::ZERO, true, Shift(true, 32)));
    assert_flag(dut, Flag::N, false);
}

static void cond_branch(DUT* dut) {
    reset(dut);

    exec(dut, dual(Op::ADD, Reg::ZERO, Reg::ZERO, true));
    exec(dut, branch(Cond::EQZ, 100));
    assert_pc(dut, 1 + 100);

    exec(dut, load(10));
    exec(dut, dual(Op::ADD, Reg::ZERO, Reg::R0, true));
    assert_pc(dut, 1 + 100 + 2);

    exec(dut, branch(Cond::EQZ, 20, true));
    assert_pc(dut, 1 + 100 + 3);

    exec(dut, branch(Cond::NEZ, 20, true));
    assert_pc(dut, 1 + 100 + 3 - 20);
}

static void cond_load(DUT* dut) {
    reset(dut);
    exec(dut, load(5));
    exec(dut, load(613, Cond::EQZ));
    assert_reg(dut, Reg::R0, 5);
}

static void mul_high(DUT* dut) {
    reset(dut);

    const uint32_t value = 0xEC6C09;
    exec(dut, load(value));
    exec(dut, dual(
        Op::MUL,
        Reg::R0, Reg::R0,
        Cond::ALWAYS,
        Shift(true, 32)
    ));

    const uint64_t expected = (uint64_t)value * (uint64_t)value;
    assert_reg(dut, Reg::R0, expected >> 32);
}

static void write_offset(DUT* dut) {
    reset(dut);

    const uint32_t addr = 123;
    const uint32_t value = 0x6E8891;
    exec(dut, load(addr));
    exec(dut, load(value));

    const uint32_t offset = 500;
    exec(dut, write(Reg::R1, Reg::R0, offset));

    assert(dut->w_valid_o);
    assert(dut->w_addr_o == addr + offset);
    assert(dut->w_write_o == value); 
}

static void cond_write(DUT* dut) {
    reset(dut);

    exec(dut, load(3));
    exec(dut, write(Cond::EQZ, Reg::R1, Reg::ZERO, 0));
    assert(!dut->w_valid_o);
}

static void add_no_reg_shift(DUT* dut) {
    reset(dut);

    const size_t len = 5;
    const uint32_t values[len] = { 0xEF9, 0xA2FD, 0x16B2, 0x18F, 0xC2A7 };
    for (size_t i = 0; i < len; i++) {
        exec(dut, load(values[i]));
    }

    exec(dut, dual(
        Op::ADD,
        static_cast<Reg>(len - 1),
        Reg::ZERO,
        Cond::ALWAYS,
        Shift(),
        false
    ));

    assert_reg(dut, static_cast<Reg>(len - 1), values[0]);
}

static void add_imm_shift(DUT* dut) {
    reset(dut);
    exec(dut, dual(Op::ADD, Reg::ZERO, Imm::ONE, Shift(false, 4)));
    assert_reg(dut, Reg::R0, 1 << 4);
}

static void add_reg_shift(DUT* dut) {
    reset(dut);
    exec(dut, load(53));
    exec(dut, load(26032));
    exec(dut, dual(Op::ADD, Reg::R1, Reg::R0, Shift(true, 3)));
    assert_reg(dut, Reg::R0, 53 + (26032 >> 3));
}

static void neg_mul_shift(DUT* dut) {
    reset(dut);
    exec(dut, load(20));
    exec(dut, neg(Reg::R0, true));
    exec(dut, load(10));
    exec(dut, dual(Op::IMUL, Reg::R0, Reg::R1, true, Shift(true, 3)));
    assert_reg(dut, Reg::R0, -25);
}

static void mul_shift(DUT* dut) {
    reset(dut);
    exec(dut, load(234));
    exec(dut, load(104));
    exec(dut, dual(
        Op::MUL,
        Reg::R0, Reg::R1,
        Cond::ALWAYS,
        Shift(true, 3)
    ));

    assert_reg(dut, Reg::R0, 3042);
}

static void cond_add(DUT* dut) {
    reset(dut);
    exec(dut, load(234));
    exec(dut, load(104));
    exec(dut, dual(Op::ADD, Reg::R0, Reg::R1, Cond::EQZ));
    assert_reg(dut, Reg::R0, 104);
}

static void clamp_unsigned_min(DUT* dut) {
    reset(dut);
    exec(dut, load(500));
    exec(dut, load(250));
    exec(dut, load(265));
    exec(dut, clamp(Reg::R2, Reg::R1, Reg::R0));
    assert_reg(dut, Reg::R0, 265);
}

static void clamp_unsigned_max(DUT* dut) {
    reset(dut);
    exec(dut, load(2000));
    exec(dut, load(0));
    exec(dut, load(600));
    exec(dut, clamp(Reg::R2, Reg::R1, Reg::R0));
    assert_reg(dut, Reg::R0, 600);
}

static void clamp_unsigned_mid(DUT* dut) {
    reset(dut);
    exec(dut, load(600));
    exec(dut, load(0));
    exec(dut, load(2000));
    exec(dut, clamp(Reg::R2, Reg::R1, Reg::R0));
    assert_reg(dut, Reg::R0, 600);
}

static void clamp_signed_min(DUT* dut) {
    reset(dut);
    exec(dut, load(999));
    exec(dut, neg(Reg::R0));
    exec(dut, load(20));
    exec(dut, neg(Reg::R0));
    exec(dut, clamp(Reg::R2, Reg::R0, Reg::R1));
    assert_reg(dut, Reg::R0, -20);
}

static void bnot(DUT* dut) {
    const size_t len = 8;
    const uint32_t values[len] = { 10000, 10, 50, 4, 3, 2, 1, 0 };
    for (size_t i = 0; i < len; i++) {
        reset(dut);
        exec(dut, load(values[i]));
        exec(dut, bnot(Reg::R0));
        assert_reg(dut, Reg::R0, !values[i]);
    }
}

static void add_imm_one(DUT* dut) {
    reset(dut);
    exec(dut, load(99));
    exec(dut, dual(Op::ADD, Reg::R0, Imm::ONE));
    assert_reg(dut, Reg::R0, 100);
}

static void pi_imm(DUT* dut) {
    reset(dut);
    exec(dut, dual(
        Op::ADD,
        Reg::ZERO,
        Imm::PI,
        Cond::ALWAYS,
        Shift(true, 32)
    ));

    // Q (2.30) pi
    const uint32_t pi = 0xC90FDAA2;
    assert_reg(dut, Reg::R0, pi);
}

static void one_over_two_pi_imm(DUT* dut) {
    reset(dut);
    exec(dut, load(150));
    exec(dut, dual(
        Op::MUL,
        Reg::R0,
        Imm::ONE_OVER_TWO_PI,
        Cond::ALWAYS,
        Shift(true, 32)
    ));

    // ((150 / (2 * pi)) % 1) * (2^32)
    const uint32_t expected = 0xDF8CC0A8;
    assert_reg(dut, Reg::R0, expected);
}

static void save_and_load(DUT* dut) {
    reset(dut);
    exec(dut, load(100));
    exec(dut, save(Saved::S0, Reg::R0));

    exec(dut, load(603));
    exec(dut, save(Saved::S1, Reg::R0, Shift(false, 1)));

    // Loading back the registers.
    exec(dut, load(Saved::S1));
    exec(dut, load(Saved::S0, Cond::ALWAYS, Shift(false, 3)));
    assert_reg(dut, Reg::R1, 603 << 1);
    assert_reg(dut, Reg::R0, 100 << 3);
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
    cond_iupt(dut);
    eqz_flag(dut);
    neg_flag(dut);
    cond_branch(dut);
    cond_load(dut);
    mul_high(dut);
    write_offset(dut);
    cond_write(dut);
    add_no_reg_shift(dut);
    add_imm_shift(dut);
    add_reg_shift(dut);
    neg_mul_shift(dut);
    mul_shift(dut);
    cond_add(dut);
    clamp_unsigned_min(dut);
    clamp_unsigned_max(dut);
    clamp_unsigned_min(dut);
    clamp_signed_min(dut);
    bnot(dut);
    add_imm_one(dut);
    pi_imm(dut);
    one_over_two_pi_imm(dut);
    save_and_load(dut);

    if (dut->traceCapable) {
        pulse(dut);
        tfp->close();
    }

    delete dut;
    delete contextp;
    return 0;
}
