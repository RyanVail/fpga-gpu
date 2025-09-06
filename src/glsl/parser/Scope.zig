const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("../parser.zig");
const Tokenizer = parser.Tokenizer;
const Var = parser.@"var";
const Expr = parser.Expr;
const ir = @import("../ir.zig");
const InstWriter = ir.InstWriter;

const Self = @This();

parent: ?*Self = null,
variables: std.StringHashMap(Var.Id),

const State = enum {
    start,
    if_expr,
    else_expr,
};

pub fn parse(
    allocator: Allocator,
    iter: *Tokenizer,
    parent: ?*Self,
    labels: *u32,
    writer: *InstWriter,
) !void {
    var self: Self = .{
        .parent = parent,
        .variables = .init(allocator),
    };

    var if_end: ?u32 = null;

    var tok = try iter.next();
    state: switch (State.start) {
        .start => switch (tok.tag) {
            .keyword_if => {
                tok = try iter.next();
                continue :state .if_expr;
            },
            .keyword_else => {
                tok = try iter.next();
                continue :state .else_expr;
            },
            .keyword_return => {
                _ = try writer.write(allocator, .{
                    .ret = try Expr.parse(allocator, iter, &self, writer),
                });

                tok = try iter.next();
                if (tok.tag != .semicolon) {
                    return error.ExpectedSemicolon;
                }
            },
            .l_brace => break :state,
            else => break :state,
        },
        .if_expr => switch (tok.tag) {
            .l_paren => {
                // TODO: This has to be a special expr parser because of short
                // circuits.
                const cond = try Expr.parse(allocator, iter, &self, writer);

                tok = try iter.next();
                if (tok.tag != .r_paren) {
                    return error.ExpectedRParen;
                }

                tok = try iter.next();
                if (tok.tag != .l_brace) {
                    return error.ExpectedScope;
                }

                const on_true = labels.*;
                const on_false = labels.* + 1;
                labels.* += 2;

                if (if_end == null) {
                    if_end = labels.*;
                    labels.* += 1;
                }

                _ = try writer.write(allocator, .{
                    .cond_branch = .{
                        .value = cond,
                        .on_true = on_true,
                        .on_false = on_false,
                    },
                });

                _ = try writer.write(allocator, .{ .label = on_true });
                try parse(allocator, iter, &self, labels, writer);
                _ = try writer.write(allocator, .{ .branch = if_end.? });

                _ = try writer.write(allocator, .{ .label = on_false });

                tok = try iter.next();
                if (tok.tag == .keyword_else) {
                    continue :state .else_expr;
                } else {
                    _ = try writer.write(allocator, .{ .label = if_end.? });
                    if_end = null;
                }

                continue :state .start;
            },
            else => return error.ExpectedCondExpr,
        },
        .else_expr => switch (tok.tag) {
            .l_brace => {
                try parse(allocator, iter, &self, labels, writer);
                _ = try writer.write(allocator, .{ .label = if_end.? });

                continue :state .start;
            },
            .keyword_if => {
                tok = try iter.next();
                continue :state .if_expr;
            },
            else => continue :state .start,
        },
    }
}

pub fn getVar(self: Self, name: []const u8) ?Var.Id {
    if (self.variables.get(name)) |v| {
        return v;
    }

    return if (self.parent) |p| p.getVar(name) else null;
}

pub fn addVar(self: *Self, name: []const u8, id: Var.Id) Allocator.Error!void {
    try self.variables.putNoClobber(name, id);
}

const debug_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "parse return" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 5 } },
        .{ .ret = 0 },
    };

    var iter = Tokenizer.from("return 5;");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Self{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    var labels: u32 = 0;
    const id = try parse(debug_allocator, &iter, &scope, &labels, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "parse if" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 0 } },
        .{ .num = .{ .int = 8 } },
        .{ .expr = .{ .eq = .{ 0, 1 } } },
        .{ .cond_branch = .{ .value = 2, .on_true = 0, .on_false = 1 } },
        .{ .label = 0 },
        .{ .branch = 2 },
        .{ .label = 1 },
        .{ .label = 2 },
    };

    var iter = Tokenizer.from("if (0 == 8) {}");
    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Self{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    var labels: u32 = 0;
    const id = try parse(debug_allocator, &iter, &scope, &labels, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "parse if else" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 0 } },
        .{ .num = .{ .int = 8 } },
        .{ .expr = .{ .eq = .{ 0, 1 } } },
        .{ .cond_branch = .{ .value = 2, .on_true = 0, .on_false = 1 } },
        .{ .label = 0 },
        .{ .branch = 2 },
        .{ .label = 1 },
        .{ .label = 2 },
    };

    var iter = Tokenizer.from("if (0 == 8) {}");

    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Self{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    var labels: u32 = 0;
    const id = try parse(debug_allocator, &iter, &scope, &labels, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "parse if else chain" {
    const expected = [_]ir.Inst{
        .{ .num = .{ .int = 0 } },
        .{ .num = .{ .int = 8 } },
        .{ .expr = .{ .eq = .{ 0, 1 } } },
        .{ .cond_branch = .{ .value = 2, .on_true = 0, .on_false = 1 } },
        .{ .label = 0 },
        .{ .branch = 2 },
        .{ .label = 1 },
        .{ .num = .{ .int = 0 } },
        .{ .num = .{ .int = 1 } },
        .{ .expr = .{ .eq = .{ 7, 8 } } },
        .{ .cond_branch = .{ .value = 9, .on_true = 3, .on_false = 4 } },
        .{ .label = 3 },
        .{ .branch = 2 },
        .{ .label = 4 },
        .{ .num = .{ .int = 4 } },
        .{ .num = .{ .int = 2 } },
        .{ .expr = .{ .eq = .{ 14, 15 } } },
        .{ .cond_branch = .{ .value = 16, .on_true = 5, .on_false = 6 } },
        .{ .label = 5 },
        .{ .branch = 7 },
        .{ .label = 6 },
        .{ .label = 7 },
        .{ .label = 2 },
    };

    var iter = Tokenizer.from(
        \\if (0 == 8) {
        \\} else if (0 == 1) {
        \\} else {
        \\    if (4 == 2) {
        \\    }
        \\}
    );

    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Self{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    var labels: u32 = 0;
    const id = try parse(debug_allocator, &iter, &scope, &labels, &writer);
    _ = id;

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(ir.Inst, &expected, slice);
}

test "if no parenthesis" {
    var iter = Tokenizer.from("if 2 != 4 {}");

    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Self{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    var labels: u32 = 0;
    try expectEqual(
        error.ExpectedCondExpr,
        parse(debug_allocator, &iter, &scope, &labels, &writer),
    );
}

test "if no expression" {
    var iter = Tokenizer.from("if () {}");

    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Self{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    var labels: u32 = 0;
    try expectEqual(
        error.ExpectedValue,
        parse(debug_allocator, &iter, &scope, &labels, &writer),
    );
}
