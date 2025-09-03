const std = @import("std");
const parser = @import("../parser.zig");
const Token = parser.Token;

const Self = @This();

pub const Error = error{
    UnexpectedChar,
};

buffer: []const u8,
index: usize = 0,

pub fn from(buffer: [:0]const u8) Self {
    return .{ .buffer = buffer[0..buffer.len + 1] };
}

const State = enum {
    start,
    identifier,
    number,
    number_decimal,
    plus,
    minus,
    asterisk,
    slash,
    equal,
    angle_bracket_left,
    angle_bracket_right,
};

pub fn next(self: *Self) Error!Token {
    var result: Token = .{
        .tag = undefined,
        .loc = .{
            .start = self.index,
            .end = undefined,
        },
    };

    state: switch (State.start) {
        .start => switch (self.buffer[self.index]) {
            0 => {
                if (self.index != self.buffer.len - 1) {
                    return error.UnexpectedChar;
                }

                return .{
                    .tag = .eof,
                    .loc = .{
                        .start = self.index,
                        .end = self.index + 1,
                    },
                };
            },
            ' ', '\n', '\r', '\t' => {
                self.index += 1;
                result.loc.start = self.index;
                continue :state .start;
            },
            'a'...'z', 'A'...'Z', '_', => {
                result.tag = .identifier;
                continue :state .identifier;
            },
            '0'...'9' => {
                result.tag = .number;
                continue :state .number;
            },
            '.' => {
                self.index += 1;
                result.tag = .period;
            },
            ',' => {
                self.index += 1;
                result.tag = .comma;
            },
            ';' => {
                self.index += 1;
                result.tag = .semicolon;
            },
            '(' => {
                self.index += 1;
                result.tag = .l_paren;
            },
            ')' => {
                self.index += 1;
                result.tag = .r_paren;
            },
            '[' => {
                self.index += 1;
                result.tag = .l_bracket;
            },
            ']' => {
                self.index += 1;
                result.tag = .r_bracket;
            },
            '{' => {
                self.index += 1;
                result.tag = .l_brace;
            },
            '}' => {
                self.index += 1;
                result.tag = .r_brace;
            },
            '!' => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        self.index += 1;
                        result.tag = .bang_equal;
                    },
                    else => return error.UnexpectedChar,
                }
            },
            '+' => continue :state .plus,
            '-' => continue :state .minus,
            '*' => continue :state .asterisk,
            '/' => continue :state .slash,
            '=' => continue :state .equal,
            '<' => continue :state .angle_bracket_left,
            '>' => continue :state .angle_bracket_right,
            else => return error.UnexpectedChar,
        },
        .plus => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '+' => {
                    self.index += 1;
                    result.tag = .plus_plus;
                },
                '=' => {
                    self.index += 1;
                    result.tag = .plus_equal;
                },
                else => result.tag = .plus,
            }
        },
        .minus => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '+' => {
                    self.index += 1;
                    result.tag = .minus_minus;
                },
                '=' => {
                    self.index += 1;
                    result.tag = .minus_equal;
                },
                else => result.tag = .minus,
            }
        },
        .asterisk => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    self.index += 1;
                    result.tag = .asterisk_equal;
                },
                else => result.tag = .asterisk,
            }
        },
        .slash => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    self.index += 1;
                    result.tag = .slash_equal;
                },
                else => result.tag = .slash,
            }
        },
        .equal => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    self.index += 1;
                    result.tag = .equal_equal;
                },
                else => result.tag = .equal,
            }
        },
        .angle_bracket_left => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    self.index += 1;
                    result.tag = .angle_bracket_left_equal;
                },
                else => result.tag = .angle_bracket_left,
            }
        },
        .angle_bracket_right => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '=' => {
                    self.index += 1;
                    result.tag = .angle_bracket_right_equal;
                },
                else => result.tag = .angle_bracket_right,
            }
        },
        .identifier => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => {
                    continue :state .identifier;
                },
                else => {
                    const str = self.buffer[result.loc.start..self.index];
                    if (Token.Tag.getKeyword(str)) |keyword| {
                        result.tag = keyword;
                    }
                },
            }
        },
        .number => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '0'...'9' => continue :state .number,
                '.' => continue :state .number_decimal,
                else => {},
            }
        },
        .number_decimal => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                '0'...'9' => continue :state .number_decimal,
                'f', 'F' => self.index += 1,
                else => {},
            }
        },
    }

    result.loc.end = self.index;
    return result;
}

