const std = @import("std");

pub const Database = struct {
    key_value: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Database {
        return Database{
            .allocator = allocator,
            .key_value = std.StringHashMap([]const u8).init(allocator),
        };
    }
    pub fn set(self: *Database, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        const value_copy = try self.allocator.dupe(u8, value);
        try self.key_value.put(key_copy, value_copy);
    }
    pub fn get(self: *Database, key: []const u8) ?[]const u8 {
        return self.key_value.get(key);
    }
    pub fn del(self: *Database, key: []const u8) bool {
        return self.key_value.remove(key);
    }
};
