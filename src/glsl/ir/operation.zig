const ir = @import("../ir.zig");
const Type = ir.Type;
const Val = ir.Val;
const parser = @import("../parser.zig");

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

    pub fn initDual(op: parser.Op, a: Val.Id, b: Val.Id) Self {
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

    pub fn initSingle(op: parser.Op, arg: Val.Id) Self {
        return switch (op) {
            .sub => .{ .neg = arg },
            .bnot => .{ .bnot = arg },
            .lnot => .{ .lnot = arg },
            else => unreachable,
        };
    }
};
