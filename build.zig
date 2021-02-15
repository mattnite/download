const Builder = @import("std").build.Builder;
const pkgs = @import("gyro").pkgs;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("tmp", "src/main.zig");
    lib.setBuildMode(mode);
    pkgs.addAllTo(lib);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    pkgs.addAllTo(main_tests);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
