const std = @import("std");
const stdout = std.io.getStdOut().writer();

const Piece = enum {
    WhitePawn,
    WhiteKnight,
    WhiteRook,
    WhiteBishop,
    WhiteKing,
    WhiteQueen,
    BlackPawn,
    BlackKnight,
    BlackRook,
    BlackBishop,
    BlackKing,
    BlackQueen,
};

const Move = struct {
    const Self = @This();
    from: struct { u8, u8 },
    to: struct { u8, u8 },

    pub fn compare(self: *const Self, move: Self) bool {
        if (self.from.@"0" == move.from.@"0" and self.from.@"1" == move.from.@"1" and self.to.@"0" == move.to.@"0" and self.to.@"1" == move.to.@"1") {
            return true;
        } else {
            return false;
        }
    }
};

const Color = enum {
    White,
    Black,
    None,
};

const PieceIcons = [_][]const u8{
    "\x1b[37m󰡙",
    "\x1b[37m",
    "\x1b[37m",
    "\x1b[37m",
    "\x1b[37m",
    "\x1b[37m",
    "\x1b[30m󰡙",
    "\x1b[30m",
    "\x1b[30m",
    "\x1b[30m",
    "\x1b[30m",
    "\x1b[30m",
};
const BackgroundColor = [_][]const u8{ "\x1b[48;5;49m", "\x1b[48;5;130m", "\x1b[0m" };

