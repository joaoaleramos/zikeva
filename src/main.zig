const std = @import("std");
const Server = @import("server.zig").Server;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try Server.init(allocator, "db.aof");
    try server.start("127.0.0.1", 6379);
}
