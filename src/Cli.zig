const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;

const Self = @This();

exe_dir: []const u8,
mode: Mode,
version: []const u8,

pub const Mode = enum { zig, zls };

pub const help =
    \\Usage: ztup <mode>
    \\
    \\Modes:
    \\  zig <version>   Update zig
    \\  zls <version>   Update zls
    \\  -h --help       Print help
;

pub const Error = error{
    PrintHelp,
    FieldMissing,
    UnknownMode,
};

pub fn parse(allocator: Allocator) !Self {
    var iter = try std.process.argsWithAllocator(allocator);
    defer iter.deinit();

    const exe_path = iter.next().?;
    const exe_dir = std.fs.path.dirname(exe_path).?;
    const mode_str = iter.next() orelse {
        std.log.err("Missing field 'mode'", .{});
        return Error.FieldMissing;
    };
    const mode = mode: {
        if (eql(u8, mode_str, "-h") or eql(u8, mode_str, "--help")) {
            std.log.info("{s}", .{help});
            return Error.PrintHelp;
        } else if (eql(u8, mode_str, "zig")) {
            break :mode Mode.zig;
        } else if (eql(u8, mode_str, "zls")) {
            break :mode Mode.zls;
        } else {
            std.log.err("Unknown mode '{s}'", .{mode_str});
            return Error.UnknownMode;
        }
    };
    const version = iter.next() orelse {
        std.log.err("Missing field 'version'", .{});
        return Error.FieldMissing;
    };

    return .{
        .exe_dir = try allocator.dupe(u8, exe_dir),
        .mode = mode,
        .version = try allocator.dupe(u8, version),
    };
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.free(self.exe_dir);
    allocator.free(self.version);
    self.* = undefined;
}
