const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const stem = std.fs.path.stem;

pub const Cli = @import("Cli.zig");
pub const mirrors = @import("mirrors.zig");
pub const index = @import("index.zig");
pub const simple = @import("simple.zig");

pub const zig_filename_prefix = "zig-x86_64-linux";
pub const zls_filename_prefix = "zls-x86_64-linux";
pub const file_extension = ".tar.xz";

/// Only support x86_64-linux
pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    var arena: std.heap.ArenaAllocator = .init(std.heap.smp_allocator);
    defer arena.deinit();
    const allocator = allocator: {
        if (builtin.mode == .Debug) break :allocator debug_allocator.allocator();
        break :allocator arena.allocator();
    };

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var cli = Cli.parse(allocator) catch |err| {
        if (err == Cli.Error.PrintHelp) return else return err;
    };
    defer cli.deinit(allocator);
    const version = try index.getMasterVersion(allocator, io, cli.exe_dir);
    defer allocator.free(version);

    const filename = switch (cli.mode) {
        .zig => try std.fmt.allocPrint(
            allocator,
            "{s}-{s}{s}",
            .{ zig_filename_prefix, version, file_extension },
        ),

        .zls => try std.fmt.allocPrint(
            allocator,
            "{s}-{s}{s}",
            .{ zls_filename_prefix, version, file_extension },
        ),
    };
    defer allocator.free(filename);

    if (!cli.forced) {
        if (try checkInstalled(allocator, io, cli.exe_dir, filename)) {
            std.log.info("Version '{s}' has been installed", .{version});
            return;
        }

        if (try checkCache(allocator, io, filename)) |cache_path| {
            std.log.info("Version '{s}' has been in caches", .{version});
            std.log.info("Extract cache", .{});
            _ = try simple.execProcess(
                allocator,
                io,
                &.{ "tar", "-xf", cache_path, "-C", cli.exe_dir },
            );
            return;
        }
    }

    std.log.info("Download version '{s}' to caches", .{version});
    const cache_path = try downloadCache(
        allocator,
        io,
        cli.mode,
        filename,
        cli.exe_dir,
    );
    defer allocator.free(cache_path);
    std.log.info("Extract cache", .{});
    _ = try simple.execProcess(
        allocator,
        io,
        &.{ "tar", "-xf", cache_path, "-C", cli.exe_dir },
    );
}

pub fn checkInstalled(allocator: Allocator, io: Io, exe_dir: []const u8, filename: []const u8) !bool {
    const installed_dir = stem(stem(filename));
    const installed_path = try std.fs.path.join(
        allocator,
        &.{ exe_dir, installed_dir },
    );
    defer allocator.free(installed_path);

    std.Io.Dir.cwd().access(io, installed_path, .{}) catch |err| {
        if (err == error.FileNotFound) return false else return err;
    };
    return true;
}

pub fn cacheDirPath(allocator: Allocator) ![]u8 {
    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);

    return try std.fs.path.join(allocator, &.{ home, ".cache/ztup" });
}

pub fn checkCache(allocator: Allocator, io: Io, filename: []const u8) !?[]u8 {
    const cache_dir_path = try cacheDirPath(allocator);
    defer allocator.free(cache_dir_path);

    const cache_path = try std.fs.path.join(allocator, &.{ cache_dir_path, filename });
    defer allocator.free(cache_path);

    std.Io.Dir.accessAbsolute(io, cache_path, .{}) catch |err| {
        if (err == error.FileNotFound) return null else return err;
    };
    return cache_path;
}

pub const zls_url_prefix = "https://builds.zigtools.org";

pub const DownloadError = error{
    WgetFailed,
};

pub fn downloadCache(
    allocator: Allocator,
    io: Io,
    mode: Cli.Mode,
    filename: []const u8,
    exe_dir: []const u8,
) ![]u8 {
    const cache_dir_path = try cacheDirPath(allocator);
    defer allocator.free(cache_dir_path);

    _ = try simple.execProcess(allocator, io, &.{ "mkdir", "-p", cache_dir_path });

    const cache_path = try std.fs.path.join(allocator, &.{ cache_dir_path, filename });
    defer allocator.free(cache_path);

    const url = switch (mode) {
        .zig => zig: {
            const zig_url_prifix = try mirrors.communityMirror(allocator, io, exe_dir);
            defer allocator.free(zig_url_prifix);
            break :zig try std.fs.path.join(allocator, &.{ zig_url_prifix, filename });
        },
        .zls => try std.fs.path.join(allocator, &.{ zls_url_prefix, filename }),
    };
    defer allocator.free(url);

    std.log.info("Download from {s}", .{url});
    const term = try simple.execProcess(allocator, io, &.{ "wget", url, "-P", cache_dir_path });
    // This is the list of exit codes for wget:
    //
    // 0       No problems occurred
    // 1       Generic error code
    // 2       Parse error — for instance, when parsing command-line options, the .wgetrc or .netrc…
    // 3       File I/O error
    // 4       Network failure
    // 5       SSL verification failure
    // 6       Username/password authentication failure
    // 7       Protocol errors
    // 8       Server issued an error response
    switch (term) {
        .Exited => |code| {
            if (code != 0) return DownloadError.WgetFailed;
        },
        else => return DownloadError.WgetFailed,
    }

    return cache_path;
}
