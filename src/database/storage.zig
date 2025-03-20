const std = @import("std");

pub const Storage = struct {
    file: std.fs.File,
    pub fn init(path: []const u8) !Storage {
        const file = try std.fs.cwd().createFile(path, .{ .read = true });

        return Storage{ .file = file };
    }

    pub fn append(self: *Storage, command: []const u8) !void {
        try self.file.writer().writeAll(command);
        try self.file.writer().writeAll("\n");
        try self.file.sync();
    }
    pub fn close(self: *Storage) void {
        self.close();
    }
};
