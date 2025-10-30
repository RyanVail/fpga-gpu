#include <cstdint>

namespace inst {

enum Op : uint8_t {
    ADD = 0b0000,
    SUB = 0b0001,
    MUL = 0b0010,
    RCP = 0b0011,
    LOAD = 0b0100,
    BRANCH = 0b0101,
    MEM_WRITE = 0b0110,
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

typedef uint32_t Inst;

typedef struct Shift {
    bool right;
    uint8_t bits;
} Shift;

static Inst triple(
    Op op,
    Reg a,
    Reg b,
    Reg c = Reg::ZERO,
    bool is_signed = false,
    bool set_flags = false,
    Shift shift = {
        .right = false,
        .bits = 0,
    },
    Cond cond = Cond::ALWAYS,
    bool shift_regs = true
) {
    return ((uint32_t)(!shift_regs) << 31)
        | ((uint32_t)cond << 29)
        | ((uint32_t)op << 25)
        | ((uint32_t)a << 20)
        | ((uint32_t)b << 15)
        | ((uint32_t)c << 10)
        | ((uint32_t)is_signed << 9)
        | ((uint32_t)set_flags << 8)
        | ((uint32_t)shift.right << 7)
        | ((uint32_t)shift.bits);
}

static Inst dual(
    Op op,
    Reg a,
    Reg b,
    bool is_signed,
    bool set_flags,
    Cond cond = Cond::ALWAYS
) {
    const Shift shift = { .right = false, .bits = 0 };
    return triple(op, a, b, Reg::ZERO, is_signed, set_flags, shift, cond);
}

static Inst dual(Op op, Reg a, Reg b, Cond cond = Cond::ALWAYS) {
    return dual(op, a, b, false, false, cond);
}

static Inst dual(Op op, Reg a, Reg b, Shift shift) {
    return triple(op, a, b, Reg::ZERO, false, false, shift);
}

static Inst neg(Reg a, bool is_signed, bool set_flags) {
    return dual(Op::SUB, Reg::ZERO, a, is_signed, set_flags);
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

}
