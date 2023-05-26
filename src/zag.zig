const std = @import("std");
const json = std.json;

const MAX_DEPTH = 256;
pub const DepsMap = std.StringArrayHashMapUnmanaged(ZagDep);

/// Zag file
pub const ZagFile = struct {
    deps: DepsMap = DepsMap{},
    alloc: std.mem.Allocator,

    pub fn serialize(
        comptime OutStream: type,
        comptime max_depth: usize,
        self: *const ZagFile,
        stream: *json.WriteStream(OutStream, max_depth),
    ) !void {
        try stream.beginObject();

        try stream.objectField("deps");
        try stream.beginObject();

        var iter = self.deps.iterator();
        while (iter.next()) |entry| {
            try stream.objectField(entry.key_ptr);
            try entry.value_ptr.serialize(OutStream, max_depth, stream);
        }
        try stream.endObject();

        try stream.endObject();
    }

    pub fn deinit(self: ZagFile) void {
        var iter = self.deps.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit(self.alloc);
        }

        var this = self;
        this.deps.deinit(self.alloc);
    }
};

// Zag dependency
pub const ZagDep = struct {
    repo: []const u8,
    version: Version,
    entry: ?[]const u8 = null,

    pub fn serialize(
        comptime OutStream: type,
        comptime max_depth: usize,
        self: *const ZagDep,
        stream: *json.WriteStream(OutStream, max_depth),
    ) !void {
        try stream.beginObject();

        try stream.objectField("repo");
        try stream.emitString(self.repo);

        try stream.objectField("version");
        try self.version.serialize(OutStream, max_depth, &self.version, stream);

        if (self.entry) |entry| {
            try stream.objectField("entry");
            try stream.emitString(entry);
        }

        try stream.endObject();
    }

    pub fn deinit(self: ZagDep, alloc: std.mem.Allocator) void {
        alloc.free(self.repo);
        self.version.deinit(alloc);
        if (self.entry) |entry| alloc.free(entry);
    }
};

pub const Version = union(enum) {
    version: std.SemanticVersion,
    branch: []const u8,

    pub fn serialize(
        comptime OutStream: type,
        comptime max_depth: usize,
        self: *const Version,
        stream: *json.WriteStream(OutStream, max_depth),
    ) !void {
        return switch (self) {
            Version.version => |version| {
                const result = std.ArrayList(u8).init(std.heap.page_allocator);
                defer result.deinit();

                try std.SemanticVersion.format(version, "", .{}, result.writer());
                stream.emitString(result.items);
            },
            Version.branch => |branch| stream.emitString(branch),
        };
    }

    pub fn deinit(self: Version, alloc: std.mem.Allocator) void {
        switch (self) {
            Version.version => |version| {
                if (version.pre) |pre| alloc.free(pre);
                if (version.build) |build| alloc.free(build);
            },
            Version.branch => |branch| alloc.free(branch),
        }
    }
};
