const std = @import("std");
const Database = @import("database/database.zig").Database;
const Storage = @import("database/storage.zig").Storage;

pub const Server = struct {
    const Command = enum {
        Set,
        Get,
        Del,
        Unknown,
    };

    database: Database,
    storage: Storage,
    pub fn init(allocator: std.mem.Allocator, storage_path: []const u8) !Server {
        return Server{ .database = Database.init(allocator), .storage = try Storage.init(storage_path) };
    }

    pub fn handleClient(self: *Server, stream: *std.net.Stream) !void {
        var buf: [1024]u8 = undefined;
        const len = try stream.read(&buf);
        const request = buf[0..len];

        // Split request into tokens separated by space
        var tokens = std.mem.splitSequence(u8, request, " ");
        const cmd_token = tokens.next() orelse "";
        const command = std.meta.stringToEnum(Command, cmd_token) orelse Command.Unknown;

        switch (command) {
            Command.Set => {
                const key = tokens.next() orelse "";
                const value = tokens.next() orelse "";
                try self.database.set(key, value);
                try self.storage.append(request); // Log to AOF
                try stream.writeAll("+OK\r\n");
            },
            Command.Get => {
                const key = tokens.next() orelse "";
                if (self.database.get(key)) |value| {
                    try stream.writeAll("+");
                    try stream.writeAll(value);
                    try stream.writeAll("\r\n");
                } else {
                    try stream.writeAll("$-1\r\n"); // Null response
                }
            },
            Command.Del => {
                const key = tokens.next() orelse "";
                if (self.database.del(key)) {
                    try stream.writeAll(":1\r\n"); // Deleted
                } else {
                    try stream.writeAll(":0\r\n"); // Not found
                }
            },
            Command.Unknown => {
                try stream.writeAll("-ERR Unknown command\r\n");
            },
        }
    }

    pub fn start(self: *Server, name: []const u8, port: u16) !void {
        const address = try std.net.Address.resolveIp(name, port);
        var listener = try address.listen(.{});
        defer listener.deinit(); // Clean up after exit

        std.debug.print("Server running on {s}:{d}\n", .{ name, port });

        while (true) {
            var client = try listener.accept();
            defer client.stream.close(); // Ensure connection closes

            try self.handleClient(&client.stream);
        }
    }
};
