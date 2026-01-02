const std = @import("std");
const Allocator = std.mem.Allocator;
const stem = std.fs.path.stem;

const root = @import("main.zig");
const cache_dir_path = root.cache_dir_path;
const mirror = root.mirror;

pub fn obtainZig(
    allocator: Allocator,
    io: std.Io,
    filename: []const u8,
    exe_dir: []const u8,
) !void {
    const cache_path = try obtainCachePath(allocator, io, filename);
    defer allocator.free(cache_path);

    const target_dir_raw = try std.fs.path.join(allocator, &.{ exe_dir, filename });
    defer allocator.free(target_dir_raw);
    const target_dir = stem(stem(target_dir_raw));

    try execChildProcess(allocator, io, &.{
        "tar",
        "-xf",
        cache_path,
        "-C",
        target_dir,
    });
}

pub fn obtainCachePath(allocator: Allocator, io: std.Io, filename: []const u8) ![]const u8 {
    const cache_path = try std.fs.path.join(
        allocator,
        &.{ cache_dir_path, filename },
    );
    const open_result = std.Io.Dir.openFileAbsolute(
        io,
        cache_path,
        .{ .mode = .read_write },
    );
    if (open_result) |_| {} else |err| {
        if (err != error.FileNotFound) return err else {
            try ensureCacheDir(io);

            const url = try std.fs.path.join(allocator, &.{ mirror, filename });
            defer allocator.free(url);

            _ = try execChildProcess(allocator, io, &.{ "wget", url, "-P", cache_dir_path });
        }
    }

    return cache_path;
}

pub fn ensureCacheDir(io: std.Io) !void {
    std.Io.Dir.createDirAbsolute(
        io,
        cache_dir_path,
        std.Io.File.Permissions.default_dir,
    ) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
}

pub fn execChildProcess(
    allocator: Allocator,
    io: std.Io,
    argv: []const []const u8,
) !std.process.Child.Term {
    var child: std.process.Child = .init(argv, allocator);

    var stdout = try std.ArrayList(u8).initCapacity(allocator, 128);
    var stderr = try std.ArrayList(u8).initCapacity(allocator, 128);
    defer stdout.deinit(allocator);
    defer stderr.deinit(allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.collectOutput(
        allocator,
        &stdout,
        &stderr,
        std.math.maxInt(usize),
    );

    return try child.spawnAndWait(io);
}
