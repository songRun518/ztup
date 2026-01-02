const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const stem = std.fs.path.stem;

const Cli = @import("Cli.zig");

const zig_filename_prefix = "zig-x86_64-linux";
const zls_filename_prefix = "zls-x86_64-linux";
const file_extension = ".tar.xz";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var cli = Cli.parse(allocator) catch |err| {
        if (err == Cli.Error.PrintHelp) return else return err;
    };
    defer cli.deinit(allocator);
    const version = try getMasterVersion(allocator, io);

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

    if (try checkInstalled(allocator, io, cli.exe_dir, filename)) {
        std.log.info("Version '{s}' has been installed", .{version});
        return;
    }

    if (try checkCache(allocator, io, filename)) |cache_path| {
        std.log.info("Version '{s}' has been in caches", .{version});
        std.log.info("Extract cache", .{});
        _ = try execChildProcess(allocator, io, &.{ "tar", "-xf", cache_path, "-C", cli.exe_dir });
        return;
    }

    std.log.info("Download version '{s}' to caches", .{version});
    const cache_path = try downloadCache(allocator, io, cli.mode, filename);
    defer allocator.free(cache_path);
    std.log.info("Extract cache", .{});
    _ = try execChildProcess(allocator, io, &.{ "tar", "-xf", cache_path, "-C", cli.exe_dir });
}

const index_url = "https://ziglang.org/download/index.json";
const Index = struct { master: struct { version: []const u8 } };

fn getMasterVersion(allocator: Allocator, io: Io) ![]u8 {
    var client: std.http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();

    var request = try client.request(.GET, try .parse(index_url), .{});
    defer request.deinit();

    try request.sendBodiless();
    var redirect_buffer: [1024]u8 = undefined;
    var resp = try request.receiveHead(&redirect_buffer);
    var transfer_buffer: [1024]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    const decompress_buffer = try allocator.alloc(u8, 10 * 1024 * 1024);
    var resp_reader = resp.readerDecompressing(
        &transfer_buffer,
        &decompress,
        decompress_buffer,
    );

    var content_writer: std.Io.Writer.Allocating = .init(allocator);
    defer content_writer.deinit();
    var read_buffer: [1024]u8 = undefined;
    while (true) {
        const len = try resp_reader.readSliceShort(&read_buffer);
        try content_writer.writer.writeAll(read_buffer[0..len]);
        if (len != read_buffer.len) break;
    }
    const content = try content_writer.toOwnedSlice();
    defer allocator.free(content);

    const parsed: std.json.Parsed(Index) = try std.json.parseFromSlice(
        Index,
        allocator,
        content,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    return allocator.dupe(u8, parsed.value.master.version);
}

fn checkInstalled(allocator: Allocator, io: Io, exe_dir: []const u8, filename: []const u8) !bool {
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

var cache_dir_path: ?[]u8 = null;

fn setCacheDirPath(allocator: Allocator) !void {
    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);

    cache_dir_path = try std.fs.path.join(allocator, &.{ home, ".cache/ztup" });
}

fn checkCache(allocator: Allocator, io: Io, filename: []const u8) !?[]u8 {
    if (cache_dir_path) |_| {} else try setCacheDirPath(allocator);

    const cache_path = try std.fs.path.join(allocator, &.{ cache_dir_path.?, filename });

    std.Io.Dir.accessAbsolute(io, cache_path, .{}) catch |err| {
        if (err == error.FileNotFound) return null else return err;
    };
    return cache_path;
}

const zig_url_prefix = "https://pkg.machengine.org/zig";
const zls_url_prefix = "https://builds.zigtools.org";

fn downloadCache(allocator: Allocator, io: Io, mode: Cli.Mode, filename: []const u8) ![]u8 {
    if (cache_dir_path) |_| {} else try setCacheDirPath(allocator);

    _ = try execChildProcess(allocator, io, &.{ "mkdir", "-p", cache_dir_path.? });

    const cache_path = try std.fs.path.join(allocator, &.{ cache_dir_path.?, filename });

    const url = switch (mode) {
        .zig => try std.fs.path.join(allocator, &.{ zig_url_prefix, filename }),
        .zls => try std.fs.path.join(allocator, &.{ zls_url_prefix, filename }),
    };
    defer allocator.free(url);
    _ = try execChildProcess(allocator, io, &.{ "wget", url, "-P", cache_dir_path.? });

    return cache_path;
}

fn execChildProcess(
    allocator: Allocator,
    io: std.Io,
    argv: []const []const u8,
) !std.process.Child.Term {
    var child: std.process.Child = .init(argv, allocator);

    const stdout = std.Io.File.stdout();
    const stderr = std.Io.File.stderr();
    child.stdout = stdout;
    child.stderr = stderr;

    return try child.spawnAndWait(io);
}
