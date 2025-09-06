const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const parser = @import("../parser.zig");
const VarId = parser.@"var".Id;
const Scope = parser.Scope;
const Op = parser.Op;
const Tokenizer = parser.Tokenizer;
const ir = @import("../ir.zig");
const Val = ir.Val;
const InstWriter = ir.InstWriter;
const Weight = parser.operator.Weight;

const Tok = union(enum) {
    tok: parser.Token,
    val: Val.Id,
};

// TODO: This has to parse function calls and fields too.
pub fn parse(
    allocator: Allocator,
    iter: *Tokenizer,
    scope: *const Scope,
    writer: *InstWriter,
) !Val.Id {
    const toks = try collectToks(allocator, iter);
    defer allocator.free(toks);

    const result = try translate(allocator, iter, scope, toks, writer, true);
    return result.val;
}

const Translation = struct {
    /// The id of the final value after translation.
    val: Val.Id,

    /// The number of tokens that were translated.
    tokens: usize,
};

fn translate(
    allocator: Allocator,
    iter: *Tokenizer,
    scope: *const Scope,
    tokens: []Tok,
    writer: *InstWriter,
    base: bool,
) !Translation {
    var toks = tokens;

    var child_tokens: usize = 0;

    // Translating parenthesis.
    var i: usize = 0;
    while (i < toks.len) : (i += 1) {
        if (toks[i] == .tok and toks[i].tok.tag == .l_paren) {
            const result = try translate(
                allocator,
                iter,
                scope,
                toks[i + 1 ..],
                writer,
                false,
            );

            toks[i] = .{ .val = result.val };

            const len = result.tokens + 1;
            child_tokens += len;

            for (i + 1..toks.len - 2) |j| {
                toks[j] = toks[j + 2];
            }
            toks.len -= len;
        }
    }

    // Determining the number of tokens in this sub expression.
    var num_tokens: usize = toks.len;
    for (toks, 0..) |tok, j| {
        if (tok == .tok and tok.tok.tag == .r_paren) {
            num_tokens = j;
            break;
        }
    }

    var tokens_left: usize = num_tokens;

    // Translating operators in order of precedence.
    for (0..@intFromEnum(Weight.max) + 1) |weight| {
        i = 0;
        while (i < tokens_left) : (i += 1) {
            const tok = toks[i];
            if (tok != .tok) {
                continue;
            }

            const op = Op.read(tok.tok) orelse continue;
            if (op.getWeight() != @as(Weight, @enumFromInt(weight))) {
                continue;
            }

            if (op.appliesToDual() and i != 0 and i != toks.len - 1) {
                const a = try translateValue(allocator, iter, scope, toks[i - 1], writer);

                const b = try translateValue(allocator, iter, scope, toks[i + 1], writer);

                const id = try writer.write(
                    allocator,
                    .{ .expr = .initDual(op, a, b) },
                );

                toks[i - 1] = .{ .val = id };
                for (i..toks.len - 2) |j| {
                    toks[j] = toks[j + 2];
                }
                tokens_left -= 2;
                i -= 1;

                continue;
            }

            // TODO: Implement these.
            if (op.appliesToLeft() and i != 0) {
                unreachable;
            }

            if (op.appliesToRight() and i != toks.len - 1) {
                unreachable;
            }

            return error.ExpectedValue;
        }
    }

    if (toks.len == 0) {
        return error.ExpectedValue;
    }

    // Checking if there were extra values. The base call should result in one
    // value assuming all values have a corrisponding operator.
    if (base) {
        if (tokens_left > 1) {
            return error.UnexpectedValue;
        }
    }

    const value: Val.Id = if (toks[0] != .val)
        try translateValue(allocator, iter, scope, toks[0], writer)
    else
        toks[0].val;

    return .{
        .val = value,
        .tokens = num_tokens + child_tokens,
    };
}

fn translateValue(
    allocator: Allocator,
    iter: *Tokenizer,
    scope: *const Scope,
    tok: Tok,
    writer: *InstWriter,
) !VarId {
    if (tok == .val) {
        return tok.val;
    }

    return switch (tok.tok.tag) {
        .identifier => scope.getVar(iter.getSrc(tok.tok)) orelse {
            return error.UnknownIdentifier;
        },
        .number => try writer.write(
            allocator,
            try parser.parseNum(iter.getSrc(tok.tok)),
        ),
        else => error.ExpectedValue,
    };
}

