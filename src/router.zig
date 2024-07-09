const std = @import("std");
const net = std.net;
const mem = std.mem;
const Request = @import("request.zig").Request;

pub const Router = struct {
    port: u16 = 8080,
    directory: []const u8,
    address: net.Address,
    const http404 = "HTTP/1.1 404 Not Found\r\n\r\n";
    const http500 = "HTTP/1.1 500 Internal Server Error\r\n\r\n";

    pub fn init(port: u16, directory: []const u8) !Router {
        const address = net.Address.resolveIp("127.0.0.1", port) catch {
            return std.debug.panic("Failed to resolve address", .{});
        };

        const router = Router{
            .port = port,
            .directory = directory,
            .address = address,
        };

        return router;
    }

    pub fn listen(self: *Router) !void {
        var listener = self.address.listen(.{ .reuse_address = true }) catch unreachable;
        defer listener.deinit();
        std.debug.print("Listening on port {}\n", .{self.port});
        while (true) {
            const connection = try listener.accept();
            std.debug.print("client connected!\n", .{});
            const thread = try std.Thread.spawn(.{}, handleRequest, .{ connection, self.directory });
            thread.detach();
        }
    }

    fn handleRequest(connection: net.Server.Connection, directory: []const u8) !void {
        var buffer: [1024]u8 = undefined;
        const bytesRead = try connection.stream.read(&buffer);
        var request = try Request.initFromBuffer(buffer[0..bytesRead]);
        defer request.deinit();

        if (mem.eql(u8, request.path, "/")) {
            try connection.stream.writeAll("HTTP/1.1 200 OK\r\n\r\n");
        } else if (mem.eql(u8, request.path, "echo")) {
            try std.fmt.format(connection.stream.writer(), "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ request.pathParams.items[0].len, request.pathParams.items[0] });
        } else if (mem.eql(u8, request.path, "user-agent")) {
            try std.fmt.format(connection.stream.writer(), "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ request.headers.get("User-Agent").?.len, request.headers.get("User-Agent").? });
        } else if (mem.eql(u8, request.path, "files")) {
            const requestedFile = request.pathParams.items[0];
            const fullFilePath = try std.fs.path.join(std.heap.page_allocator, &[_][]const u8{ directory, requestedFile });

            if (std.mem.eql(u8, request.method, "GET")) {
                const file = std.fs.cwd().openFile(fullFilePath, .{}) catch {
                    try connection.stream.writeAll(http404);
                    return;
                };

                defer file.close();

                // Get the file size
                const file_size = try file.getEndPos();

                // Allocate memory for the buffer
                var fileBuffer = try std.heap.page_allocator.alloc(u8, file_size);
                defer std.heap.page_allocator.free(fileBuffer);
                const fileBytesRead = try file.readAll(fileBuffer);
                try std.fmt.format(connection.stream.writer(), "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: {d}\r\n\r\n{s}", .{ fileBytesRead, fileBuffer[0..fileBytesRead] });
            } else if (std.mem.eql(u8, request.method, "POST")) {
                const file = try std.fs.cwd().createFile(fullFilePath, .{ .read = true });
                defer file.close();
                try file.writeAll(request.body);
                try std.fmt.format(connection.stream.writer(), "HTTP/1.1 201 Created\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ request.body.len, request.body });
            }
        } else {
            try connection.stream.writeAll(http404);
        }
    }
};
