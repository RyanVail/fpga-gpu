pub const operator = @import("glsl/operator.zig");
pub const Op = operator.Op;
pub const @"type" = @import("glsl/type.zig");
pub const Type = @"type".Type;
pub const parser = @import("glsl/parser.zig");

test {
    _ = operator;
    _ = @"type";
}
