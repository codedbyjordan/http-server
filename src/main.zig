const std = @import("std");
const mem = std.mem;

const net = std.net;

const Request = struct {
    headers: std.StringHashMap([]const u8),
    method: []const u8,
    path: []const u8,
    pathParams: std.ArrayList([]const u8),

    pub fn initFromBuffer(buffer: []const u8) !Request {
        var splitBytes = mem.splitAny(u8, buffer, "\r\n");
        var request = Request{
            .headers = std.StringHashMap([]const u8).init(std.heap.page_allocator),
            .method = undefined,
            .path = undefined,
            .pathParams = std.ArrayList([]const u8).init(std.heap.page_allocator),
        };

        while (splitBytes.next()) |value| {
            if (mem.startsWith(u8, value, "GET")) {
                var splitMethod = mem.splitAny(u8, value, " ");
                request.method = splitMethod.next() orelse return error.InvalidRequest;
                const fullPath = splitMethod.next() orelse return error.InvalidRequest;
                if (std.mem.eql(u8, fullPath, "/")) {
                    request.path = "/";
                } else {
                    var splitFullPath = mem.splitAny(u8, fullPath, "/");

                    _ = splitFullPath.next();

                    request.path = splitFullPath.next() orelse return error.InvalidRequest;

                    while (splitFullPath.next()) |pathPart| {
                        try request.pathParams.append(pathPart);
                    }
                }
            } else if (mem.indexOf(u8, value, ":")) |colonIndex| {
                const header_name = mem.trim(u8, value[0..colonIndex], " ");
                const header_value = mem.trim(u8, value[colonIndex + 1 ..], " ");
                try request.headers.put(header_name, header_value);
            }
        }

        return request;
    }

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
        self.pathParams.deinit();
    }
};

const http404 = "HTTP/1.1 404 Not Found\r\n\r\n";

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const port = 4221;
    const address = try net.Address.resolveIp("127.0.0.1", port);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    stdout.print("Listening on port {}\n", .{port}) catch unreachable;

    var args = std.process.args();
    var directory: []const u8 = "/tmp";

    while (args.next()) |arg| {
        if (mem.startsWith(u8, arg, "--directory")) {
            if (args.next()) |dir| {
                directory = dir;
            }
        }
    }

    while (true) {
        const connection = try listener.accept();
        try stdout.print("client connected!\n", .{});
        const thread = try std.Thread.spawn(.{}, handleRequest, .{ connection, directory });
        thread.detach();
    }
}

fn handleRequest(connection: net.Server.Connection, directory: []const u8) !void {
    var buffer: [1024]u8 = undefined;
    const bytesRead = try connection.stream.read(&buffer);
    var request = try Request.initFromBuffer(buffer[0..bytesRead]);
    defer request.deinit();

    std.debug.print("Requesting path {s}\n", .{request.path});

    if (mem.eql(u8, request.path, "/")) {
        _ = try connection.stream.write("HTTP/1.1 200 OK\r\n\r\n");
    } else if (mem.eql(u8, request.path, "echo")) {
        try std.fmt.format(connection.stream.writer(), "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ request.pathParams.items[0].len, request.pathParams.items[0] });
    } else if (mem.eql(u8, request.path, "user-agent")) {
        try std.fmt.format(connection.stream.writer(), "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ request.headers.get("User-Agent").?.len, request.headers.get("User-Agent").? });
    } else if (mem.eql(u8, request.path, "files")) {
        const requestedFile = request.pathParams.items[0];
        const fullFilePath = try std.fs.path.join(std.heap.page_allocator, &[_][]const u8{ directory, requestedFile });
        const file = std.fs.cwd().openFile(fullFilePath, .{}) catch {
            _ = try connection.stream.write(http404);
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
    } else {
        _ = try connection.stream.write(http404);
    }
}
