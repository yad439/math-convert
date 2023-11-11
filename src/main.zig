const std = @import("std");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    _ = args.skip(); // skip program name
    const mode = args.next();
    if (mode == null) {
        try stdout_file.print("Need to specify mode\n", .{});
        return;
    }
    const filename = args.next();
    if (filename == null) {
        try stdout_file.print("Need to specify filename\n", .{});
        return;
    }
}
