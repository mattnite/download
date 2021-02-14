# download

zig library for downloading files for build scripts

Right now only supports tar.gz files, and it saves downloads into the build cache.
By defalt the url is hashed for the directoy name, but you can optionally set a name, as well as a sha256 hash for integrity checking.
A simple caching trick is utilized as well so that you don't download every time the build is run.

## Example

Using both options:

```zig
const std = @import("std");
const Builder = @import("std").build.Builder;

const download = @import("download");

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("stm32", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const path = try download.tar.gz(b, "https://zlib.net/zlib-1.2.11.tar.gz", .{
        .name = "zlib-1.2.11",
        .sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
    });
    defer b.allocator.free(path);

    // rest of build file ...
}
```
