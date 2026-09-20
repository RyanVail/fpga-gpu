`ifndef ALU_SVH
`define ALU_SVH

`include "dcache.svh"

`define INST_WIDTH 32
`define REG_INDEX_WIDTH 5

// The width of a register
`define REG_WIDTH 32

// The number of registers.
// The last register is always a constant zero register.
// The second to last register is the stack pointer register.
`define NUM_REGS 32

// The stack pointer and constant zero register don't get shifted.
`define NON_SHIFT_REGS 2

// The number of registers that can be saved.
`define NUM_SAVED 8

// The immediate value that loads in the flags register.
`define FLAG_IMM_VALUE 31

`define SAVED_INDEX_WIDTH $clog2(`NUM_SAVED)

`define ALU_OP_WIDTH 4
typedef enum logic [`ALU_OP_WIDTH-1:0] {
    ALU_OP_ADD = 4'b0000,
    ALU_OP_SUB = 4'b0001,
    ALU_OP_MUL = 4'b0010,
    ALU_OP_RCP = 4'b0011,
    ALU_OP_CLAMP = 4'b0100,
    ALU_OP_CONST = 4'b0101,
    ALU_OP_BRANCH = 4'b0110,
    ALU_OP_MEM_READ = 4'b0111,
    ALU_OP_MEM_WRITE = 4'b1000,
    ALU_OP_IADD = 4'b1001,
    ALU_OP_ISUB = 4'b1010,
    ALU_OP_IMUL = 4'b1011,
    ALU_OP_SAVE = 4'b1100,
    ALU_OP_MOVE_STACK = 4'b1101,

    ALU_OP_INTERRUPT = 4'b1111
} alu_op_e;

`define ALU_SHIFT_WIDTH 1
typedef enum logic {
    ALU_SHIFT_LT = 0,
    ALU_SHIFT_RT = 1
} alu_shift_e;

// TODO: Add more conditions.
`define ALU_COND_WIDTH 2
typedef enum logic [`ALU_COND_WIDTH-1:0] {
    ALU_COND_ALWAYS = 0,
    ALU_COND_NEZ = 1,
    ALU_COND_EQZ = 2,
    ALU_COND_NEG = 3
} alu_cond_e;

typedef struct packed {
    logic neg;
    logic zero;
} alu_flags_s;

typedef struct packed {
    logic keep_regs;
    alu_cond_e cond;
    alu_op_e op;
    union packed {
        struct packed {
            logic [`REG_INDEX_WIDTH-1:0] reg_0;
            logic [`REG_INDEX_WIDTH-1:0] reg_1;
            logic [`REG_INDEX_WIDTH-1:0] reg_2;

            logic is_signed;
            logic set_flags;

            // Load an immediate value in place of `reg_1`.
            logic immediate;

            // The bitwise shift to apply to the intermediate result.
            alu_shift_e i_shift;
            logic [5:0] i_shift_bits;
        } triple;

        struct packed {
            logic [`REG_INDEX_WIDTH-1:0] reg_0;
            logic [`REG_INDEX_WIDTH-1:0] reg_1;

            // The bitwise shift to apply to `reg_1`.
            alu_shift_e shift;
            logic [4:0] shift_bits;

            logic set_flags;

            // Load an immediate value in place of `reg_1`.
            logic immediate;

            // The bitwise shift to apply to the intermediate result.
            alu_shift_e i_shift;
            logic [5:0] i_shift_bits;
        } dual;

        struct packed {
            // If this is a backwards branch.
            logic negative;

            // The offset of the branch in instructions.
            logic [23:0] offset;
        } branch;

        struct packed {
            logic [`REG_INDEX_WIDTH-1:0] addr;
            logic [`REG_INDEX_WIDTH-1:0] _0;

            // The size of the operation to perform.
            dcache_data_size_e size;

            // If the offset should be subtracted from the address.
            logic negative;
            logic [11:0] offset;
        } read;

        struct packed {
            logic [`REG_INDEX_WIDTH-1:0] addr;
            logic [`REG_INDEX_WIDTH-1:0] source;

            // The size of the operation to perform.
            dcache_data_size_e size;

            // If the offset should be subtracted from the address.
            logic negative;
            logic [11:0] offset;
        } write;

        struct packed {
            logic [`SAVED_INDEX_WIDTH-1:0] dest;
            logic [1:0] _0;
            logic [`REG_INDEX_WIDTH-1:0] src;

            // The bitwise shift to apply to `src` before being saved.
            alu_shift_e shift;
            logic [4:0] shift_bits;

            logic _1;

            // Load an immediate value in place of `src`.
            logic immediate;

            logic [6:0] _2;
        } save;

        struct packed {
            logic [11:0] _0;

            // If the offset should be subtracted from the stack.
            logic negative;
            logic [11:0] offset;
        } move_stack;

        logic [24:0] immediate;
    } data;
} alu_inst_s;

`endif
