const std = @import("std");
const zag = @import("zag.zig");
const json = std.json;

pub fn main() !void {}

test "generate file" {
    const file = try zag.ZagFile.parse(std.testing.allocator, "example.json");
    defer file.deinit();

    const deps = try file.importDeps();
    defer file.alloc.free(deps);
}
