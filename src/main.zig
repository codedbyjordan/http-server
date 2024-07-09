const std = @import("std");
const mem = std.mem;
const net = std.net;

const Router = @import("router.zig").Router;
const parseCliArgs = @import("parse-cli-args.zig").parseCliArgs;

pub fn main() !void {
    const parsedArgs = try parseCliArgs();

    var router = try Router.init(4221, parsedArgs.directory);
    try router.listen();
}
