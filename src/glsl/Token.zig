const std = @import("std");

tag: Tag,
loc: Loc,

pub const Loc = struct {
    start: usize,
    end: usize,
};

pub const Tag = enum {
    const Self = @This();

    identifier,
    number,

    l_paren,
    r_paren,

    l_bracket,
    r_bracket,

    l_brace,
    r_brace,

    semicolon,
    period,
    comma,

    plus,
    plus_plus,
    plus_equal,

    minus,
    minus_minus,
    minus_equal,

    asterisk,
    asterisk_equal,

    slash,
    slash_equal,

    equal,
    equal_equal,
    bang_equal,

    angle_bracket_left,
    angle_bracket_left_equal,

    angle_bracket_right,
    angle_bracket_right_equal,

    keyword_in,
    keyword_out,
    keyword_inout,
    keyword_const,
    keyword_return,

    keyword_if,
    keyword_else,

    eof,

    pub fn isKeyword(self: Self) bool {
        return switch (self) {
            .keyword_in,
            .keyword_out,
            .keyword_inout,
            .keyword_const,
            .keyword_return,
            => return true,
            else => return false,
        };
    }

    const keyword_map = std.StaticStringMap(Tag).initComptime(.{
        .{ "in", .keyword_in },
        .{ "out", .keyword_out },
        .{ "inout", .keyword_inout },
        .{ "const", .keyword_const },
        .{ "return", .keyword_return },
        .{ "if", .keyword_if },
        .{ "else", .keyword_else },
    });

    pub fn getKeyword(str: []const u8) ?Self {
        return keyword_map.get(str);
    }

    pub fn toString(self: Self) ?[]const u8 {
        return switch (self) {
            .identifier => null,
            .number => null,
            .l_paren => "(",
            .r_paren => ")",
            .l_bracket => "[",
            .r_bracket => "]",
            .l_brace => "{",
            .r_brace => "}",
            .semicolon => ";",
            .period => ".",
            .comma => ",",
            .plus => "+",
            .plus_plus => "++",
            .plus_equal => "+=",
            .minus => "-",
            .minus_minus => "--",
            .minus_equal => "-=",
            .asterisk => "*",
            .asterisk_equal => "*=",
            .slash => "/",
            .slash_equal => "/=",
            .equal => "=",
            .equal_equal => "==",
            .bang_equal => "!=",
            .angle_bracket_left => "<",
            .angle_bracket_right => ">",
            .angle_bracket_left_equal => "<=",
            .angle_bracket_right_equal => ">=",
            .keyword_in => "in",
            .keyword_out => "out",
            .keyword_inout => "inout",
            .keyword_const => "const",
            .keyword_return => "return",
            .keyword_if => "if",
            .keyword_else => "else",
            .eof => "eof",
        };
    }
};

const expectEqualSlices = std.testing.expectEqualSlices;

test "tag to string" {
    try expectEqualSlices(u8, "const", Tag.keyword_const.toString().?);
    try expectEqualSlices(u8, "--", Tag.minus_minus.toString().?);
    try expectEqualSlices(u8, "+", Tag.plus.toString().?);
    try expectEqualSlices(u8, "-", Tag.minus.toString().?);
    try expectEqualSlices(u8, "if", Tag.keyword_if.toString().?);
}
