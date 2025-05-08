const std = @import("std");
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const Board = @import("board.zig").Board;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try repl(allocator);
}

fn repl(allocator: std.mem.Allocator) !void {
    // var board = Board.init(allocator);
    // var board = Board.fen_init(allocator, @constCast("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"));
    var board = try Board.fen_init(allocator, @constCast("r3k2r/pp1q1ppp/2n1bn2/2bp4/2B1P3/2N2N2/PPP2PPP/R2Q1RK1 b kq e3 0 10"));
    try board.print();
    try board.info();

    // try board.play(@constCast("c2c3"));
    // try board.play(@constCast("g7g6"));
    //
    // try board.play(@constCast("c3c4"));
    // try board.play(@constCast("g6g5"));
    //
    // try board.play(@constCast("c4c5"));
    // try board.play(@constCast("g5g4"));
    //
    // try board.play(@constCast("c5c6"));
    // try board.play(@constCast("g4g3"));
    //
    // try board.play(@constCast("c6b7"));
    // try board.play(@constCast("g3h2"));
    //
    // try board.play(@constCast("b7a8"));
    // try board.play(@constCast("h2g1"));
    while (true) {
        try stdout.print("> ", .{});
        const input = stdin.readUntilDelimiterAlloc(allocator, '\n', 6) catch {
            try stdout.print("String can't be longer than 5 charecters\n", .{});
            continue;
        };
        if (std.mem.eql(u8, input, "exit")) {
            try stdout.print("Thank you for playing\n", .{});
            std.process.exit(0);
        }
        try board.play(input, false);
        try board.info();
    }
}
