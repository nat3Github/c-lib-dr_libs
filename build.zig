const std = @import("std");

// Stock config by default (stdio, wchar, Ogg FLAC, CRC all enabled); see the options below. SIMD is automatic from the
// target: SSE2/SSE4.1 via __SSE2__/__SSE4_1__, NEON via __ARM_NEON.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libc_include = b.option(std.Build.LazyPath, "libc_include", "Build without libc against these headers; the consumer provides the symbols");
    const no_stdio = b.option(bool, "no_stdio", "Leave out the stdio file APIs (DR_*_NO_STDIO)") orelse false;
    const mp3_float_output = b.option(bool, "mp3_float_output", "dr_mp3 decodes to f32 natively, s16 is converted (DR_MP3_FLOAT_OUTPUT)") orelse false;

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
        var flags: std.ArrayList([]const u8) = .empty;
        flags.append(b.allocator, define) catch @panic("OOM");
        flags.appendSlice(b.allocator, no_win32) catch @panic("OOM");
        if (no_stdio) flags.append(b.allocator, b.fmt("-D{s}_NO_STDIO", .{upper})) catch @panic("OOM");
        if (mp3_float_output and std.mem.eql(u8, name, "dr_mp3")) flags.append(b.allocator, "-DDR_MP3_FLOAT_OUTPUT") catch @panic("OOM");
        mod.addCSourceFile(.{ .file = b.path(header), .language = .c, .flags = flags.items });
        const lib = b.addLibrary(.{ .name = name, .root_module = mod });
        lib.installHeader(b.path(header), header);
        b.installArtifact(lib);
    }
}
