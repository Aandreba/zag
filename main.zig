const std = @import("std");
const zag = @import("src/zag.zig");
const json = std.json;

pub fn processZag(b: anytype, file_path: ?[]const u8) !void {
    const B: type = @typeInfo(@TypeOf(b)).Pointer.child;

    const file = try zag.ZagFile.parse(std.heap.page_allocator, if (file_path) |f| f else "zag.json");
    defer file.deinit();

    const deps = try file.importDeps();
    defer file.alloc.free(deps);
    for (deps) |pkg| B.addPackage(pkg);
}

test "generate file" {
    const file = try zag.ZagFile.parse(std.testing.allocator, "example.json");
    defer file.deinit();

    const deps = try file.importDeps();
    defer file.alloc.free(deps);
}
