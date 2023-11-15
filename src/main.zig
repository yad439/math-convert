const std = @import("std");

const State = enum { DEFAULT, FIRST, INLINE, BLOCK, FIRST_CLOSE };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const check = gpa.deinit();
        if (check != .ok) std.debug.print("Memory leak detected\n", .{});
    }
    const stdout_file = std.io.getStdOut().writer();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip(); // skip program name
    const mode = args.next();
    if (mode == null) {
        try stdout_file.print("Need to specify mode\n", .{});
        return;
    }
    const filename_optional = args.next();
    if (filename_optional == null) {
        try stdout_file.print("Need to specify input file name\n", .{});
        return;
    }
    const filename = filename_optional.?;
    const output_optional = args.next();
    var allocated_second = output_optional == null;
    const output_name = if (output_optional == null) blk1: {
        allocated_second = true;
        const buf = try allocator.alloc(u8, filename.len + 4);
        @memcpy(buf[0..filename.len], filename);
        @memcpy(buf[filename.len..], ".out");
        break :blk1 buf;
    } else blk2: {
        allocated_second = false;
        break :blk2 output_optional.?;
    };
    defer if (allocated_second) {
        allocator.free(output_name);
    };
    const input_file = std.fs.cwd().openFile(filename, .{}) catch |e| {
        try stdout_file.print("Could not open file: {}\n", .{e});
        return;
    };
    defer input_file.close();
    var input_reader = std.io.bufferedReader(input_file.reader());
    const input = input_reader.reader();
    const output_file = std.fs.cwd().createFile(output_name, .{}) catch |e| {
        try stdout_file.print("Could not open file: {}\n", .{e});
        return;
    };
    defer output_file.close();
    var output_writer = std.io.bufferedWriter(output_file.writer());
    const output = output_writer.writer();
    defer output_writer.flush() catch |err| {
        std.debug.print("Can't write file: {}\n", .{err});
    };
    var state = State.DEFAULT;
    while (true) {
        const char = input.readByte() catch |err| {
            if (err == error.EndOfStream) {
                break;
            } else {
                return err;
            }
        };
        switch (state) {
            .DEFAULT => {
                if (char == '$') {
                    state = State.FIRST;
                } else try output.writeByte(char);
            },
            .FIRST => {
                if (char == '$') {
                    try output.writeAll("\\[");
                    state = .BLOCK;
                } else {
                    try output.writeAll("\\(");
                    try output.writeByte(char);
                    state = .INLINE;
                }
            },
            .INLINE => {
                if (char == '$') {
                    try output.writeAll("\\)");
                    state = .DEFAULT;
                } else {
                    try output.writeByte(char);
                }
            },
            .BLOCK => {
                if (char == '$') {
                    state = .FIRST_CLOSE;
                } else {
                    try output.writeByte(char);
                }
            },
            .FIRST_CLOSE => {
                if (char == '$') {
                    try output.writeAll("\\]");
                    state = .DEFAULT;
                } else {
                    try stdout_file.print("Mailformed input\n", .{});
                    try output.writeAll("\\$");
                    try output.writeByte(char);
                    state = .BLOCK;
                }
            },
        }
    }
}
