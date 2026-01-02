const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub fn tinyGet(allocator: Allocator, io: Io, url: []const u8) ![]u8 {
    var client: std.http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();

    var request = try client.request(.GET, try .parse(url), .{});
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
    return try content_writer.toOwnedSlice();
}

pub fn execChildProcess(
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
