const std = @import("std");
const json = std.json;

pub const ReaderError = error{ UnexpectedEndOfJson, UnexpectedToken };

pub const Reader = struct {
    tokens: json.TokenStream,
    peek: ?json.Token = null,

    pub fn init(tokens: json.TokenStream) Reader {
        return .{ .tokens = tokens };
    }

    pub fn peekToken(self: *Reader) !*const json.Token {
        self.peek = try self.nextToken();
        return if (self.peek) |*ptr| ptr else unreachable;
    }

    pub fn nextToken(self: *Reader) !json.Token {
        if (self.peek) |token| {
            self.peek = null;
            return token;
        }

        const token = try self.tokens.next() orelse ReaderError.UnexpectedEndOfJson;
        return token;
    }

    pub fn parseOptional(self: *Reader, comptime T: type, comptime f: fn (*Reader) anyerror!T) !?T {
        switch (try self.nextToken()) {
            .Null => return null,
            else => |token| {
                self.peek = token;
                return f(self);
            },
        }
    }

    pub fn parseInt(comptime T: type, self: *Reader) !T {
        const token = try self.nextToken();
        switch (token) {
            .Number => |num| if (num.is_int) std.fmt.parseInt(T, num.slice(self.tokens.slice, self.tokens.i - 1), 10) else ReaderError.UnexpectedToken,
            else => unreachable,
        }
    }

    pub fn parseFloat(comptime T: type, self: *Reader) !T {
        const token = try self.nextToken();
        switch (token) {
            .Number => |num| std.fmt.parseInt(T, num.slice(self.tokens.slice, self.tokens.i - 1), 10),
            else => unreachable,
        }
    }

    pub fn parseString(self: *Reader) ![]const u8 {
        const token = try self.nextToken();
        return switch (token) {
            .String => |s| s.slice(self.tokens.slice, self.tokens.i - 1),
            else => ReaderError.UnexpectedToken,
        };
    }

    pub fn parseBool(self: *Reader) !bool {
        const token = try self.nextToken();
        return switch (token) {
            .True => true,
            .False => false,
            else => return ReaderError.UnexpectedToken,
        };
    }

    pub fn beginObject(self: *Reader) !void {
        const token = try self.nextToken();
        if (token != json.Token.ObjectBegin) return ReaderError.UnexpectedToken;
    }

    pub fn endObject(self: *Reader) !void {
        const token = try self.nextToken();
        if (token != json.Token.ObjectEnd) return ReaderError.UnexpectedToken;
    }

    pub fn beginArray(self: *Reader) !void {
        const token = try self.nextToken();
        if (token != json.Token.ArrayBegin) return ReaderError.UnexpectedToken;
    }

    pub fn endArray(self: *Reader) !void {
        const token = try self.nextToken();
        if (token != json.Token.ArrayEnd) return ReaderError.UnexpectedToken;
    }
};
