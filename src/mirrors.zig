const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

const root = @import("main.zig");
const Cli = @import("Cli.zig");
const simple = @import("simple.zig");
const cache_dir_path = root.cacheDir();

pub const community_mirrors_url = "https://ziglang.org/download/community-mirrors.txt";
pub const local_filename = "community-mirrors.txt";

pub fn communityMirror(allocator: Allocator, io: Io, exe_dir: []const u8) ![]u8 {
    const content = ctt: {
        if (try checkLocal(allocator, io, exe_dir)) |file| {
            break :ctt try simple.readAll(allocator, io, file);
        } else {
            const content = try simple.tinyGet(allocator, io, community_mirrors_url);

            const local_path = try std.fs.path.join(allocator, &.{ exe_dir, local_filename });
            defer allocator.free(local_path);
            const local = try std.Io.Dir.cwd().createFile(io, local_path, .{});
            defer local.close(io);
            try local.writeStreamingAll(io, content);

            break :ctt content;
        }
    };
    defer allocator.free(content);

    var tokens = std.mem.tokenizeScalar(u8, content, '\n');
    var mirrors: std.ArrayList([]const u8) = try .initCapacity(allocator, 16);
    defer mirrors.deinit(allocator);
    while (tokens.next()) |mirror| {
        try mirrors.append(allocator, mirror);
    }
    const idx = std.crypto.random.intRangeLessThan(usize, 0, mirrors.items.len);
    return try allocator.dupe(u8, mirrors.items[idx]);
}

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
