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
        return Server{ .database = Database.init(allocator), .storage = Storage.init(storage_path) };
    }

    pub fn handleClient(self: *Server, stream: *std.net.Stream) !void {
        var buf: [1024]u8 = undefined;
        const len = try stream.read(&buf);
        const request = buf[0..len];

        // Extract command (first 3-4 bytes)
        const command = std.meta.stringToEnum(Command, request[0..3]) orelse return Command.Unknown;

        switch (command) {
            Command.Set => {
                var parts = std.mem.splitScalar(u8, request[4..], ' ');
                const key = parts.next() orelse "";
                const value = parts.next() orelse "";
                try self.db.set(key, value);
                try self.storage.append(request); // Log to AOF
                try stream.writeAll("+OK\r\n");
            },
            Command.Get => {
                const key = request[4..];
                if (self.db.get(key)) |value| {
                    try stream.writeAll("+");
                    try stream.writeAll(value);
                    try stream.writeAll("\r\n");
                } else {
                    try stream.writeAll("$-1\r\n"); // Null response
                }
            },
            Command.Del => {
                const key = request[4..];
                if (self.db.del(key)) {
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
        var server = try std.net.tcpListen(std.net.Address.parseIp(name, port));
        std.debug.print("Server running on {s}:{d}\n", .{ name, port });

        while (true) {
            var client = try server.accept();
            try self.handleClient(&client.stream);
            client.stream.close();
        }
    }
};
