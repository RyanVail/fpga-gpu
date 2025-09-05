
const ir = @import("../ir.zig");
const Type = ir.Type;
const Val = ir.Val;

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
};
