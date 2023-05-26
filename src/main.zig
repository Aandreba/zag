const std = @import("std");
const zag = @import("zag.zig");
const json = std.json;

pub fn main() !void {}

test "generate file" {
    var file = zag.ZagFile{
        .alloc = std.testing.allocator,
    };
    defer file.deinit();

    try file.deps.put(file.alloc, "alpha", zag.ZagDep{
        .version = zag.Version{
            .version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 },
        },
        .repo = "https://github.com/Aandreba/rzig",
    });

    const cwd = std.fs.cwd();

    var output = try cwd.openFile("zag.json", .{ .mode = .write_only });
    defer output.close();

    var stream = json.writeStream(output.writer(), 256);
    try zag.ZagFile.serialize(std.fs.File.Writer, 256, &file, &stream);
    try output.sync();
}
