const std = @import("std");

pub const tar = @import("tar.zig");

pub const Options = struct {
    /// override hashed url with a name, warning that this could collide
    name: ?[]const u8 = null,
    /// integrity check using sha256
    sha256: ?[]const u8 = null,
};

test "tar.gz" {
    const path = try tar.gz(
        std.testing.allocator,
        "zig-cache",
        "https://zlib.net/zlib-1.2.11.tar.gz",
        .{
            .name = "zlib-1.2.11",
            .sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
        },
    );
    defer std.testing.allocator.free(path);
}
