const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ir = @import("../ir.zig");
const Inst = ir.Inst;
const Label = ir.Label;
const InstReader = ir.InstReader;

const Self = @This();

pub const InstId = u32;

/// The id of the first value within this basic block.
first_val_id: u32 = 0,

/// The insts within this basic block.
insts: []Inst,

fn isValid(self: *const Self) bool {
    return switch (self.insts[self.getEnd()]) {
        .branch, .cond_branch, .ret => true,
        else => false,
    };
}

/// Reads a basic block from a stream of insts.
pub fn read(allocator: Allocator, reader: *InstReader) Allocator.Error!Self {
    var insts: std.ArrayList(Inst) = .{};
    while (reader.next()) |inst| {
        try insts.append(allocator, inst);
        if (inst.isBranch()) {
            break;
        }
    }

    const self = Self{ .insts = try insts.toOwnedSlice(allocator) };
    assert(self.isValid());
    return self;
}

/// Gets the instruction where a value is defined within this basic block or
/// `null` if the value is not defined within this basic block.
pub fn getValue(self: *const Self, id: ir.Val.Id) ?Inst {
    if (id < self.first_val_id) {
        return null;
    }

    if (id >= self.first_val_id + self.insts.len) {
        return null;
    }

    return self.insts[id - self.first_val_id];
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.free(self.insts);
}

/// Gets the last inst in this basic block.
///
/// This tag of the inst will either be `branch`, `cond_branch`, or `ret`.
pub fn getEnd(self: *const Self) InstId {
    const id: InstId = @intCast(self.insts.len - 1);
    return id;
}

const debug_allocator = std.testing.allocator;
const expectEqualSlices = std.testing.expectEqualSlices;

test read {
    const insts = [_]Inst{
        .{ .num = .{ .int = 5 } },
        .{ .alloca = .{ .primitive = .vec3} },
        .{ .num = .{ .vec3 = @splat(5.0) } },
        .{ .branch = .{ .label = 0 } },

        .{ .label = 0 },
        .{ .num = .{ .vec3 = @splat(2.0) } },
        .{ .store = .{ .dest = 0, .source = 1 } },
        .{ .ret = 0 },
    };

    var reader = ir.instReader(&insts);

    var b0 = try read(debug_allocator, &reader);
    defer b0.deinit(debug_allocator);
    try expectEqualSlices(Inst, insts[0..4], b0.insts);

    var b1 = try read(debug_allocator, &reader);
    defer b1.deinit(debug_allocator);
    try expectEqualSlices(Inst, insts[4..8], b1.insts);
}
