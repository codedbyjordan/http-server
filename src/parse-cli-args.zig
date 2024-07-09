const std = @import("std");
const mem = std.mem;

pub const RouterArgs = struct {
    directory: []const u8,
};

pub fn parseCliArgs() !RouterArgs {
    var args = std.process.args();
    var parsedArgs = RouterArgs{
        .directory = "/tmp",
    };
    while (args.next()) |arg| {
        if (mem.startsWith(u8, arg, "--directory")) {
            if (args.next()) |dir| {
                parsedArgs.directory = dir;
            }
        }
    }

    return parsedArgs;
}
