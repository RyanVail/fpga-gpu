const std = @import("std");
const fpga_gpu = @import("fpga_gpu");
const glsl = @import("glsl.zig");
const ir = @import("ir.zig");

test {
    _ = glsl.parser;
    _ = glsl.type;
    _ = glsl.Token;
    _ = glsl.Tokenizer;
    _ = glsl.operator;
    _ = glsl.Scope;
    _ = glsl.Expr;
    _ = glsl.Func;
    _ = glsl.@"var";
    _ = ir;
    _ = ir.operation;
    _ = ir.Block;
    _ = ir.Value;
    _ = ir.Range;
    _ = ir.Pipeline;

    std.testing.refAllDecls(@This());
}

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
