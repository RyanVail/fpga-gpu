const std = @import("std");

pub const Token = @import("parser/Token.zig");
pub const Tokenizer = @import("parser/Tokenizer.zig");

pub const operator = @import("parser/operator.zig");
pub const Op = operator.Op;

pub const @"type" = @import("parser/type.zig");
pub const Type = @"type".Type;
pub const Primitive = @"type".Primitive;

pub const Func = @import("parser/Func.zig");
pub const @"var" = @import("parser/var.zig");
pub const Scope = @import("parser/Scope.zig");
pub const Expr = @import("parser/Expr.zig");

pub const TokenIter = std.mem.TokenIterator(u8, .any);

const ir = @import("ir.zig");

// TODO: This is very quick and dirty number parser.
pub fn parseNum(str: []const u8) std.fmt.ParseIntError!ir.Inst {
    var num_type: std.meta.Tag(ir.Inst.Constant) = .int;

    var end_index: ?usize = null;
    for (str, 0..) |char, i| {
        switch (char) {
            '.' => num_type = .double,
            'u', 'U' => {
                num_type = .uint;
                if (end_index == null) {
                    end_index = i;
                }
            },
            'l', 'L' => {
                num_type = .double;
                if (end_index == null) {
                    end_index = i;
                }
            },
            'f', 'F' => {
                if (num_type != .double) {
                    num_type = .float;
                }

                if (end_index == null) {
                    end_index = i;
                }
            },
            else => {},
        }
    }

    const num = str[0 .. end_index orelse str.len];
    return switch (num_type) {
        .int => .{ .num = .{ .int = try std.fmt.parseInt(i32, num, 0) } },
        .uint => .{ .num = .{ .uint = try std.fmt.parseInt(u32, num, 0) } },
        .float => .{ .num = .{ .float = try std.fmt.parseFloat(f32, num) } },
        .double => .{ .num = .{ .double = try std.fmt.parseFloat(f64, num) } },
        else => unreachable,
    };
}

const expectEqual = std.testing.expectEqual;

test "parse int" {
    const Pair = struct { std.fmt.ParseIntError!ir.Inst, []const u8 };
    const results = [_]Pair{
        .{ .{ .num = .{ .uint = 392 } }, "392u" },
        .{ .{ .num = .{ .int = 1 } }, "1" },
        .{ .{ .num = .{ .float = 10.0 } }, "10f" },
        .{ .{ .num = .{ .double = 10.0 } }, "10.0" },
        .{ .{ .num = .{ .double = 0.5 } }, "0.5" },
        .{ .{ .num = .{ .double = 4.5 } }, "4.5LF" },
        .{ .{ .num = .{ .int = 89 } }, "8_9" },
    };

    for (results) |pair| {
        try expectEqual(pair[0], parseNum(pair[1]));
    }
}
