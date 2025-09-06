const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("../parser.zig");
const Type = parser.Type;
const Tokenizer = parser.Tokenizer;
const Scope = parser.Scope;
const ir = @import("../ir.zig");
const InstWriter = ir.InstWriter;

pub const Id = ir.Val.Id;

const Self = @This();

pub const Error = Allocator.Error || Type.ReadError || error{
    ExpectedVarName,
};

pub fn parse(
    allocator: Allocator,
    iter: *Tokenizer,
    scope: *Scope,
    writer: *InstWriter,
) Error!?Id {
    const t = try Type.read(iter) orelse return null;

    const tok = try iter.next();
    if (tok.tag != .identifier) {
        return error.ExpectedVarName;
    }

    const id = try writer.write(allocator, .{ .alloca = t });
    try scope.addVar(iter.getSrc(tok), id);
    return id;
}

const debug_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test parse {
    const Expected = struct { Id, []const u8, Type };
    const Pair = struct { Error!?Expected, [:0]const u8 };
    const tests = [_]Pair{
        .{
            .{ 0, "flag", .{ .constant = true, .primitive = .bool } },
            "const bool flag",
        },
        .{
            .{ 1, "abc", .{ .constant = true, .primitive = .bvec3 } },
            "const bvec3 abc",
        },
        .{
            .{ 2, "var", .{ .constant = false, .primitive = .float } },
            "float var = 5",
        },
        .{ error.ExpectedType, "const" },
        .{ error.ExpectedVarName, "int" },
        .{ null, "" },
        .{ null, "=" },
        .{ null, ";" },
        .{ null, "abc" },
    };

    var writer = InstWriter{};
    defer writer.buffer.deinit(debug_allocator);

    var scope = Scope{ .variables = .init(debug_allocator) };
    defer scope.variables.deinit();

    for (tests) |r| {
        var iter = Tokenizer.from(r[1]);
        const id = parse(debug_allocator, &iter, &scope, &writer) catch |err| {
            try expectEqual(r[0], err);
            continue;
        } orelse {
            try expectEqual(r[0], null);
            continue;
        };

        const r_id, const name, const t = (try r[0]).?;
        try expectEqual(r_id, id);
        try expectEqual(r_id, scope.getVar(name));

        const inst = writer.buffer.items[id];
        try expectEqual(t, inst.alloca);
    }
}
