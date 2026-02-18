pub const operation = @import("ir/operation.zig");
pub const Block = @import("ir/Block.zig");
pub const Value = @import("ir/Value.zig");
pub const Range = @import("ir/Range.zig");
pub const Pipeline = @import("ir/pipeline.zig").Pipeline;

const glsl = @import("glsl.zig");
const Type = glsl.Type;
const Primitive = glsl.Primitive;

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Val = struct {
    pub const Id = u32;

    id: Id,
};

pub const Label = struct {
    pub const Id = u32;

    id: Id,
};

pub const Inst = union(enum) {
    const Self = @This();

    pub const Store = struct {
        dest: Val.Id,
        source: Val.Id,
    };

    pub const Call = struct {
        fn_name: []const u8,
    };

    pub const CondBranch = struct {
        value: Val.Id,
        on_true: Label.Id,
        on_false: Label.Id,
    };

    pub const Constant = union(Primitive) {
        bool: bool,
        int: i32,
        uint: u32,
        float: f32,
        double: f64,

        bvec2: @Vector(2, bool),
        bvec3: @Vector(3, bool),
        bvec4: @Vector(4, bool),

        ivec2: @Vector(2, i32),
        ivec3: @Vector(3, i32),
        ivec4: @Vector(4, i32),

        uvec2: @Vector(2, u32),
        uvec3: @Vector(3, u32),
        uvec4: @Vector(4, u32),

        vec2: @Vector(2, f32),
        vec3: @Vector(3, f32),
        vec4: @Vector(4, f32),

        dvec2: @Vector(2, f64),
        dvec3: @Vector(3, f64),
        dvec4: @Vector(4, f64),

        pub fn isZero(self: @This()) bool {
            return switch (self) {
                .bool => |v| !v,
                .int => |v| v == 0,
                .uint => |v| v == 0,
                .float => |v| v == 0,
                .double => |v| v == 0,
                else => false,
            };
        }

        pub fn isOne(self: @This()) bool {
            return switch (self) {
                .bool => |v| v,
                .int => |v| v == 1,
                .uint => |v| v == 1,
                .float => |v| v == 1,
                .double => |v| v == 1,
                else => false,
            };
        }

        pub fn isNegOne(self: @This()) bool {
            return switch (self) {
                .int => |v| v == -1,
                .float => |v| v == -1,
                .double => |v| v == -1,
                else => false,
            };
        }
    };

    alloca: Type,
    free: Val.Id,

    load: Val.Id,
    store: Store,

    num: Constant,
    expr: operation.Op,

    ret: Val.Id,
    call: Call,
    label: Label.Id,
    branch: Label.Id,
    cond_branch: CondBranch,

    pub fn isBranch(self: Self) bool {
        return switch (self) {
            .branch, .cond_branch, .ret => true,
            else => false,
        };
    }

    /// Checks if this instruction uses the supplied value.
    ///
    /// This doesn't check if this instruction is setting the supplied value,
    /// only if it's using the value.
    pub fn usesVal(self: Self, val: Val.Id) bool {
        return switch (self) {
            .load => |v| v == val,
            .store => |s| s.source == val,
            .expr => |e| e.usesVal(val),
            .ret => |e|  e == val,
            else => false,
        };
    }
};

pub const InstReader = struct {
    const Self = @This();

    buffer: []const Inst,
    index: usize,

    pub fn next(self: *Self) ?Inst {
        if (self.index == self.buffer.len) {
            return null;
        }

        const inst = self.buffer[self.index];
        self.index += 1;
        return inst;
    }
};

pub fn instReader(buffer: []const Inst) InstReader {
    return .{
        .buffer = buffer,
        .index = 0,
    };
}

pub const InstWriter = struct {
    const Self = @This();

    buffer: std.ArrayList(Inst) = .{},

    pub fn write(
        self: *Self,
        allocator: Allocator,
        inst: Inst,
    ) Allocator.Error!Val.Id {
        try self.buffer.append(allocator, inst);
        return @intCast(self.buffer.items.len - 1);
    }
};

const debug_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "uses value" {
    const Test = struct{ bool, Inst, Val.Id };
    const tests = [_]Test{
        .{ false, .{ .ret = 4 }, 0 },
        .{ true, .{ .ret = 4 }, 4 },
        .{ false, .{ .load = 100 }, 3 },
        .{ true, .{ .load = 10 }, 10 },
        .{ false, .{ .free = 2 }, 2 },
        .{ true, .{ .expr = .{ .add = .{ 0, 2 } }}, 2 },
        .{ false, .{ .expr = .{ .add = .{ 0, 2 } }}, 3 },
        .{ true, .{ .expr = .{ .bnot = 10 }}, 10 },
        .{ true, .{ .store = .{ .dest = 0, .source = 1 }}, 1 },
        .{ false, .{ .store = .{ .dest = 0, .source = 1 }}, 2 },
        .{ false, .{ .store = .{ .dest = 2, .source = 1 }}, 2 },
    };

    for (tests) |t| {
        try expectEqual(t[0], t[1].usesVal(t[2]));
    }
}

test "inst reader" {
    const insts = [_]Inst{
        .{ .num = .{ .int = 5 } },
        .{ .alloca = .{ .primitive = .vec3 } },
        .{ .num = .{ .vec3 = @splat(5.0) } },
    };

    var reader = instReader(&insts);
    for (insts) |inst| {
        try expectEqual(inst, reader.next());
    }

    try expectEqual(null, reader.next());
}

test "inst writer" {
    const insts = [_]Inst{
        .{ .num = .{ .vec2 = @splat(1.0) } },
        .{ .alloca = .{ .primitive = .bool } },
        .{ .label = 5 },
    };

    var writer = InstWriter{};
    for (insts, 0..) |inst, i| {
        try expectEqual(i, try writer.write(debug_allocator, inst));
    }

    const slice = try writer.buffer.toOwnedSlice(debug_allocator);
    defer debug_allocator.free(slice);

    try expectEqualSlices(Inst, &insts, slice);
}
