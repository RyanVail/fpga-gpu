//`include "rcp.sv"

`define INST_WIDTH 32
`define REG_INDEX_WIDTH 5

// The width of a register
`define REG_WIDTH 32

// The number of registers.
// The last register is always a constant zero register.
`define NUM_REGS 32

`define ALU_OP_WIDTH 4
typedef enum logic [`ALU_OP_WIDTH-1:0] {
    ALU_OP_ADD = 4'b0000,
    ALU_OP_SUB = 4'b0001,
    ALU_OP_MUL = 4'b0010,
    ALU_OP_RCP = 4'b0011,
    ALU_OP_CLAMP = 4'b0100,
    ALU_OP_LOAD = 4'b0101,
    ALU_OP_BRANCH = 4'b0110,
    ALU_OP_MEM_WRITE = 4'b0111,
    ALU_OP_IADD = 4'b1000,
    ALU_OP_ISUB = 4'b1001,
    ALU_OP_IMUL = 4'b1010
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
} alu_flags;

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
            logic [`REG_INDEX_WIDTH-1:0] source;

            // If the offset should be subtracted from the address.
            logic negative;
            logic [13:0] offset;
        } write;

        logic [24:0] immediate;
    } data;
} alu_inst_s;

module alu #(
    // The width of the program counter register.
    parameter pc_width = 10,

    // The width of a memory address.
    parameter mem_addr_width = 16,

    parameter [`NUM_REGS-1:0][`REG_WIDTH*2-1:0] immediates = '{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0,

        64'hC90FDAA22168C235, // (Q 2.62) pi
        64'h28BE60DB9391054B, // (Q 0.64) 1 / (2 * pi)
        64'hB504F333F9DE6484, // (Q 1.63) sqrt(2)
        64'hFFFFFFFFFFFFFFFF, // -1
        64'h0000000000000001  //  1
    }

    // TODO: Add RCP.
    // The bit precision of the reciprocal instruction.
    //parameter rcp_width = 16,

    // The number of iterations of Newton's method to use for the reciprocal
    // instruction.
    //parameter rcp_iters = 3
) (
    input clk_i,
    input reset_i,

    input [`INST_WIDTH-1:0] inst_i,

    output logic [pc_width-1:0] pc,

    // TODO: This is just used to get output from the alu during tests right
    // now actually implement it.
    output logic w_valid_o,
    output logic [mem_addr_width-1:0] w_addr,
    output logic [width-1:0] w_write,

    output alu_flags flags
);
    // The width of a register.
    localparam width = `REG_WIDTH;

    wire alu_inst_s inst = alu_inst_s'(inst_i);
    wire alu_op_e op = inst.op;

    localparam [`REG_INDEX_WIDTH-1:0] zero_reg = `REG_INDEX_WIDTH'(
        `NUM_REGS - 1
    );

    wire [width-1:0] reg_value_0 = (inst.data.triple.reg_0 == zero_reg)
        ? 0 : regs[inst.data.triple.reg_0];

    wire [width-1:0] reg_value_1 = (inst.data.triple.reg_1 == zero_reg)
        ? 0 : regs[inst.data.triple.reg_1];

    wire [width-1:0] reg_value_2 = (inst.data.triple.reg_2 == zero_reg)
        ? 0 : regs[inst.data.triple.reg_2];

    logic [`NUM_REGS-2:0][width-1:0] regs;

    // The width of intermediate values.
    localparam i_width = width * 2;

    // TODO: Maybe the highest bits of the i_result should be saved and wired
    // into one of the immediates. That way a single calculation can give
    // optionally a full 64 bit result.
    // The intermediate result of the calculation.
    logic [i_width-1:0] i_result;

    // If the instruction takes two values as arguments.
    logic is_dual;
    always_comb begin
        casez (op)
            ALU_OP_LOAD,
            ALU_OP_BRANCH,
            ALU_OP_MEM_WRITE,
            ALU_OP_CLAMP: begin
                is_dual = 0;
            end default: begin
                is_dual = 1;
            end
        endcase
    end

    // If the instruction takes three values as arguments.
    wire is_triple = (op == ALU_OP_CLAMP);

    // The shifted intermediate value.
    wire [i_width-1:0] i_shifted = (inst.data.triple.i_shift == ALU_SHIFT_LT) 
        ? i_result <<< inst.data.triple.i_shift_bits
        : i_result >>> inst.data.triple.i_shift_bits;

    // Only execute instructions when their conditions are met.
    logic exec;
    always_comb begin
        casez (inst.cond)
            ALU_COND_ALWAYS: exec = 1;
            ALU_COND_NEZ: exec = !flags.zero;
            ALU_COND_EQZ: exec = flags.zero;
            ALU_COND_NEG: exec = flags.neg;
            default: exec = 1;
        endcase

        if (op == ALU_OP_MEM_WRITE && w_valid_o) begin
            exec = 0;
        end
    end

    always @(posedge clk_i) begin
        if (reset_i) begin
            w_valid_o <= 0;
            w_addr <= 'X;
            w_write <= 'X;
        end else if (op == ALU_OP_MEM_WRITE) begin
            w_valid_o <= 1;

            w_write <= reg_value_1;
            if (inst.data.write.negative) begin
                w_addr <= mem_addr_width'(reg_value_0)
                    - mem_addr_width'(inst.data.write.offset);
            end else begin
                w_addr <= mem_addr_width'(reg_value_0)
                    + mem_addr_width'(inst.data.write.offset);
            end
        end else begin
            w_valid_o <= w_valid_o;
            w_addr <= w_addr;
            w_write <= w_write;
        end
    end

    wire set_flags = inst.data.dual.set_flags;

    always @(posedge clk_i) begin
        if (reset_i) begin
            flags <= 0;
            regs[0] <= 0;
        end else if (!exec) begin
            flags <= flags;
            regs[0] <= regs[0];
        end else if (is_dual) begin
            if (set_flags) begin
                flags.zero <= width'(i_shifted) == 0;
                flags.neg <= i_shifted[width-1];
            end else begin
                flags <= flags;
            end

            regs[0] <= width'(i_shifted);
        end else begin
            flags <= flags;
            regs[0] <= width'(i_result);
        end
    end

    // If the intermediate values should be signed extended.
    logic is_signed;
    always_comb begin
        if (is_triple) begin
            is_signed = inst.data.triple.is_signed;
        end else begin
            casez (op)
                ALU_OP_IADD: is_signed = 1;
                ALU_OP_ISUB: is_signed = 1;
                ALU_OP_IMUL: is_signed = 1;
                default: is_signed = 0;
            endcase
        end
    end

    wire [i_width-1:0] i_value_0 = {
        {width{is_signed & reg_value_0[width-1]}},
        reg_value_0[width-1:0]
    };

    logic [i_width-1:0] i_src_value_1;
    always_comb begin
        if (inst.data.triple.immediate) begin
            i_src_value_1 = immediates[inst.data.dual.reg_1];
        end else begin
            i_src_value_1 = {
                {width{is_signed & reg_value_1[width-1]}},
                reg_value_1[width-1:0]
            };
        end
    end

    logic [i_width-1:0] i_value_1;
    always_comb begin
        if (is_dual) begin
            if (inst.data.dual.shift == ALU_SHIFT_LT) begin
                i_value_1 = i_src_value_1 <<< inst.data.dual.shift_bits;
            end else begin
                i_value_1 = i_src_value_1 >>> inst.data.dual.shift_bits;
            end
        end else begin
            i_value_1 = i_src_value_1;
        end
    end

    wire [i_width-1:0] i_value_2 = {
        {width{is_signed & reg_value_2[width-1]}},
        reg_value_2[width-1:0]
    };

    always_comb begin
        casez (op)
            ALU_OP_ADD, ALU_OP_IADD: begin
                i_result = i_value_0 + i_value_1;
            end ALU_OP_SUB, ALU_OP_ISUB: begin
                i_result = i_value_0 - i_value_1;
            end ALU_OP_MUL, ALU_OP_IMUL: begin
                i_result = i_value_0 * i_value_1;
            end ALU_OP_RCP: begin
                // TODO: Finish.
                i_result = i_width'(regs[`NUM_REGS-2]);
            end ALU_OP_CLAMP: begin
                if (is_signed) begin
                    if (signed'(i_value_1) > signed'(i_value_0)) begin
                        i_result = i_value_1;
                    end else if (signed'(i_value_2) < signed'(i_value_0)) begin
                        i_result = i_value_2;
                    end else begin
                        i_result = i_value_0;
                    end
                end else begin
                    if (i_value_1 > i_value_0) begin
                        i_result = i_value_1;
                    end else if (i_value_2 < i_value_0) begin
                        i_result = i_value_2;
                    end else begin
                        i_result = i_value_0;
                    end
                end
            end

            ALU_OP_LOAD: begin
                i_result = i_width'(inst.data.immediate);
            end

            ALU_OP_BRANCH: begin
                i_result = i_width'(regs[0]);
            end

            ALU_OP_MEM_WRITE: begin
                i_result = i_width'(regs[`NUM_REGS-2]);
            end

            default begin
                // TODO: Real handler.
                $fatal("Invalid Instruction");
                i_result = 'X;
            end
        endcase
    end

    // Shifting the regs.
    always @(posedge clk_i) begin
        regs[`NUM_REGS-2:1] <= reset_i ? 0
            : (inst.keep_regs || !exec)
                ? regs[`NUM_REGS-2:1]
                : regs[`NUM_REGS-3:0];
    end

    wire branching = (op == ALU_OP_BRANCH) && exec;

    always @(posedge clk_i) begin
        if (reset_i) begin
            pc <= 0;
        end else if (branching) begin
            if (inst.data.branch.negative) begin
                pc <= pc - pc_width'(inst.data.branch.offset);
            end else begin
                pc <= pc + pc_width'(inst.data.branch.offset);
            end
        end else begin
            pc <= pc + 1;
        end
    end
endmodule
