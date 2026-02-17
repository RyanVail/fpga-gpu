const std = @import("std");
const assert = std.debug.assert;
const Value = @import("Value.zig");

const Self = @This();

/// The minimum possible value of this range.
min: Value = .initZero(),

/// The maximum possible value of this range.
max: Value,

/// The step value between min and max.
/// One means the range only contains whole numbers.
/// Zero means the step is not known and could be any value.
step: Value = .initOne(),

/// Checks if this range is valid.
pub fn isValid(self: Self) bool {
    return !self.step.negative and !self.min.gt(self.max);
}

/// Checks if a value is within the bounds of this range.
///
/// This does not check the step for that use `contains`.
pub fn withinBounds(self: Self, value: Value) bool {
    assert(self.isValid());
    return self.min.lte(value) and self.max.gte(value);
}

// TODO: Check step.
/// Checks if this range contains a value.
pub fn contains(self: Self, value: Value) bool {
    assert(self.isValid());
    if (!self.withinBounds(value)) {
        return false;
    }

    // Checking if the value falls on the step.
    return value.eql(value.trunc(self.step));
}

/// Attempts to fold this range into a value.
pub fn fold(self: Self) ?Value {
    assert(self.isValid());
    const stepped = self.min.add(self.step) catch {
        return null;
    };

    if (stepped.gt(self.max) or self.min.eql(self.max)) {
        return self.min;
    } else {
        return null;
    }
}

/// Checks if this range only contains whole numbers.
pub fn isWholeNum(self: Self) bool {
    assert(self.isValid());
    return self.step.isWholeNum();
}

/// Adds a range to this range.
pub fn add(self: Self, other: Self) error{Overflow}!Self {
    assert(self.isValid());
    assert(other.isValid());

    return .{
        .min = try self.min.add(other.min),
        .max = try self.max.add(other.max),
        .step = .{
            .negative = false,
            .val = @min(self.step.val, other.step.val),
        },
    };
}

/// Subtracts a range from this range.
pub fn sub(self: Self, other: Self) error{Overflow}!Self {
    assert(self.isValid());
    assert(other.isValid());

    return .{
        .min = try self.min.sub(other.min),
        .max = try self.max.sub(other.max),
        .step = .{
            .negative = false,
            .val = @min(self.step.val, other.step.val),
        },
    };
}

const expectEqual = std.testing.expectEqual;

test withinBounds {
    const Test = struct{ bool, Self, Value };
    const tests = [_]Test{
        .{ true, .{ .max = .initOne() }, .initZero() },
        .{ true, .{ .max = .initOne() }, .initOne() },
        .{ false, .{ .max = .initOne() }, .initNegOne() },
        .{ true, .{
            .min = .initFloat(@as(f32, -200.5)),
            .max = .initFloat(@as(f64, -5.0)),
        }, .initInt(-10) },
        .{ false, .{
            .min = .initFloat(@as(f32, 15.0)),
            .max = .initFloat(@as(f64, 25.0)),
        }, .initInt(10) },
        .{ true, .{
            .min = .initFloat(@as(f32, 15.0)),
            .max = .initFloat(@as(f64, 25.0)),
        }, .initInt(15) },
        .{ true, .{
            .min = .initInt(25),
            .max = .initInt(25),
        }, .initInt(25) },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].withinBounds(t[2]));
    }
}

test contains {
    const Test = struct{ bool, Self, Value };
    const tests = [_]Test{
        .{ true, .{ .max = .initOne() }, .initZero() },
        .{ true, .{ .max = .initOne() }, .initOne() },
        .{ false, .{ .max = .initOne() }, .initNegOne() },
        .{ true, .{
            .min = .initFloat(@as(f32, -200.5)),
            .max = .initFloat(@as(f64, -5.0)),
        }, .initInt(-10) },
        .{ false, .{
            .min = .initFloat(@as(f32, 15.0)),
            .max = .initFloat(@as(f64, 25.0)),
        }, .initInt(10) },
        .{ true, .{
            .min = .initFloat(@as(f32, 15.0)),
            .max = .initFloat(@as(f64, 25.0)),
        }, .initInt(15) },
        .{ true, .{
            .min = .initInt(25),
            .max = .initInt(25),
        }, .initInt(25) },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].contains(t[2]));
    }
}

test fold {
    const Test = struct{ ?Value, Self };
    const tests = [_]Test{
        .{ .initZero(), .{ .max = .initFloat(@as(f64, 0.25)) }},
        .{ .initOne(), .{
            .min = .initOne(),
            .max = .initOne(),
            .step = .initFloat(@as(f32, 0.0)),
        }},
        .{ .initInt(-34), .{
            .min = .initInt(-34),
            .max = .initOne(),
            .step = .initFloat(@as(f32, 149.125)),
        }},
        .{ null, .{ .max = .initOne() } },
        .{ null, .{ .min = .initNegOne(), .max = .initOne() } },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].fold());
    }
}

test isWholeNum {
    const Test = struct{ bool, Self };
    const tests = [_]Test{
        .{ true, .{ .max = .initOne() } },
        .{ true, .{ .max = .initInt(5) } },
        .{ true, .{ .min = .initInt(-5), .max = .initInt(0xFFFF) } },
        .{ false, .{
            .max = .initOne(),
            .step = .initFloat(@as(f32, 0.25)),
        }},
        .{ true, .{
            .min = .initFloat(@as(f32, 0.8)),
            .max = .initOne(),
        }},
        .{ true, .{ .max = .initFloat(@as(f32, 5.45)) }},
        .{ true, .{
            .step = .initInt(5),
            .max = .initInt(25),
        }},
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].isWholeNum());
    }
}

test add {
    const Test = struct{ Self, Self, Self };
    const tests = [_]Test{
        .{
            .{ .max = .initInt(2) },
            .{ .max = .initOne() },
            .{ .max = .initOne() },
        },
        .{
            .{ .max = .initOne() },
            .{ .max = .initOne() },
            .{ .max = .initZero() },
        },
        .{
            .{ .min = .initInt(-3), .max = .initInt(7) },
            .{ .min = .initInt(-3), .max = .initOne() },
            .{ .max = .initInt(6), .step = .initInt(2) },
        },
        .{
            .{ .max = .initInt(2), .step = .initFloat(@as(f32, 0.25)) },
            .{ .max = .initOne() },
            .{ .max = .initOne(), .step = .initFloat(@as(f64, 0.25)) },
        },
    };

    for (tests) |t| {
        try expectEqual(t[0], try t[1].add(t[2]));
    }
}

test sub {
    const Test = struct{ Self, Self, Self };
    const tests = [_]Test{
        .{
            .{ .max = .initInt(2) },
            .{ .max = .initOne() },
            .{ .max = .initOne() },
        },
        .{
            .{ .max = .initOne() },
            .{ .max = .initOne() },
            .{ .max = .initZero() },
        },
        .{
            .{ .min = .initInt(-3), .max = .initInt(7) },
            .{ .min = .initInt(-3), .max = .initOne() },
            .{ .max = .initInt(6), .step = .initInt(2) },
        },
        .{
            .{ .max = .initInt(2), .step = .initFloat(@as(f32, 0.25)) },
            .{ .max = .initOne() },
            .{ .max = .initOne(), .step = .initFloat(@as(f64, 0.25)) },
        },
    };

    for (tests) |t| {
        try expectEqual(t[0], try t[1].add(t[2]));
    }
}
