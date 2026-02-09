const std = @import("std");
const assert = std.debug.assert;

pub const decimal_bits = 64;
pub const whole_bits = 64;
pub const IntType = std.meta.Int(.unsigned, whole_bits + decimal_bits);

const Self = @This();

/// If this value is negative.
negative: bool = false,

/// The fixed point representation of this value as defined by `decimal_bits`
/// and `whole_bits`.
val: IntType,

pub fn initZero() Self {
    return .{ .val = 0 };
}

pub fn initOne() Self {
    return .{ .val = @intCast(1 << decimal_bits) };
}

pub fn initNegOne() Self {
    return .{
        .negative = true,
        .val = @intCast(1 << decimal_bits),
    };
}

pub fn initInt(int: anytype) Self {
    var s: Self = undefined;
    s.negative = (int < 0);
    s.val = @intCast(@as(IntType, @abs(int)) << decimal_bits);
    return s;
}

pub fn initFloat(float: anytype) Self {
    var s: Self = undefined;
    s.negative = (float < 0);
    s.val = @intFromFloat(@abs(float) * (@as(IntType, 1) << decimal_bits));
    return s;
}

/// Normalizes `-0` to `+0`.
pub fn normalize(self: Self) Self {
    if (self.isZero()) {
        return .initZero();
    } else {
        return self;
    }
}

/// Checks if this value is equal to zero.
pub fn isZero(self: Self) bool {
    return self.val == 0;
}

/// Checks if this value is equal to positive one.
pub fn isOne(self: Self) bool {
    return self.val == (1 << decimal_bits) and !self.negative;
}

/// Checks if this value is equal to negative one.
pub fn isNegOne(self: Self) bool {
    return self.val == (1 << decimal_bits) and self.negative;
}

/// Checks if this value is a whole number.
pub fn isWholeNum(self: Self) bool {
    return (self.val % @as(IntType, 1 << decimal_bits)) == 0;
}

/// Checks if this value equals another value.
pub fn eql(self: Self, other: Self) bool {
    return self.negative == other.negative and
        self.val == other.val;
}

/// Checks if this value doesn't equal another value.
pub fn neq(self: Self, other: Self) bool {
    return !self.eql(other);
}

/// Checks if this value is greater than another value.
pub fn gt(self: Self, other: Self) bool {
    if (self.negative and !other.negative) {
        return false;
    } else if (other.negative and !self.negative) {
        return true;
    } else if (self.negative and other.negative) {
        return self.val < other.val;
    } else {
        return self.val > other.val;
    }
}

/// Checks if this value is greater than or equal to another value.
pub fn gte(self: Self, other: Self) bool {
    return self.gt(other) or self.eql(other);
}

/// Checks if this value is less than another value.
pub fn lt(self: Self, other: Self) bool {
    return other.gt(self);
}

/// Checks if this value is less than or equal to another value.
pub fn lte(self: Self, other: Self) bool {
    return other.gt(self) or self.eql(other);
}

/// Calculates the absolute value of this value.
pub fn abs(self: Self) Self {
    return .{ .val = self.val };
}

/// Takes the negative of this value.
pub fn neg(self: Self) Self {
    return .{
        .negative = !self.negative,
        .val = self.val,
    };
}

/// Adds this value to another value.
pub fn add(self: Self, other: Self) error{Overflow}!Self {
    if (self.negative != other.negative) {
        const greater = (self.val > other.val);
        return (Self{
            .negative = if (greater) self.negative else other.negative,
            .val = try std.math.sub(
                IntType,
                @max(self.val, other.val),
                @min(self.val, other.val),
            ),
        }).normalize();
    } else {
        return .{
            .negative = self.negative,
            .val = try std.math.add(IntType, self.val, other.val),
        };
    }
}

/// Subtracts a value from this value.
pub fn sub(self: Self, other: Self) error{Overflow}!Self {
    return self.add(other.neg());
}

