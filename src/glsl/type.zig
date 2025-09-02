const std = @import("std");

const glsl = @import("../glsl.zig");
const parser = glsl.parser;

pub const Type = struct {
    const Self = @This();

    constant: bool = false,
    primitive: Primitive,

    pub const GetError = error{
        ExpectedType,
    };

    pub fn get(iter: *parser.TokenIter) GetError!?Self {
        var self = Self{ .primitive = undefined };

        var str = iter.peek() orelse return null;
        if (std.mem.eql(u8, str, "const")) {
            _ = iter.next() orelse unreachable;
            self.constant = true;

            str = iter.peek() orelse return error.ExpectedType;
        }

        self.primitive = Primitive.get(str) orelse {
            return if (self.constant) error.ExpectedType else null;
        };

        _ = iter.next() orelse unreachable;
        return self;
    }
};

pub const Primitive = enum {
    const Self = @This();

    // TODO: This is slow.
    const map = b: {
        const fields = @typeInfo(Self).@"enum".fields;

        const KV = struct { []const u8, Self };
        var pairs: [fields.len]KV = undefined;
        for (fields, &pairs) |field, *pair| {
            const val: Self = @enumFromInt(field.value);
            pair.* = .{ val.toString(), val };
        }

        break :b std.StaticStringMap(Self).initComptime(pairs);
    };

    @"bool",
    int,
    uint,
    float,
    double,

    bvec2,
    bvec3,
    bvec4,

    ivec2,
    ivec3,
    ivec4,

    uvec2,
    uvec3,
    uvec4,

    vec2,
    vec3,
    vec4,

    dvec2,
    dvec3,
    dvec4,

    pub fn get(tok: []const u8) ?Self {
        return map.get(tok);
    }

    pub fn toString(self: Self) []const u8 {
        return switch (self) {
            inline else => |t| {
                return @tagName(t);
            }
        };
    }
};

const expectEqual = std.testing.expectEqual;

test "primitive get" {
    const Pair = struct { ?Primitive, []const u8 };
    const results = [_]Pair{
        .{ .bool, "bool" },
        .{ .int, "int" },
        .{ .uint, "uint" },
        .{ null, "uit" },
        .{ null, "bool " },
        .{ .dvec2, "dvec2" },
        .{ .float, "float" },
        .{ null, "" },
        .{ .double, "double" },
        .{ .vec2, "vec2" },
        .{ null, "-double" },
    };

    for (results) |r| {
        try expectEqual(r[0], Primitive.get(r[1]));
    }
}

test "type get" {
    const Pair = struct { Type.GetError!?Type, []const u8 };
    const results = [_]Pair{
        .{ null, "" },
        .{ .{ .primitive = .int }, "int" },
        .{ .{ .constant = true, .primitive = .int }, "const int" },
        .{ .{ .constant = true, .primitive = .uint }, "const uint" },
        .{ error.ExpectedType, "const " },
        .{ error.ExpectedType, "const" },
        .{ null, "cost" },
        .{ null, "_vec3" },
        .{ .{ .primitive = .vec3 }, "vec3" },
        .{ .{ .constant = true, .primitive = .vec3 }, "const vec3" },
        .{ .{ .primitive = .bool }, "bool" },
        .{ .{ .constant = true, .primitive = .bool }, "const bool" },
        .{ error.ExpectedType, "const _" },
    };

    for (results) |r| {
        var iter = std.mem.tokenizeAny(u8, r[1], " ");
        try expectEqual(r[0], Type.get(&iter));
    }
}
