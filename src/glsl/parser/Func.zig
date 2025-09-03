const std = @import("std");
const parser = @import("../parser.zig");
const Type = parser.Type;
const Primitive = parser.Primitive;
const Token = parser.Token;
const Tokenizer = parser.Tokenizer;

const ReadError = Tokenizer.Error || error{
    ExpectedArg,
    ExpectedArgType,
    ExpectedArgName,
};

pub const Arg = struct {
    const Self = @This();

    name: []const u8,
    type: Type,
    in: bool = true,
    out: bool = false,

    pub fn read(iter: *Tokenizer) ReadError!?Self {
        var self = Self{
            .name = undefined,
            .type = undefined,
        };

        var qualified = false;
        var tok: Token = try iter.next();

        // Reading the type qualifiers.
        while (true) {
            switch (tok.tag) {
                .identifier => break,
                .keyword_const => self.type.constant = true,
                .keyword_in => self.in = true,
                .keyword_out => self.out = true,
                .keyword_inout => {
                    self.in = true;
                    self.out = true;
                },
                else => if (qualified) {
                    return error.ExpectedArg;
                } else {
                    iter.back(tok);
                    return null;
                },
            }

            qualified = true;
            tok = try iter.next();
        }

        self.type.primitive = Primitive.read(iter.getSrc(tok)) orelse {
            return error.ExpectedArgType;
        };

        tok = try iter.next();
        if (tok.tag != .identifier) {
            return error.ExpectedArgName;
        }

        self.name = iter.getSrc(tok);
        return self;
    }
};

name: []const u8,
return_type: Type,
args: []const Arg,

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "arg read" {
    const Pair = struct { ReadError!?Arg, [:0]const u8 };
    const results = [_]Pair{
        .{ .{
            .name = "a",
            .type = .{ .primitive = .int },
            .in = false,
            .out = false,
        }, "int a" },
        .{ .{
            .name = "arg_0",
            .type = .{ .constant = true, .primitive = .vec3 },
            .in = true,
            .out = true,
        }, "const inout vec3 arg_0" },
        .{ error.ExpectedArg, "const" },
        .{ error.ExpectedArgName, "int" },
        .{ error.ExpectedArgName, "const inout vec3 0" },
        .{ error.ExpectedArgType, "const abc" },
        .{ null, "," },
        .{ null, ")" },
        .{ null, ";" },
    };

    for (results) |r| {
        var iter = Tokenizer.from(r[1]);
        const arg = Arg.read(&iter) catch |err| {
            try expectEqual(r[0], err);
            continue;
        } orelse {
            try expectEqual(r[0], null);
            continue;
        };

        try expectEqualSlices(u8, (try r[0]).?.name, arg.name);
    }
}
