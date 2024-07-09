const std = @import("std");
const mem = std.mem;

pub const Request = struct {
    headers: std.StringHashMap([]const u8),
    method: []const u8,
    path: []const u8,
    pathParams: std.ArrayList([]const u8),
    body: []const u8,

    pub fn initFromBuffer(buffer: []const u8) !Request {
        var splitBytes = mem.splitAny(u8, buffer, "\r\n");
        var request = Request{
            .headers = std.StringHashMap([]const u8).init(std.heap.page_allocator),
            .method = undefined,
            .path = undefined,
            .pathParams = std.ArrayList([]const u8).init(std.heap.page_allocator),
            .body = undefined,
        };

        while (splitBytes.next()) |value| {
            if (mem.startsWith(u8, value, "GET") or mem.startsWith(u8, value, "POST")) {
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
            } else {
                request.body = value;
            }
        }

        return request;
    }

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
        self.pathParams.deinit();
    }
};