const expectEqual = std.testing.expectEqual;

test "assignment expression" {
    const expected = [_]Token{
        .{ .tag = .keyword_const, .loc = .{ .start = 0, .end = 5 } },
        .{ .tag = .identifier, .loc = .{ .start = 6, .end = 9 } },
        .{ .tag = .identifier, .loc = .{ .start = 10, .end = 11 } },
        .{ .tag = .equal, .loc = .{ .start = 12, .end = 13 } },
        .{ .tag = .number, .loc = .{ .start = 14, .end = 15 } },
        .{ .tag = .semicolon, .loc = .{ .start = 15, .end = 16 } },
    };

    var iter = from("const int a = 5;");
    for (expected) |e| {
        try expectEqual(e, iter.next());
    }
}

test "integer" {
    const expected = [_]Token.Tag{
        .l_paren,
        .number,
        .comma,
        .number,
        .r_paren,
        .eof,
        .eof,
    };

    var iter = from("(100.00f, 5)");
    for (expected) |e| {
        try expectEqual(e, (try iter.next()).tag);
    }
}

test "function header" {
    const expected = [_]Token.Tag{
        .identifier,
        .identifier,
        .l_paren,
        .keyword_in,
        .identifier,
        .identifier,
        .comma,
        .keyword_out,
        .identifier,
        .identifier,
        .r_paren,
        .identifier,
        .l_brace,
        .r_brace,
        .eof,
        .eof,
    };

    var iter = from("void test(in float _a1, out vec3 b) int {}");
    for (expected) |e| {
        try expectEqual(e, (try iter.next()).tag);
    }
}

test "unexpected eof" {
    const expected = [_]Error!Token.Tag{
        .keyword_if,
        .l_paren,
        .identifier,
        .angle_bracket_left_equal,
        .number,
        .r_paren,
        error.UnexpectedChar
    };

    var iter = from("if (a <= 5.0)\x00 else {}");
    for (expected) |e| {
        const a = iter.next();
        _ = a catch |err| {
            try expectEqual(err, a);
            continue;
        };

        try expectEqual(e, (try a).tag);
    }
}

test "incorrect number" {
    const expected = [_]Error!Token.Tag{
        .number,
        .period,
        .number,
    };

    var iter = from("8.0.0");
    for (expected) |e| {
        try expectEqual(e, (try iter.next()).tag);
    }
}

test "function definition" {
    const expected = [_]Token.Tag{
        .identifier,
        .identifier,
        .l_paren,
        .keyword_in,
        .keyword_const,
        .identifier,
        .identifier,
        .comma,
        .keyword_out,
        .identifier,
        .identifier,
        .r_paren,
        .l_brace,
        .keyword_if,
        .l_paren,
        .identifier,
        .period,
        .identifier,
        .equal_equal,
        .identifier,
        .period,
        .identifier,
        .r_paren,
        .l_brace,
        .identifier,
        .period,
        .identifier,
        .asterisk_equal,
        .number,
        .semicolon,
        .r_brace,
        .r_brace,
        .eof,
        .eof,
    };

    var iter = from(
        \\void
        \\func(
        \\  in const vec3 a,
        \\  out vec3 b
        \\) {
        \\    if (a.x == b.x) {
        \\        b.x *= 0.5f;
        \\    }
        \\}
    );

    for (expected) |e| {
        try expectEqual(e, (try iter.next()).tag);
    }
}
