const std = @import("std");

const State = enum { DEFAULT, FIRST, INLINE, BLOCK, FIRST_CLOSE };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const check = gpa.deinit();
        if (check != .ok) std.debug.print("Memory leak detected\n", .{});
    }

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip(); // skip program name
    const mode = args.next();
    if (mode == null) {
        std.debug.print("Need to specify mode\n", .{});
        return;
    }
    const filename_optional = args.next();
    if (filename_optional == null) {
        std.debug.print("Need to specify input file name\n", .{});
        return;
    }
    const filename = filename_optional.?;
    const output_optional = args.next();
    const allocated_second = output_optional == null;
    const output_name = output_optional orelse blk1: {
        const buf = try allocator.alloc(u8, filename.len + 4);
        @memcpy(buf[0..filename.len], filename);
        @memcpy(buf[filename.len..], ".out");
        break :blk1 buf;
    };
    defer if (allocated_second) {
        allocator.free(output_name);
    };
    const input_file = std.fs.cwd().openFile(filename, .{}) catch |e| {
        std.debug.print("Could not open file: {}\n", .{e});
        return;
    };
    defer input_file.close();
    var input_reader = std.io.bufferedReader(input_file.reader());
    const input = input_reader.reader();
    const output_file = std.fs.cwd().createFile(output_name, .{}) catch |e| {
        std.debug.print("Could not open file: {}\n", .{e});
        return;
    };
    defer output_file.close();
    var output_writer = std.io.bufferedWriter(output_file.writer());
    const output = output_writer.writer();
    defer output_writer.flush() catch |err| {
        std.debug.print("Can't write file: {}\n", .{err});
    };
    if (std.mem.eql(u8, mode.?, "l")) {
        try convertToBraces(input, output);
    } else try convertToDollars(input, output);
}

fn convertToBraces(input: std.io.BufferedReader(4096, std.fs.File.Reader).Reader, output: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) !void {
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
                    std.debug.print("Mailformed input\n", .{});
                    try output.writeByte('$');
                    try output.writeByte(char);
                    state = .BLOCK;
                }
            },
        }
    }
}

fn convertToDollars(input: std.io.BufferedReader(4096, std.fs.File.Reader).Reader, output: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) !void {
    while (true) {
        const char = input.readByte() catch |err| {
            if (err == error.EndOfStream) {
                break;
            } else {
                return err;
            }
        };
        if (char == '\\') {
            const second_char = try input.readByte();
            switch (second_char) {
                '(', ')' => try output.writeByte('$'),
                '[', ']' => try output.writeAll("$$"),
                else => {
                    try output.writeByte('\\');
                    try output.writeByte(second_char);
                },
            }
        } else {
            try output.writeByte(char);
        }
    }
}
