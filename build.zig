const std = @import("std");
const builtin = @import("builtin");

const allocator = std.heap.page_allocator;
var devkitproPath: ?*const []u8 = null;

fn devkitpro(comptime string: []const u8) ![]const u8 {
    if (devkitproPath == null)
        devkitproPath = &try std.process.getEnvVarOwned(allocator, "DEVKITPRO_DIR");

    return try std.fmt.allocPrint(allocator, string, .{devkitproPath.?});
}

pub fn build(builder: *std.Build) !void {
    const obj = builder.addObject(.{ .name = "zig-3ds", .root_source_file = std.build.FileSource{ .path = "src/main.zig" }, .optimize = builder.standardOptimizeOption(.{}), .target = .{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.mpcore },
    } });
    obj.setMainPkgPath("zig-out");
    obj.linkLibC();
    obj.setLibCFile(std.build.FileSource{ .path = "libc.txt" });
    obj.addIncludePath(try devkitpro("{s}/libctru/include"));
    obj.addIncludePath(try devkitpro("{s}/portlibs/3ds/include"));

    const extension = if (builtin.target.os.tag == .windows) ".exe" else "";
    const elf = builder.addSystemCommand(&.{
        try devkitpro("{s}/devkitARM/bin/arm-none-eabi-gcc" ++ extension),
        "-g",
        "-march=armv6k",
        "-mtune=mpcore",
        "-mfloat-abi=hard",
        "-mtp=soft",
        "-Wl,-Map,zig-out/zig-3ds.map",
        try devkitpro("{s}/devkitARM/arm-none-eabi/lib/3dsx.specs"),
        "zig-out/zig-3ds.o",
        try devkitpro("-L{s}/libctru/lib"),
        try devkitpro("-L{s}/portlibs/3ds/lib"),
        "-lctru",
        "-o",
        "zig-out/zig-3ds.elf",
    });

    const dsx = builder.addSystemCommand(&.{
        try devkitpro( "{s}/tools/bin/3dsxtool" ++ extension ),
        "zig-out/zig-3ds.elf",
        "zig-out/zig-3ds.3dsx",
    });

    builder.default_step.dependOn(&dsx.step);
    dsx.step.dependOn(&elf.step);
    elf.step.dependOn(&obj.step);

    const run_step = builder.step("run", "Run in Citra");
    const citra = builder.addSystemCommand(&.{ "citra" ++ extension, "zig-out/zig-3ds.3dsx" });
    run_step.dependOn(&dsx.step);
    run_step.dependOn(&citra.step);
}