/// Truncates this value to `step`.
pub fn trunc(self: Self, step: Self) Self {
    assert(!step.negative);
    return .{
        .negative = self.negative,
        .val = self.val - (self.val % step.val),
    };
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "init one and zero" {
    const zero = Self.initZero();
    try expect(!zero.negative);
    try expectEqual(0, zero.val);

    const one = Self.initOne();
    try expect(!one.negative);
    try expectEqual(1 << decimal_bits, one.val);

    const neg_one = Self.initNegOne();
    try expect(neg_one.negative);
    try expectEqual(1 << decimal_bits, neg_one.val);
}

test initInt {
    try expectEqual(
        Self{ .negative = false, .val = 5 << decimal_bits },
        initInt(@as(u8, 5)),
    );

    try expectEqual(
        Self{ .negative = true, .val = 2000 << decimal_bits },
        initInt(@as(i12, -2000)),
    );
}

test initFloat {
    try expectEqual(
        Self{
            .negative = false,
            .val = (2 << decimal_bits) + (1 << decimal_bits) / 2,
        },
        initFloat(@as(f64, 2.5)),
    );

    try expectEqual(
        Self{ .negative = false, .val = (1 << decimal_bits) / 2 },
        initFloat(@as(f64, 0.5)),
    );

    try expectEqual(
        Self{ .negative = false, .val = (1 << decimal_bits) / 4 },
        initFloat(@as(f32, 0.25)),
    );

    try expectEqual(
        Self{ .negative = false, .val = (1 << decimal_bits) / 8 },
        initFloat(@as(f64, 0.125)),
    );
}

test isZero {
    try expect(initZero().isZero());
    try expect(!initOne().isZero());
    try expect(!initInt(@as(i8, 1)).isZero());
    try expect(!initInt(@as(i8, -1)).isZero());
    try expect(initInt(@as(i8, 0)).isZero());
    try expect(initInt(@as(u32, 0)).isZero());
    try expect(!initFloat(@as(f32, 0.5)).isZero());
    try expect(!initFloat(@as(f64, 1.0)).isZero());
}

test isOne {
    try expect(initOne().isOne());
    try expect(initInt(@as(i8, 1)).isOne());
    try expect(!initInt(@as(i8, -1)).isOne());
    try expect(!initInt(@as(u32, 0)).isOne());
    try expect(!initFloat(@as(f32, 0.5)).isOne());
    try expect(initFloat(@as(f64, 1.0)).isOne());
}

test isNegOne {
    try expect(!initOne().isNegOne());
    try expect(!initInt(@as(i8, 1)).isNegOne());
    try expect(initInt(@as(i8, -1)).isNegOne());
    try expect(!initInt(@as(u32, 0)).isNegOne());
    try expect(!initFloat(@as(f32, 0.5)).isNegOne());
    try expect(initFloat(@as(f32, -1.0)).isNegOne());
    try expect(!initFloat(@as(f64, 1.0)).isNegOne());
}

test isWholeNum {
    try expect(initZero().isWholeNum());
    try expect(initOne().isWholeNum());
    try expect(initInt(@as(i32, -1)).isWholeNum());
    try expect(initInt(@as(i12, -8)).isWholeNum());
    try expect(initInt(@as(u8, 8)).isWholeNum());
    try expect(!initFloat(@as(f32, -0.5)).isWholeNum());
    try expect(!initFloat(@as(f64, -9.02)).isWholeNum());
    try expect(initFloat(@as(f32, 5.0)).isWholeNum());
}

test eql {
    try expect(!initZero().eql(initOne()));
    try expect(initZero().eql(initZero()));
    try expect(initOne().eql(initOne()));
    try expect(!initZero().eql(initInt(@as(u32, 256))));
    try expect(!initOne().eql(initInt(@as(i8, -1))));
    try expect(initOne().eql(initFloat(@as(f32, 1.0))));
    try expect(!initOne().eql(initFloat(@as(f64, 0.25))));
}

test "comparisons" {
    const a = initFloat(@as(f64, -0.25));
    const b = initFloat(@as(f64, 0.0));
    const c = initFloat(@as(f64, 0.25));

    try expect(a.neq(b));
    try expect(a.neq(c));
    try expect(a.lt(b));
    try expect(a.lte(b));
    try expect(a.lt(c));
    try expect(a.lte(c));

    try expect(b.neq(a));
    try expect(b.neq(c));
    try expect(b.lt(c));
    try expect(b.gt(a));
    try expect(b.gte(a));
    try expect(b.lt(c));
    try expect(b.lte(c));

    try expect(c.neq(a));
    try expect(c.neq(b));
    try expect(c.gt(a));
    try expect(c.gte(a));
    try expect(c.gt(b));
    try expect(c.gte(b));
    try expect(!c.lt(c));
    try expect(c.lte(c));

    const d = initFloat(@as(f64, -10.0));
    const e = initFloat(@as(f64, 10.0));

    try expect(d.lt(a));
    try expect(a.gte(d));
    try expect(d.lt(e));
    try expect(e.gt(c));
    try expect(c.lt(e));
}

test abs {
    try expectEqual(initOne(), initOne().abs());
    try expectEqual(initOne(), initInt(@as(i8, -1)).abs());
    try expectEqual(initFloat(@as(f32, 5.0)), initInt(@as(i8, -5)).abs());
}

test neg {
    try expect(initOne().neg().isNegOne());
    try expect(initOne().neg().neg().isOne());
    try expect(initZero().neg().isZero());
    try expectEqual(
        initFloat(@as(f32, -203.125)),
        initFloat(@as(f64, 203.125)).neg(),
    );
}

// TODO: These should test overflow too.
test add {
    const Test = struct { Self, Self, Self };
    const tests = [_]Test{
        .{ initZero(), initZero(), initZero() },
        .{ initZero(), initOne(), initNegOne() },
        .{ initInt(@as(u8, 2)), initOne(), initOne() },
        .{ initInt(@as(i8, -2)), initNegOne(), initNegOne() },
        .{
            initFloat(@as(f32, -7.125)),
            initFloat(@as(f32, 8.0)),
            initFloat(@as(f64, -15.125)),
        },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].add(t[2]));
    }
}

test sub {
    const Test = struct { Self, Self, Self };
    const tests = [_]Test{
        .{ initZero(), initZero(), initZero() },
        .{ initZero(), initOne(), initOne() },
        .{ initZero(), initNegOne(), initNegOne() },
        .{ initOne(), initZero(), initNegOne() },
        .{ initInt(@as(u8, 2)), initOne(), initNegOne() },
        .{
            initFloat(@as(f32, 23.125)),
            initFloat(@as(f32, 8.0)),
            initFloat(@as(f64, -15.125)),
        },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].sub(t[2]));
    }
}

test trunc {
    const Test = struct{ Self, Self, Self };
    const tests = [_]Test{
        .{ .initOne(), .initFloat(@as(f32, 1.5)), .initOne() },
        .{ .initZero(), .initOne(), .initInt(2) },
        .{ .initInt(2), .initInt(2), .initInt(2) },
        .{ .initInt(4), .initInt(5), .initInt(2) },
        .{ .initInt(16), .initInt(23), .initInt(8) },
        .{ .initNegOne(), .initFloat(@as(f32, -1.5)), .initOne() },
        .{
            .initFloat(@as(f32, 1.5)),
            .initFloat(@as(f32, 1.8)),
            .initFloat(@as(f64, 0.5)),
        },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].trunc(t[2]));
    }
}
