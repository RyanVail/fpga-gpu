pub const operation = @import("ir/operation.zig");
pub const Type = parser.Type;
pub const Block = @import("ir/Block.zig");

const std = @import("std");
const assert = std.debug.assert;
const parser = @import("parser.zig");
const Primitive = parser.Primitive;

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

    pub const Branch = struct {
        label: Label.Id,
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
                .@"bool" => |v| !v,
                .int => |v| v == 0,
                .uint => |v| v == 0,
                .float => |v| v == 0,
                .double => |v| v == 0,
                else => false,
            };
        }

        pub fn isOne(self: @This()) bool {
            return switch (self) {
                .@"bool" => |v| v,
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
    load: Val.Id,
    store: Store,
    expr: operation.Op,
    label: Label.Id,
    call: Call,
    branch: Branch,
    cond_branch: CondBranch,
    ret: Val.Id,
    num: Constant,

    pub fn isBranch(self: Self) bool {
        return switch (self) {
            .branch, .cond_branch, .ret => true,
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

const expectEqual = std.testing.expectEqual;

test "inst reader" {
    const insts = [_]Inst{
        .{ .num = .{ .int = 5 } },
        .{ .alloca = .{ .primitive = .vec3} },
        .{ .num = .{ .vec3 = @splat(5.0) } },
    };

    var reader = instReader(&insts);
    for (insts) |inst| {
        try expectEqual(inst, reader.next());
    }

    try expectEqual(null, reader.next());
}
