const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

const simple = @import("simple.zig");

pub const index_url = "https://ziglang.org/download/index.json";
pub const Index = struct { master: struct { version: []const u8 } };

pub fn getMasterVersion(allocator: Allocator, io: Io, exe_dir: []const u8) ![]u8 {
    if (try checkLocal(allocator, io, exe_dir)) |file| {
        const content = try simple.readAll(allocator, io, file);
        defer allocator.free(content);

        const parsed_result = std.json.parseFromSlice(
            Index,
            allocator,
            content,
            .{ .ignore_unknown_fields = true },
        );
        if (parsed_result) |parsed| {
            defer parsed.deinit();
            return allocator.dupe(u8, parsed.value.master.version);
        } else |_| {}
    }

    const content = try simple.tinyGet(allocator, io, index_url);
    defer allocator.free(content);

    const local_path = try std.fs.path.join(allocator, &.{ exe_dir, local_filename });
    defer allocator.free(local_path);
    const local = try std.Io.Dir.cwd().createFile(io, local_path, .{});
    defer local.close(io);
    try local.writeStreamingAll(io, content);

    const parsed: std.json.Parsed(Index) = try std.json.parseFromSlice(
        Index,
        allocator,
        content,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    return allocator.dupe(u8, parsed.value.master.version);
}

pub const local_filename = "index.json";

pub fn checkLocal(allocator: Allocator, io: Io, exe_dir: []const u8) !?std.Io.File {
    const local_path = try std.fs.path.join(allocator, &.{ exe_dir, local_filename });
    defer allocator.free(local_path);
    const local = std.Io.Dir.cwd().openFile(
        io,
        local_path,
        .{ .mode = .read_write },
    ) catch |err| {
        if (err == error.FileNotFound) return null else return err;
    };
    return local;
}
