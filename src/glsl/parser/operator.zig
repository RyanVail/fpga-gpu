const std = @import("std");

const parser = @import("../parser.zig");
const Token = parser.Token;

pub const Weight = enum {
    const Self = @This();

    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    @"10",
    @"11",
    @"12",

    pub const max = Self.@"12";
};

pub const Op = enum {
    const Self = @This();

    // TODO: This is slow.
    const map = b: {
        const fields = @typeInfo(Self).@"enum".fields;

        const KV = struct { []const u8, Self };
        var pairs: [fields.len]KV = undefined;
        for (fields, &pairs) |field, *pair| {
            const val: Self = @enumFromInt(field.value);
            pair.* = .{ val.toString(), val };
        }

        break :b std.StaticStringMap(Self).initComptime(pairs);
    };

    add,
    sub,
    mul,
    div,
    mod,

    bxor,
    bor,
    band,

    bnot,

    lnot,
    land,
    lxor,
    lor,

    eq,
    ne,
    lt,
    gt,
    le,
    ge,

    inc,
    dec,

    field,
    assign,

    add_assign,
    sub_assign,
    mul_assign,
    div_assign,
    mod_assign,

    bxor_assign,
    bor_assign,
    band_assign,

    /// Reads an operator from a token.
    pub fn read(tok: Token) ?Self {
        return switch (tok.tag) {
            .period => .field,
            .plus => .add,
            .plus_plus => .inc,
            .plus_equal => .add_assign,
            .minus => .sub,
            .minus_minus => .dec,
            .minus_equal => .sub_assign,
            .asterisk => .mul,
            .asterisk_equal => .mul_assign,
            .slash => .div,
            .slash_equal => .div_assign,
            .equal => .assign,
            .equal_equal => .eq,
            .bang_equal => .ne,
            .angle_bracket_left => .lt,
            .angle_bracket_left_equal => .le,
            .angle_bracket_right => .gt,
            .angle_bracket_right_equal => .ge,
            else => null,
        };
    }

    pub fn toString(self: Self) []const u8 {
        return switch (self) {
            .add => "+",
            .sub => "-",
            .mul => "*",
            .div => "/",
            .mod => "%",
            .bxor => "^",
            .bor => "|",
            .band => "&",
            .bnot => "~",
            .lnot => "!",
            .land => "&&",
            .lxor => "^^",
            .lor => "||",
            .eq => "==",
            .ne => "!=",
            .lt => "<",
            .gt => ">",
            .le => "<=",
            .ge => ">=",
            .inc => "++",
            .dec => "--",
            .field => ".",
            .assign => "=",
            .add_assign => "+=",
            .sub_assign => "-=",
            .mul_assign => "*=",
            .div_assign => "/=",
            .mod_assign => "%=",
            .bxor_assign => "^=",
            .bor_assign => "|=",
            .band_assign => "&=",
        };
    }

    pub fn appliesToLeft(self: Self) bool {
        return switch (self) {
            .inc, .dec => true,
            else => false,
        };
    }

    pub fn appliesToRight(self: Self) bool {
        return switch (self) {
            .sub, .bnot, .lnot => true,
            else => false,
        };
    }

    pub fn appliesToDual(self: Self) bool {
        return switch (self) {
            .add,
            .sub,
            .mul,
            .div,
            .mod,
            .bxor,
            .bor,
            .band,
            .land,
            .lxor,
            .lor,
            .eq,
            .ne,
            .lt,
            .gt,
            .le,
            .ge,
            .field,
            .assign,
            .add_assign,
            .sub_assign,
            .mul_assign,
            .div_assign,
            .mod_assign,
            .bxor_assign,
            .bor_assign,
            .band_assign,
            => true,
            else => false,
        };
    }

    pub fn getWeight(self: Self) Weight {
        return switch (self) {
            .field, .inc, .dec => .@"0",
            .bnot, .lnot => .@"1",
            .mul, .div, .mod => .@"2",
            .add, .sub => .@"3",
            .lt, .gt, .le, .ge => .@"4",
            .eq, .ne => .@"5",
            .band => .@"6",
            .bxor => .@"7",
            .bor => .@"8",
            .land => .@"9",
            .lxor => .@"10",
            .lor => .@"11",
            .assign,
            .add_assign,
            .sub_assign,
            .mul_assign,
            .div_assign,
            .mod_assign,
            .bxor_assign,
            .bor_assign,
            .band_assign,
            => .@"12",
        };
    }
};

const expectEqual = std.testing.expectEqual;

test "operator read" {
    const Pair = struct { ?Op, Token.Tag };
    const results = [_]Pair{
        .{ .add, .plus },
        .{ .sub, .minus },
        .{ null, .l_brace },
        .{ null, .l_paren },
        .{ .field, .period },
        .{ .div, .slash },
        .{ .dec, .minus_minus },
        .{ .div_assign, .slash_equal },
        .{ .eq, .equal_equal },
        .{ .assign, .equal },
        .{ .inc, .plus_plus },
    };

    for (results) |r| {
        const tok = Token{ .tag = r[1], .loc = undefined };
        try expectEqual(r[0], Op.read(tok));
    }
}
