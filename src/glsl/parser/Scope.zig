const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("../parser.zig");
const Tokenizer = parser.Tokenizer;
const Var = parser.@"var";

const Self = @This();

parent: ?*Self = null,
variables: std.StringHashMap(Var.Id),

pub fn getVar(self: Self, name: []const u8) ?Var.Id {
    if (self.variables.get(name)) |v| {
        return v;
    }

    return if (self.parent) |p| p.getVar(name) else null;
}

pub fn addVar(self: *Self, name: []const u8, id: Var.Id) Allocator.Error!void {
    try self.variables.putNoClobber(name, id);
}
