const std = @import("std");
const mem = std.mem;

const net = std.net;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    // try stdout.print("Logs from your program will appear here!\n", .{});
    const port = 4221;
    const address = try net.Address.resolveIp("127.0.0.1", port);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    stdout.print("Listening on port {}\n", .{port}) catch unreachable;

    const connection = try listener.accept();

    var buffer: [1024]u8 = undefined;
    const allocator = std.heap.page_allocator;

    const memory = try allocator.alloc(u8, 1024);
    defer allocator.free(memory);

    const bytesRead = try connection.stream.read(&buffer);
    var splitBytes = mem.splitAny(u8, buffer[0..bytesRead], " ");

    _ = splitBytes.next();
    const endpoint = splitBytes.next() orelse return;

    if (mem.eql(u8, endpoint, "/")) {
        _ = try connection.stream.write("HTTP/1.1 200 OK\r\n\r\n");
    } else if (mem.startsWith(u8, endpoint, "/echo")) {
        const echoParameter = endpoint[6..];
        try std.fmt.format(connection.stream.writer(), "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ echoParameter.len, echoParameter });
    } else {
        _ = try connection.stream.write("HTTP/1.1 404 Not Found\r\n\r\n");
    }

    try stdout.print("client connected!", .{});
}
