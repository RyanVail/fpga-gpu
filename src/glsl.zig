pub const Token = @import("glsl/Token.zig");
pub const Tokenizer = @import("glsl/Tokenizer.zig");

pub const operator = @import("glsl/operator.zig");
pub const Op = operator.Op;

pub const @"type" = @import("glsl/type.zig");
pub const Type = @"type".Type;
pub const Primitive = @"type".Primitive;

pub const Func = @import("glsl/Func.zig");
pub const @"var" = @import("glsl/var.zig");
pub const Scope = @import("glsl/Scope.zig");
pub const Expr = @import("glsl/Expr.zig");

pub const parser = @import("glsl/parser.zig");
