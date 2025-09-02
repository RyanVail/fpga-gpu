const std = @import("std");

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

    pre_inc,
    pre_dec,

    post_inc,
    post_dec,

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

    pub fn read(tok: []const u8) ?Self {
        return map.get(tok);
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
            .pre_inc, .post_inc => "++",
            .pre_dec, .post_dec => "--",
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
};

const expectEqual = std.testing.expectEqual;

test "operator read" {
    const Pair = struct { ?Op, []const u8 };
    const results = [_]Pair{
        .{ .mod_assign, "%=" },
        .{ .add, "+" },
        .{ .sub, "-" },
        .{ null, "" },
        .{ null, " " },
        .{ .field, "." },
        .{ null, "- " },
        .{ .bxor_assign, "^=" },
        .{ .bxor, "^" },
        .{ null, ". " },
        .{ .assign, "=", },
    };

    for (results) |r| {
        try expectEqual(r[0], Op.read(r[1]));
    }
}
