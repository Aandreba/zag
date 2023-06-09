const std = @import("std");
const zag = @import("src/parse.zig");
const json = std.json;

pub fn processZag(b: anytype) !void {
    return processZagWithFile(b, "zag.json");
}

pub fn processZagWithFile(b: anytype, file_path: []const u8) !void {
    const B: type = @typeInfo(@TypeOf(b)).Pointer.child;

    const file = try zag.ZagFile.parse(std.heap.page_allocator, file_path);
    defer file.deinit();

    const deps = try file.importDeps();
    defer {
        for (deps) |dep| file.alloc.free(dep.source.path);
        file.alloc.free(deps);
    }

    for (deps) |pkg| {
        std.debug.print("Imported {s}\n", .{pkg.name});
        B.addPackage(b, pkg);
    }
}

test "generate file" {
    const file = try zag.ZagFile.parse(std.testing.allocator, "zag.json");
    defer file.deinit();

    const deps = try file.importDeps();
    for (deps) |dep| std.debug.print("{s}\n", .{dep.source.path});

    defer {
        for (deps) |dep| file.alloc.free(dep.source.path);
        file.alloc.free(deps);
    }
}