fn collectToks(
    allocator: Allocator,
    iter: *Tokenizer,
) ![]Tok {
    var toks: std.ArrayList(Tok) = .{};

    var depth: usize = 0;
    while (true) {
        const tok = try iter.next();
        switch (tok.tag) {
            .l_paren => depth += 1,
            .r_paren => {
                if (depth == 0) {
                    iter.back(tok);
                    break;
                }

                depth -= 1;
            },
            .plus_plus, .minus_minus, .equal_equal, .bang_equal, .angle_bracket_left, .angle_bracket_left_equal, .angle_bracket_right, .angle_bracket_right_equal, .number, .identifier, .period, .plus, .minus, .asterisk, .slash => {},
            else => {
                iter.back(tok);
                break;
            },
        }

        try toks.append(allocator, .{ .tok = tok });
    }

    if (depth != 0) {
        toks.deinit(allocator);
        return error.UnclosedParenthesis;
    }

    return toks.toOwnedSlice(allocator);
}

const debug_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test parse {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 3 } },
        .{ .num = .{ .int = 1 } },
        .{ .expr = .{ .add = .{ 0, 1 } } },
        .{ .num = .{ .int = 2 } },
        .{ .expr = .{ .mul = .{ 3, 2 } } },
        .{ .num = .{ .int = 9 } },
        .{ .expr = .{ .add = .{ 5, 4 } } },
    };

    var iter = Tokenizer.from("9 + 2 * (3 + 1)");
    var writer = InstWriter{};

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    const id = try parse(debug_allocator, &iter, &scope, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "parse with variables" {
    const expected = [_]ir.Inst{
        .{ .alloca = .{ .constant = false, .primitive = .int } },
        .{ .alloca = .{ .constant = false, .primitive = .int } },
        .{ .alloca = .{ .constant = false, .primitive = .int } },
        .{ .expr = .{ .add = .{ 2, 1 } } },
        .{ .num = .{ .int = 2 } },
        .{ .expr = .{ .mul = .{ 0, 4 } } },
        .{ .expr = .{ .div = .{ 5, 3 } } },
    };

    var iter = Tokenizer.from("a * 2 / (j + c)");
    var writer = InstWriter{};

    var scope = Scope{ .variables = .init(debug_allocator) };

    const alloca = ir.Inst{ .alloca = .{ .primitive = .int } };

    try scope.variables.put("a", 0);
    _ = try writer.write(debug_allocator, alloca);

    try scope.variables.put("c", 1);
    _ = try writer.write(debug_allocator, alloca);

    try scope.variables.put("j", 2);
    _ = try writer.write(debug_allocator, alloca);

    defer scope.variables.deinit();

    const id = try parse(debug_allocator, &iter, &scope, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "single value in parenthesis" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 1 } },
    };

    var iter = Tokenizer.from("((1))");
    var writer = InstWriter{};

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    const id = try parse(debug_allocator, &iter, &scope, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "unknown identifier" {
    var iter = Tokenizer.from("1 + (b)");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.UnknownIdentifier,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}

test "expected value" {
    var iter = Tokenizer.from("1 + ()");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.ExpectedValue,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}

test "multiple parenthesis expression" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 2 } },
        .{ .num = .{ .int = 1 } },
        .{ .expr = .{ .add = .{ 0, 1 } } },
        .{ .num = .{ .int = 3 } },
        .{ .expr = .{ .mul = .{ 2, 3 } } },
        .{ .num = .{ .int = 5 } },
        .{ .expr = .{ .mul = .{ 4, 5 } } },
        .{ .num = .{ .int = 4 } },
        .{ .expr = .{ .add = .{ 7, 6 } } },
    };

    var iter = Tokenizer.from("4 + ((2 + 1) * 3) * 5");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    const id = try parse(debug_allocator, &iter, &scope, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "single value" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 2 } },
    };

    var iter = Tokenizer.from("2");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    const id = try parse(debug_allocator, &iter, &scope, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "Unclosed parenthesis" {
    var iter = Tokenizer.from("((1 + 1) + 5");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.UnclosedParenthesis,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}

test "semicolon with unclosed parenthesis" {
    var iter = Tokenizer.from("(2 + 2;");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.UnclosedParenthesis,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}

test "extra parenthesis" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 1000 } },
        .{ .num = .{ .int = 5 } },
        .{ .expr = .{ .add = .{ 0, 1 } } },
    };

    var iter = Tokenizer.from("(1000 + 5))");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    const id = try parse(debug_allocator, &iter, &scope, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "unexpected value" {
    var iter = Tokenizer.from("1 2");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.UnexpectedValue,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}

test "unexpected value with right parenthesis" {
    var iter = Tokenizer.from("1 (2)");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.UnexpectedValue,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}

test "unexpected value with left parenthesis" {
    var iter = Tokenizer.from("(1) 2");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.UnexpectedValue,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}

test "unexpected value with parenthesis" {
    var iter = Tokenizer.from("(1) (2)");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    try expectEqual(
        error.UnexpectedValue,
        parse(debug_allocator, &iter, &scope, &writer),
    );
}
