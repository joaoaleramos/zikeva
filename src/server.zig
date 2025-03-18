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
        const command = if (std.mem.startsWith(u8, request, "SET ")) Command.Set else if (std.mem.startsWith(u8, request, "GET ")) Command.Get else if (std.mem.startsWith(u8, request, "DEL ")) Command.Del else Command.Unknown;

        switch (command) {
            .Set => {
                var parts = std.mem.splitScalar(u8, request[4..], ' ');
                const key = parts.next() orelse "";
                const value = parts.next() orelse "";
                try self.db.set(key, value);
                try self.storage.append(request); // Log to AOF
                try stream.writeAll("+OK\r\n");
            },
            .Get => {
                const key = request[4..];
                if (self.db.get(key)) |value| {
                    try stream.writeAll("+");
                    try stream.writeAll(value);
                    try stream.writeAll("\r\n");
                } else {
                    try stream.writeAll("$-1\r\n"); // Null response
                }
            },
            .Del => {
                const key = request[4..];
                if (self.db.del(key)) {
                    try stream.writeAll(":1\r\n"); // Deleted
                } else {
                    try stream.writeAll(":0\r\n"); // Not found
                }
            },
            .Unknown => {
                try stream.writeAll("-ERR Unknown command\r\n");
            },
        }
    }

    pub fn start(self: *Server) !void {
        var server = try std.net.tcpListen(std.net.Address.parseIp("127.0.0.1", 6379));
        std.debug.print("Server running on 127.0.0.1:6379\n", .{});

        while (true) {
            var client = try server.accept();
            try self.handleClient(&client.stream);
            client.stream.close();
        }
    }
};
