const std = @import("std");

// ponytail: stock config (stdio, wchar, Ogg FLAC, CRC all enabled). SIMD is automatic from the
// target: SSE2/SSE4.1 via __SSE2__/__SSE4_1__, NEON via __ARM_NEON.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libc_include = b.option(std.Build.LazyPath, "libc_include", "Build without libc against these headers; the consumer provides the symbols");

    for ([_][]const u8{ "dr_mp3", "dr_wav", "dr_flac" }) |name| {
        const header = b.fmt("{s}.h", .{name});
        const upper = std.ascii.allocUpperString(b.allocator, name) catch @panic("OOM");
        const define = b.fmt("-D{s}_IMPLEMENTATION", .{upper});
        const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = libc_include == null });
        if (libc_include) |p| mod.addIncludePath(p); // -I: must win over the macOS SDK headers zig always adds
        // Without libc the Windows file code (windows.h, io.h, _wfopen) cannot build; the consumer's
        // libc has no files anyway, so take the POSIX paths (they call its failing stubs).
        const no_win32: []const []const u8 = if (libc_include != null and target.result.os.tag == .windows)
            &.{ "-U_WIN32", "-UWIN32", "-U__WIN32__", "-U__MINGW32__" } // not _WIN64: used to detect LLP64
        else
            &.{};
        mod.addCSourceFile(.{ .file = b.path(header), .language = .c, .flags = std.mem.concat(b.allocator, []const u8, &.{ &.{define}, no_win32 }) catch @panic("OOM") });
        const lib = b.addLibrary(.{ .name = name, .root_module = mod });
        lib.installHeader(b.path(header), header);
        b.installArtifact(lib);
    }
}
