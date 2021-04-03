const std = @import("std");
const zfetch = @import("zfetch");
const tar = @import("tar");
const uri = @import("uri");
const Options = @import("main.zig").Options;

const Hasher = std.crypto.hash.blake2.Blake2b128;

pub fn gz(
    allocator: *std.mem.Allocator,
    cache_root: []const u8,
    url: []const u8,
    opts: Options,
) ![]const u8 {
    try zfetch.init();
    defer zfetch.deinit();

    var digest: [Hasher.digest_length]u8 = undefined;
    var subpath: [2 * Hasher.digest_length]u8 = undefined;

    Hasher.hash(url, &digest, .{});
    var fixed_buffer = std.io.fixedBufferStream(&subpath);
    for (digest) |i| try std.fmt.format(fixed_buffer.writer(), "{x:0>2}", .{i});

    const base = try std.fs.path.join(allocator, &[_][]const u8{
        cache_root,
        "downloads",
        if (opts.name) |n| n else &subpath,
    });
    defer allocator.free(base);

    var ret = try std.fs.path.join(allocator, &[_][]const u8{
        base, "content",
    });
    errdefer allocator.free(ret);

    var base_dir = try std.fs.cwd().makeOpenPath(base, .{});
    defer base_dir.close();

    var found = true;
    base_dir.access("ok", .{ .read = true }) catch |err| {
        if (err == error.FileNotFound)
            found = false
        else
            return err;
    };

    if (found) return ret;

    var dir = try std.fs.cwd().makeOpenPath(ret, .{});
    defer dir.close();

    try getTarGz(allocator, url, dir, opts.sha256);

    (try base_dir.createFile("ok", .{ .read = true })).close();
    return ret;
}

fn getTarGz(
    allocator: *std.mem.Allocator,
    url: []const u8,
    dir: std.fs.Dir,
    sha256: ?[]const u8,
) !void {
    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();

    std.log.info("fetching tarball: {s}", .{url});

    try headers.set("Accept", "*/*");
    try headers.set("User-Agent", "zig");

    var real_url = try allocator.dupe(u8, url);
    defer allocator.free(real_url);

    var redirects: usize = 0;
    var req = while (redirects < 128) {
        var ret = try zfetch.Request.init(allocator, real_url, null);
        const link = try uri.parse(real_url);
        try headers.set("Host", link.host orelse return error.NoHost);
        try ret.commit(.GET, headers, null);
        try ret.fulfill();

        switch (ret.status.code) {
            200 => break ret,
            302 => {
                // tmp needed for memory safety
                const tmp = real_url;
                const location = ret.headers.get("location") orelse return error.NoLocation;
                real_url = try allocator.dupe(u8, location);
                allocator.free(tmp);

                ret.deinit();
            },
            else => {
                return error.FailedRequest;
            },
        }
    } else return error.TooManyRedirects;
    defer req.deinit();

    var checker = try integrityChecker(sha256, req.reader());
    var gzip = try std.compress.gzip.gzipStream(allocator, checker.reader());
    defer gzip.deinit();

    try tar.instantiate(allocator, dir, gzip.reader(), 1);
    if (!try checker.valid()) return error.InvalidHash;
}

fn integrityChecker(sha256: ?[]const u8, reader: anytype) !IntegrityChecker(@TypeOf(reader)) {
    return IntegrityChecker(@TypeOf(reader)).init(sha256, reader);
}

fn IntegrityChecker(comptime ReaderType: type) type {
    return struct {
        internal: ReaderType,
        hasher: std.crypto.hash.sha2.Sha256,
        expected: ?[]const u8,

        const Self = @This();

        pub const Reader = std.io.Reader(*Self, ReaderType.Error, read);

        pub fn init(sha256: ?[]const u8, internal: ReaderType) !Self {
            if (sha256) |hash| if (hash.len != 64) return error.BadHashLen;
            return Self{
                .internal = internal,
                .hasher = std.crypto.hash.sha2.Sha256.init(.{}),
                .expected = sha256,
            };
        }

        fn read(self: *Self, buffer: []u8) ReaderType.Error!usize {
            const n = try self.internal.read(buffer);

            if (self.expected != null)
                self.hasher.update(buffer[0..n]);

            return n;
        }

        pub fn valid(self: *Self) !bool {
            return if (self.expected) |expected| blk: {
                const digest_len = std.crypto.hash.sha2.Sha256.digest_length;
                var out: [digest_len]u8 = undefined;
                self.hasher.final(&out);

                var fmted: [2 * digest_len]u8 = undefined;
                var fixed_buffer = std.io.fixedBufferStream(&fmted);
                for (out) |i| try std.fmt.format(fixed_buffer.writer(), "{x:0>2}", .{i});

                break :blk std.mem.eql(u8, expected, &fmted);
            } else true;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}
