const std = @import("std");
const mem = std.mem;

const net = std.net;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    // try stdout.print("Logs from your program will appear here!\n", .{});

    const address = try net.Address.resolveIp("127.0.0.1", 4221);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    const connection = try listener.accept();

    var buffer: [1024]u8 = undefined;
    const allocator = std.heap.page_allocator;

    const memory = try allocator.alloc(u8, 1024);
    defer allocator.free(memory);

    const bytesRead = try connection.stream.read(&buffer);
    var splitBytes = mem.splitAny(u8, buffer[0..bytesRead], " ");

    _ = splitBytes.next();
    const resource = splitBytes.next();

    if (mem.eql(u8, resource.?, "/")) {
        _ = try connection.stream.write("HTTP/1.1 200 OK\r\n\r\n");
    } else {
        _ = try connection.stream.write("HTTP/1.1 404 Not Found\r\n\r\n");
    }

    try stdout.print("client connected!", .{});
}
