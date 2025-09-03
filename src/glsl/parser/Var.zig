const std = @import("std");
const parser = @import("../parser.zig");
const Type = parser.Type;
const Tokenizer = parser.Tokenizer;

pub const Id = u32;

const Self = @This();

name: []const u8,
type: Type,

pub const ReadError = Type.ReadError || error{
    ExpectedVarName,
};

pub fn read(iter: *Tokenizer) ReadError!?Self {
    var self: Self = undefined;
    self.type = try Type.read(iter) orelse {
        return null;
    };

    const tok = try iter.next();
    if (tok.tag != .identifier) {
        return error.ExpectedVarName;
    }

    self.name = iter.getSrc(tok);
    return self;
}

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "var read" {
    const Pair = struct { ReadError!?Self, [:0]const u8 };
    const results = [_]Pair{
        .{ .{
            .name = "flag",
            .type = .{ .constant = true, .primitive = .bool },
        }, "const bool flag;" },
        .{ .{
            .name = "abc",
            .type = .{ .constant = true, .primitive = .bvec3 },
        }, "const bvec3 abc" },
        .{ .{
            .name = "var",
            .type = .{ .primitive = .float },
        }, "float var = 5;" },
        .{ error.ExpectedType, "const" },
        .{ error.ExpectedVarName, "int" },
        .{ null, "" },
        .{ null, "=" },
        .{ null, ";" },
        .{ null, "abc" },
    };

    for (results) |r| {
        var iter = Tokenizer.from(r[1]);
        const arg = read(&iter) catch |err| {
            try expectEqual(r[0], err);
            continue;
        } orelse {
            try expectEqual(r[0], null);
            continue;
        };

        try expectEqualSlices(u8, (try r[0]).?.name, arg.name);
    }
}
