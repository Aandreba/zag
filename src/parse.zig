const std = @import("std");
const json = std.json;

const JsonReader = @import("json.zig").Reader;
pub const DepsMap = std.StringArrayHashMapUnmanaged(ZagDep);

pub const ZagError = error{MissingField};
const MAX_DEPTH = 256;

/// Zag file
pub const ZagFile = struct {
    dir: ?[]const u8,
    deps: DepsMap = DepsMap{},
    bytes: []const u8,
    alloc: std.mem.Allocator,

    pub fn importDeps(self: *const ZagFile) ![]std.build.Pkg {
        const dir = self.dir orelse "zag-modules";
        std.fs.cwd().makeDir(dir) catch |e| {
            if (e != error.PathAlreadyExists) return e;
        };

        const fs_dir = try std.fs.cwd().openDir(dir, .{});
        var result = try self.alloc.alloc(std.build.Pkg, self.deps.count());
        errdefer self.alloc.free(result);

        var i: usize = 0;
        var iter = self.deps.iterator();
        while (iter.next()) |entry| {
            result[i] = try entry.value_ptr.import(self.alloc, entry.key_ptr.*, dir, fs_dir);
            i += 1;
        }

        return result;
    }

    pub fn parse(alloc: std.mem.Allocator, path: []const u8) !ZagFile {
        const cwd = std.fs.cwd();

        // Read file contents
        const file = try cwd.readFileAlloc(alloc, path, std.math.maxInt(usize));
        errdefer alloc.free(file);

        var reader = JsonReader.init(json.TokenStream.init(file));
        var deps = DepsMap{};
        var dir: ?[]const u8 = null;

        try reader.beginObject();
        while (true) {
            const peek = try reader.peekToken();
            if (peek.* == .ObjectEnd) break;

            const key = try reader.parseString();
            if (std.mem.eql(u8, key, "dir")) {
                dir = try reader.parseString();
            } else if (std.mem.eql(u8, key, "deps")) {
                deps = DepsMap{};
                errdefer deps.deinit(alloc);

                try reader.beginObject();
                while (true) {
                    const deps_peek = try reader.peekToken();
                    if (deps_peek.* == .ObjectEnd) break;

                    const name = try reader.parseString();
                    const value = try ZagDep.parse(&reader);
                    try deps.put(alloc, name, value);
                }
                try reader.endObject();
            } else {
                std.log.warn("Unknown field: '{s}'\n", .{key});
            }
        }
        try reader.endObject();

        return ZagFile{
            .dir = dir,
            .deps = deps,
            .bytes = file,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: ZagFile) void {
        var this = self;
        this.deps.deinit(self.alloc);
        self.alloc.free(self.bytes);
    }
};

// Zag dependency
pub const ZagDep = struct {
    repo: []const u8,
    version: std.SemanticVersion,
    version_str: []const u8,
    entry: ?[]const u8 = null,

    pub fn import(self: *const ZagDep, alloc: std.mem.Allocator, name: []const u8, dir: []const u8, fs_dir: std.fs.Dir) !std.build.Pkg {
        // Path for the repo
        var target_path = std.ArrayList(u8).init(alloc);
        defer target_path.deinit();
        try std.fmt.format(target_path.writer(), "{s}/{s}", .{ dir, name });

        var target_dir_fs = fs_dir.openDir(name, .{}) catch |e| {
            // Clone repo
            if (e == error.FileNotFound) {
                const argv = [_][]const u8{
                    "git",
                    "clone",
                    "--branch",
                    self.version_str,
                    self.repo,
                    name,
                };
                var clone_process = std.ChildProcess.init(&argv, alloc);
                clone_process.stdout_behavior = .Close;
                clone_process.cwd = dir;

                switch (try clone_process.spawnAndWait()) {
                    .Exited => |ex| if (ex == 0) {} else return error.Unexpected,
                    else => return error.Unexpected,
                }

                // Entry point
                const relative_path = if (self.entry) |entry| entry else "src/main.zig";
                try std.fmt.format(target_path.writer(), "{s}/{s}", .{ target_path.toOwnedSlice(), relative_path });

                return std.build.Pkg{
                    .name = name,
                    .source = std.build.FileSource.relative(target_path.toOwnedSlice()),
                    .dependencies = null,
                };
            }
            return e;
        };
        target_dir_fs.close();

        // Checkout verion tag
        const argv = [_][]const u8{
            "git",
            "checkout",
            self.version_str,
        };
        var checkout_process = std.ChildProcess.init(&argv, alloc);
        checkout_process.stdout_behavior = .Close;
        checkout_process.cwd = target_path.items;

        switch (try checkout_process.spawnAndWait()) {
            .Exited => |ex| if (ex == 0) {} else return error.Unexpected,
            else => return error.Unexpected,
        }

        const relative_path = if (self.entry) |entry| entry else "src/main.zig";
        try std.fmt.format(target_path.writer(), "{s}/{s}", .{ target_path.toOwnedSlice(), relative_path });

        return std.build.Pkg{
            .name = name,
            .source = std.build.FileSource.relative(target_path.toOwnedSlice()),
            .dependencies = null,
        };
    }

    pub fn parse(reader: *JsonReader) !ZagDep {
        var repo: ?[]const u8 = null;
        var version: ?std.SemanticVersion = null;
        var version_str: ?[]const u8 = null;
        var entry: ?[]const u8 = null;

        try reader.beginObject();
        while (true) {
            const peek = try reader.peekToken();
            if (peek.* == .ObjectEnd) break;

            const key = try reader.parseString();
            if (std.mem.eql(u8, key, "repo")) {
                repo = try reader.parseString();
            } else if (std.mem.eql(u8, key, "version")) {
                const parsed_version = try reader.parseString();
                version_str = parsed_version;
                version = try std.SemanticVersion.parse(if (parsed_version[0] == 'v') parsed_version[1..] else parsed_version);
            } else if (std.mem.eql(u8, key, "entry")) {
                entry = try reader.parseString();
            } else {
                std.log.warn("Unknown field: '{s}'\n", .{key});
            }
        }
        try reader.endObject();

        return ZagDep{
            .repo = repo orelse return ZagError.MissingField,
            .version = version orelse return ZagError.MissingField,
            .version_str = version_str orelse return ZagError.MissingField,
            .entry = entry,
        };
    }
};