pub const Board = struct {
    const Self = @This();

    squares: [8][8]?Piece,
    allocator: std.mem.Allocator,
    turn: Color,

    pub fn init(allocator: std.mem.Allocator) Self {
        var squares: [8][8]?Piece = undefined;

        for (&squares, 0..) |*row, i| {
            for (row, 0..) |*square, j| {
                if (i == 1) {
                    square.* = Piece.BlackPawn;
                } else if (i == 6) {
                    square.* = Piece.WhitePawn;
                } else if (i == 0) {
                    if (j == 0 or j == 7) {
                        square.* = Piece.BlackRook;
                    } else if (j == 1 or j == 6) {
                        square.* = Piece.BlackKnight;
                    } else if (j == 2 or j == 5) {
                        square.* = Piece.BlackBishop;
                    } else if (j == 3) {
                        square.* = Piece.BlackQueen;
                    } else if (j == 4) {
                        square.* = Piece.BlackKing;
                    }
                } else if (i == 7) {
                    if (j == 0 or j == 7) {
                        square.* = Piece.WhiteRook;
                    } else if (j == 1 or j == 6) {
                        square.* = Piece.WhiteKnight;
                    } else if (j == 2 or j == 5) {
                        square.* = Piece.WhiteBishop;
                    } else if (j == 3) {
                        square.* = Piece.WhiteQueen;
                    } else if (j == 4) {
                        square.* = Piece.WhiteKing;
                    }
                } else {
                    square.* = null;
                }
            }
        }

        return Self{
            .squares = squares,
            .allocator = allocator,
            .turn = Color.White,
        };
    }

    pub fn play(self: *Self, s: []u8) !void {
        const move = try self.parse(s);
        const color = self.check_peice_color(move.from);
        if (color != Color.None) {
            if (color != self.turn) {
                try stdout.print("It is {s}'s turn\n", .{@tagName(self.turn)});
                return;
            }
        } else {
            // Modulus to prevent over and underflow
            try stdout.print("No piece in the position {c}{}\n", .{ move.from.@"1" % 159 + 97, 8 - move.from.@"0" % 8 });
            return;
        }
        const moves = try self.generate_legal_moves(move);
        defer moves.deinit();
        var can_move = false;
        for (moves.items) |m| {
            if (move.compare(m)) {
                can_move = true;
                break;
            }
        }
        if (can_move) {
            try self.do_move(move);
            if (self.turn == Color.White) {
                self.turn = Color.Black;
            } else {
                self.turn = Color.White;
            }
            try self.print();
        }
    }

    fn check_peice_color(self: *Self, from: struct { u8, u8 }) Color {
        if (!(from.@"0" < 8 and from.@"0" >= 0 and from.@"1" < 8 and from.@"1" >= 0)) {
            return Color.None;
        }
        if (self.squares[from.@"0"][from.@"1"]) |square| {
            if (@intFromEnum(square) < 6) {
                return Color.White;
            } else {
                return Color.Black;
            }
        } else {
            return Color.None;
        }
    }

    fn do_move(self: *Self, move: Move) !void {
        self.squares[move.to.@"0"][move.to.@"1"] = self.squares[move.from.@"0"][move.from.@"1"];
        self.squares[move.from.@"0"][move.from.@"1"] = null;
    }

    fn parse(_: *Self, move: []u8) !Move {
        var setting: [6]u8 = undefined;
        var j: u8 = 0;
        for (0..move.len) |i| {
            switch (move[i]) {
                'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' => {
                    setting[j] = move[i] - 97;
                    j += 1;
                },
                '1', '2', '3', '4', '5', '6', '7', '8' => {
                    setting[j] = 8 - (move[i] - 49 + 1);
                    j += 1;
                },
                else => {
                    try stdout.print("Not done yet", .{});
                },
            }
        }
        return Move{
            .from = .{ setting[1], setting[0] },
            .to = .{ setting[3], setting[2] },
        };
    }

    pub fn generate_legal_moves(self: *Self, move: Move) !std.ArrayList(Move) {
        var moves_list = std.ArrayList(Move).init(self.allocator);
        if (self.squares[move.from.@"0"][move.from.@"1"]) |piece| {
            switch (piece) {
                Piece.WhitePawn => {
                    if (move.from.@"0" - 1 >= 0 and self.squares[move.from.@"0" - 1][move.from.@"1"] == null) {
                        try moves_list.append(Move{
                            .from = move.from,
                            .to = .{
                                move.from.@"0" - 1,
                                move.from.@"1",
                            },
                        });
                    }
                    if (move.from.@"0" - 1 >= 0 and move.from.@"1" - 1 >= 0 and self.check_peice_color(.{ move.from.@"0" - 1, move.from.@"1" - 1 }) == Color.Black) {
                        try moves_list.append(Move{
                            .from = move.from,
                            .to = .{
                                move.from.@"0" - 1,
                                move.from.@"1" - 1,
                            },
                        });
                    }
                    if (move.from.@"0" - 1 >= 0 and move.from.@"1" + 1 < 8 and self.check_peice_color(.{ move.from.@"0" - 1, move.from.@"1" + 1 }) == Color.Black) {
                        try moves_list.append(Move{
                            .from = move.from,
                            .to = .{
                                move.from.@"0" - 1,
                                move.from.@"1" + 1,
                            },
                        });
                    }
                },
                Piece.BlackPawn => {
                    if (move.from.@"0" + 1 < 8 and self.squares[move.from.@"0" + 1][move.from.@"1"] == null) {
                        try moves_list.append(Move{
                            .from = move.from,
                            .to = .{
                                move.from.@"0" + 1,
                                move.from.@"1",
                            },
                        });
                    }
                    if (move.from.@"0" + 1 < 8 and move.from.@"1" - 1 >= 0 and self.check_peice_color(.{ move.from.@"0" + 1, move.from.@"1" - 1 }) == Color.White) {
                        try moves_list.append(Move{
                            .from = move.from,
                            .to = .{
                                move.from.@"0" + 1,
                                move.from.@"1" - 1,
                            },
                        });
                    }
                    if (move.from.@"0" + 1 < 8 and move.from.@"1" + 1 < 8 and self.check_peice_color(.{ move.from.@"0" + 1, move.from.@"1" + 1 }) == Color.White) {
                        try moves_list.append(Move{
                            .from = move.from,
                            .to = .{
                                move.from.@"0" + 1,
                                move.from.@"1" + 1,
                            },
                        });
                    }
                },
                else => {
                    try stdout.print("{any}\n", .{self.squares[move.from.@"0"][move.from.@"1"]});
                    try stdout.print("Not implemented yet", .{});
                },
            }
        } else {
            try stdout.print("No Piece here\n", .{});
            try stdout.print("{} {}\n", .{ move.from.@"0", move.from.@"1" });
            try stdout.print("{any}", .{self.squares[move.from.@"0"][move.from.@"1"]});
        }
        return moves_list;
    }

    pub fn print(self: *Self) !void {
        try stdout.print("  A B C D E F G H", .{});
        try stdout.print("\n", .{});
        for (self.squares, 0..) |row, i| {
            try stdout.print("{} ", .{8 - i});
            for (row, 0..) |square, j| {
                if (square) |s| {
                    try stdout.print("{s}{s: <2} {s}", .{ BackgroundColor[(i + j) % 2], PieceIcons[@intFromEnum(s)], BackgroundColor[2] });
                } else {
                    try stdout.print("{s}  {s}", .{ BackgroundColor[(i + j) % 2], BackgroundColor[2] });
                }
            }
            try stdout.print(" {}", .{8 - i});
            try stdout.print("\n", .{});
        }
        try stdout.print("  A B C D E F G H\n", .{});
    }
};
