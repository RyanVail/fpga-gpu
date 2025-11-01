#include <cstdint>

namespace inst {

enum Flag : uint8_t {
    Z = 1, // Zero
    N = 2, // Negative
};

enum Op : uint8_t {
    ADD = 0b0000,
    SUB = 0b0001,
    MUL = 0b0010,
    RCP = 0b0011,
    CLAMP = 0b0100,
    LOAD = 0b0101,
    BRANCH = 0b0110,
    MEM_WRITE = 0b0111,
    IADD = 0b1000,
    ISUB = 0b1001,
    IMUL = 0b1010,

    INTERRUPT = 0b1111,
};

enum Cond : uint8_t {
    ALWAYS = 0,
    NEZ = 1,
    EQZ = 2,
    NEG = 3,
};

enum Reg : uint8_t {
    R0 = 0,
    R1 = 1,
    R2 = 2,
    R3 = 3,
    R4 = 4,
    R5 = 5,
    R6 = 6,
    R7 = 7,
    R8 = 8,
    R9 = 9,
    R10 = 10,
    R11 = 11,
    R12 = 12,
    R13 = 13,
    R14 = 14,
    R15 = 15,
    R16 = 16,
    R17 = 17,
    R18 = 18,
    R19 = 19,
    R20 = 20,
    R21 = 21,
    R22 = 22,
    R23 = 23,
    R24 = 24,
    R25 = 25,
    R26 = 26,
    R27 = 27,
    R28 = 28,
    R29 = 29,
    R30 = 30,

    ZERO = 31,
};

enum Imm : uint8_t {
    ONE = 0,
    NEG_ONE = 1,
    SQRT_2 = 2,
    ONE_OVER_TWO_PI = 3,
    PI = 4,
};

typedef uint32_t Inst;

typedef struct Shift {
    bool right;
    uint8_t bits;

    Shift(bool rl = false, uint8_t b = 0) : right(rl), bits(b) {}
} Shift;

static Inst dual_intern(
    Op op,
    Reg a,
    bool v1_immediate,
    uint8_t v1,
    Shift v1_shift = Shift(),
    bool set_flags = false,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    return ((uint32_t)(!shift_regs) << 31)
        | ((uint32_t)cond << 29)
        | ((uint32_t)op << 25)
        | ((uint32_t)a << 20)
        | ((uint32_t)v1 << 15)
        | ((uint32_t)v1_shift.right << 14)
        | ((uint32_t)v1_shift.bits << 9)
        | ((uint32_t)set_flags << 8)
        | ((uint32_t)v1_immediate << 7)
        | ((uint32_t)shift.right << 6)
        | ((uint32_t)shift.bits);
}

static Inst dual(
    Op op,
    Reg a,
    Reg b,
    Shift v1_shift = Shift(),
    bool set_flags = false,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    return dual_intern(
        op, a, false, b, v1_shift, set_flags, cond, shift, shift_regs
    );
}

static Inst dual(Op op, Reg a, Reg b, bool set_flags, Shift shift = Shift()) {
    return dual(op, a, b, Shift(), set_flags, Cond::ALWAYS, shift);
}

static Inst dual(
    Op op,
    Reg a,
    Reg b,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    return dual(op, a, b, Shift(), false, cond, shift, shift_regs);
}

static Inst dual(
    Op op,
    Reg a,
    Imm imm,
    Shift imm_shift = Shift(),
    bool set_flags = false,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    return dual_intern(
        op, a, true, imm, imm_shift, set_flags, cond, shift, shift_regs
    );
}

static Inst dual(Op op, Reg a, Imm b, bool set_flags, Shift shift = Shift()) {
    return dual(op, a, b, Shift(), set_flags, Cond::ALWAYS, shift);
}

static Inst neg(
    Reg a,
    bool set_flags = false,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    // TODO: Should be signed.
    return dual(
        Op::SUB, Reg::ZERO, a, Shift(), set_flags, cond, shift, shift_regs
    );
}

static Inst clamp_intern(
    Reg value,
    bool min_immediate,
    uint8_t min,
    Reg max,
    bool is_signed,
    bool set_flags,
    Cond cond,
    Shift shift,
    bool shift_regs
) {
    return ((uint32_t)(!shift_regs) << 31)
        | ((uint32_t)cond << 29)
        | ((uint32_t)Op::CLAMP << 25)
        | ((uint32_t)value << 20)
        | ((uint32_t)min << 15)
        | ((uint32_t)max << 10)
        | ((uint32_t)is_signed << 9)
        | ((uint32_t)set_flags << 8)
        | ((uint32_t)min_immediate << 7)
        | ((uint32_t)shift.right << 6)
        | ((uint32_t)shift.bits);
}

static Inst clamp(
    Reg value,
    Reg min,
    Reg max,
    bool is_signed = false,
    bool set_flags = false,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    return clamp_intern(
        value, false, min, max, is_signed, set_flags, cond, shift, shift_regs
    );
}

static Inst clamp(
    Reg value,
    Imm min,
    Reg max,
    bool is_signed = false,
    bool set_flags = false,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    return clamp_intern(
        value, true, min, max, is_signed, set_flags, cond, shift, shift_regs
    );
}

static Inst bnot(
    Reg a,
    bool set_flags = false,
    Cond cond = Cond::ALWAYS,
    Shift shift = Shift(),
    bool shift_regs = true
) {
    return clamp(
        a,
        Imm::ONE,
        Reg::ZERO,
        false,
        set_flags,
        cond,
        shift,
        shift_regs
    );
}

static Inst branch(
    Cond cond,
    uint32_t offset,
    bool negative = false,
    bool shift_regs = true
) {
    return ((uint32_t)(!shift_regs) << 31)
        | ((uint32_t)cond << 29)
        | ((uint32_t)inst::Op::BRANCH << 25)
        | ((uint32_t)negative << 24)
        | offset;
}

static Inst load (
    uint32_t immediate,
    Cond cond = Cond::ALWAYS,
    bool shift_regs = true
) {
    return ((uint32_t)(!shift_regs) << 31)
        | ((uint32_t)cond << 29)
        | ((uint32_t)inst::Op::LOAD << 25)
        | ((uint32_t)immediate);
}

static Inst write (
    Cond cond,
    Reg addr,
    Reg source,
    uint16_t offset,
    bool negative = false,
    bool shift_regs = true
) {
    return ((uint32_t)(!shift_regs) << 31)
        | ((uint32_t)cond << 29)
        | ((uint32_t)inst::Op::MEM_WRITE << 25)
        | ((uint32_t)addr << 20)
        | ((uint32_t)source << 15)
        | ((uint32_t)negative << 14)
        | offset;
}

static Inst write (
    Reg addr,
    Reg source,
    uint16_t offset = 0,
    bool negative = false,
    bool shift_regs = true
) {
    return write(Cond::ALWAYS, addr, source, offset, negative, shift_regs);
}

static Inst iupt(Cond cond, Reg reg, bool shift_regs = false) {
    return ((uint32_t)(!shift_regs) << 31)
        | ((uint32_t)cond << 29)
        | ((uint32_t)inst::Op::INTERRUPT << 25)
        | ((uint32_t)reg << 20);
}

static Inst iupt(Reg reg) {
    return iupt(Cond::ALWAYS, reg);
}

static Inst nop(bool shift_regs = false) {
    return dual(Op::ADD, Reg::ZERO, Reg::ZERO, Shift(), shift_regs);
}

}
