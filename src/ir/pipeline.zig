const std = @import("std");
const ir = @import("../ir.zig");
const Val = ir.Val;

/// A FIFO of values in a pipeline.
pub fn Pipeline(comptime max_depth: usize) type {
    return struct {
        const Self = @This();

        const depth = max_depth;
        const Index = std.math.IntFittingRange(0, depth - 1);

        start: Index = 0,
        vals: [depth]?Val.Id = @splat(null),

        fn calcIndex(self: Self, index: Index) Index {
            return @intCast(
                (@as(usize, self.start) + index) % depth
            );
        }

        pub fn get(self: Self, index: Index) ?Val.Id {
            return self.vals[self.calcIndex(index)];
        }

        pub fn next(self: *Self) ?Val.Id {
            const v = self.vals[self.start];
            self.vals[self.start] = null;
            self.start = @intCast((@as(usize, self.start) + 1) % depth);
            return v;
        }

        pub fn isIndexFull(self: Self, index: Index) bool {
            return self.get(index) != null;
        }

        /// Checks if this FIFO is full.
        pub fn isFull(self: *Self) bool {
            for (self.vals) |v| {
                if (v == null) {
                    return false;
                }
            }

            return true;
        }

        /// Schedules this 
        pub fn schedule(
            self: *Self,
            index: Index,
            val: Val.Id,
        ) error{IndexFull}!void {
            if (isIndexFull(self.*, index)) {
                return error.IndexFull;
            }

            self.vals[self.calcIndex(index)] = val;
        }
    };
}

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

test Pipeline {
    const Pipe = Pipeline(4);
    try expectEqual(4, Pipe.depth);

    var pipe: Pipe = .{};
    for (0..4) |i| {
        try expect(!pipe.isIndexFull(@intCast(i)));
    }

    try pipe.schedule(0, 32);
    try expect(!pipe.isFull());

    try expect(pipe.isIndexFull(0));
    try expect(!pipe.isIndexFull(1));
    try expect(!pipe.isIndexFull(2));
    try expect(!pipe.isIndexFull(3));

    try pipe.schedule(3, 7);
    try expect(!pipe.isFull());

    try expect(pipe.isIndexFull(0));
    try expect(!pipe.isIndexFull(1));
    try expect(!pipe.isIndexFull(2));
    try expect(pipe.isIndexFull(3));

    try expectEqual(32, pipe.next());
    try expect(!pipe.isFull());

    try expect(!pipe.isIndexFull(0));
    try expect(!pipe.isIndexFull(1));
    try expect(pipe.isIndexFull(2));
    try expect(!pipe.isIndexFull(3));

    try expectEqual(null, pipe.next());
    try expect(!pipe.isFull());

    try expect(!pipe.isIndexFull(0));
    try expect(pipe.isIndexFull(1));
    try expect(!pipe.isIndexFull(2));
    try expect(!pipe.isIndexFull(3));

    try expectError(error.IndexFull, pipe.schedule(1, 0));

    try expectEqual(null, pipe.next());
    try expect(!pipe.isFull());

    try expect(pipe.isIndexFull(0));
    try expect(!pipe.isIndexFull(1));
    try expect(!pipe.isIndexFull(2));
    try expect(!pipe.isIndexFull(3));

    try expectEqual(7, pipe.next());
    try expect(!pipe.isFull());

    for (0..4) |i| {
        try expect(!pipe.isIndexFull(@intCast(i)));
    }

    for (0..4) |i| {
        try pipe.schedule(@intCast(i), @intCast(i));
    }

    try expect(pipe.isFull());
}
