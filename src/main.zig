const std = @import("std");

pub const tar = @import("tar.zig");

pub const Options = struct {
    /// override hashed url with a name, warning that this could collide
    name: ?[]const u8 = null,
    /// integrity check using sha256
    sha256: ?[]const u8 = null,
};
