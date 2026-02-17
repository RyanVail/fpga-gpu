const std = @import("std");
const ir = @import("../ir.zig");
const Val = ir.Val;
const glsl = @import("../glsl.zig");
const Type = glsl.Type;

pub const Tag = enum {
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

    neg,
    cast,
};

pub const Op = union(Tag) {
    const Self = @This();

    pub const Dual = struct { Val.Id, Val.Id };
    pub const Single = Val.Id;
    pub const Cast = struct {
        type: Type,
        value: Val.Id,
    };

    add: Dual,
    sub: Dual,
    mul: Dual,
    div: Dual,
    mod: Dual,
    bxor: Dual,
    bor: Dual,
    band: Dual,

    bnot: Single,
    lnot: Single,

    land: Dual,
    lxor: Dual,
    lor: Dual,
    eq: Dual,
    ne: Dual,
    lt: Dual,
    gt: Dual,
    le: Dual,
    ge: Dual,

    neg: Single,
    cast: Cast,

    pub fn isSingle(self: Self) bool {
        return self.getSingle() != null;
    }

    pub fn isDual(self: Self) bool {
        return self.getDual() != null;
    }

    pub fn getSingle(self: Self) ?Single {
        return switch (self) {
            .bnot, .lnot, .neg => |v| v,
            else => null,
        };
    }

    pub fn getDual(self: Self) ?Dual {
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
            => |v| v,
            else => null,
        };
    }

    pub fn initDual(op: glsl.Op, a: Val.Id, b: Val.Id) Self {
        const args = Dual{ a, b };
        return switch (op) {
            .add => .{ .add = args },
            .sub => .{ .sub = args },
            .mul => .{ .mul = args },
            .div => .{ .div = args },
            .mod => .{ .mod = args },
            .bxor => .{ .bxor = args },
            .bor => .{ .bor = args },
            .band => .{ .band = args },
            .land => .{ .land = args },
            .lxor => .{ .lxor = args },
            .lor => .{ .lor = args },
            .eq => .{ .eq = args },
            .ne => .{ .ne = args },
            .lt => .{ .lt = args },
            .gt => .{ .gt = args },
            .le => .{ .le = args },
            .ge => .{ .ge = args },
            else => unreachable,
        };
    }

    pub fn initSingle(op: glsl.Op, arg: Val.Id) Self {
        return switch (op) {
            .sub => .{ .neg = arg },
            .bnot => .{ .bnot = arg },
            .lnot => .{ .lnot = arg },
            else => unreachable,
        };
    }

    /// Checks if this operation uses the supplied value.
    pub fn usesVal(self: Self, val: Val.Id) bool {
        return switch (self) {
            inline else => |o| {
                return switch (@TypeOf(o)) {
                    Single => o == val,
                    Dual => o[0] == val or o[1] == val,
                    Cast => o.value == val,
                    else => unreachable,
                };
            },
        };
    }
};

const expectEqual = std.testing.expectEqual;

test "uses val" {
    const Test = struct{ bool, Op, Val.Id };
    const tests = [_]Test{
        .{ true, .initSingle(.bnot, 0), 0 },
        .{ false, .initSingle(.lnot, 4), 0 },
        .{ true, .initDual(.add, 1, 3), 3 },
        .{ false, .initDual(.add, 1, 2), 3 },
        .{ false, .initDual(.mul, 5, 2), 3 },
        .{ true, .initDual(.ge, 0, 0), 0 },
        .{ true, .{ .cast = .{
            .type = .{ .primitive = .int },
            .value = 100,
        } }, 100 },
        .{ false, .{ .cast = .{
            .type = .{ .primitive = .float },
            .value = 25,
        } }, 100 },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].usesVal(t[2]));
    }
}
