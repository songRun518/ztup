const std = @import("std");
const Allocator = std.mem.Allocator;

const Cli = @import("Cli.zig");
const zig_mode = @import("zig_mode.zig");

pub const cache_dir_path = "~/.cache/ztup";
pub const mirror = "https://pkg.machengine.org/zig";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const stdout = std.Io.File.stdout();
    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = stdout.writer(io, &stdout_buffer);

    var cli = Cli.parse(allocator, &stdout_writer.interface) catch |err| {
        if (err == Cli.Error.PrintHelp) return else return err;
    };
    defer cli.deinit(allocator);

    try zig_mode.obtainZig(allocator, io, cli.filename, cli.exe_dir);
}
