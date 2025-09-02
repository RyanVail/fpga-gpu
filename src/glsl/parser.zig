const std = @import("std");

pub const operator = @import("parser/operator.zig");
pub const Op = operator.Op;

pub const @"type" = @import("parser/type.zig");
pub const Type = @"type".Type;

pub const TokenIter = std.mem.TokenIterator(u8, .any);

test {
    _ = operator;
    _ = @"type";
}
