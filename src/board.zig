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

const Position = struct {
    row: usize,
    col: usize,
};

const Move = struct {
    const Self = @This();
    from: Position,
    to: Position,

    pub fn compare(self: *const Self, move: Self) bool {
        if (self.from.row == move.from.row and self.from.col == move.from.col and self.to.row == move.to.row and self.to.col == move.to.col) {
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
    castling: ?[]const u8,
    en_passent: ?[]const u8,
    half_move_clock: u8,
    full_move_clock: u8,

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
            .en_passent = null,
            .castling = "kqKQ",
            .half_move_clock = 0,
            .full_move_clock = 1,
        };
    }

    fn clone(self: *Self) Self {
        return Self{
            .squares = self.squares,
            .allocator = self.allocator,
            .turn = self.turn,
            .castling = self.castling,
            .en_passent = self.en_passent,
            .half_move_clock = self.half_move_clock,
            .full_move_clock = self.full_move_clock,
        };
    }

    pub fn fen_init(allocator: std.mem.Allocator, fen: []u8) !Self {
        var squares: [8][8]?Piece = undefined;
        var pieces_pointer = std.mem.splitAny(u8, fen, " ");
        const pieces = pieces_pointer.first();
        var lines = std.mem.splitAny(u8, pieces, "/");
        var i: usize = 0;
        var j: usize = 0;
        while (lines.next()) |line| : (i += 1) {
            j = 0;
            for (line) |piece| {
                if (std.ascii.isDigit(piece)) {
                    for (0..(piece - 48)) |_| {
                        squares[i][j] = null;
                        j += 1;
                    }
                    j -= 1;
                } else if (piece == 'r') {
                    squares[i][j] = Piece.BlackRook;
                } else if (piece == 'R') {
                    squares[i][j] = Piece.WhiteRook;
                } else if (piece == 'n') {
                    squares[i][j] = Piece.BlackKnight;
                } else if (piece == 'N') {
                    squares[i][j] = Piece.WhiteKnight;
                } else if (piece == 'b') {
                    squares[i][j] = Piece.BlackBishop;
                } else if (piece == 'B') {
                    squares[i][j] = Piece.WhiteBishop;
                } else if (piece == 'q') {
                    squares[i][j] = Piece.BlackQueen;
                } else if (piece == 'Q') {
                    squares[i][j] = Piece.WhiteQueen;
                } else if (piece == 'k') {
                    squares[i][j] = Piece.BlackKing;
                } else if (piece == 'K') {
                    squares[i][j] = Piece.WhiteKing;
                } else if (piece == 'p') {
                    squares[i][j] = Piece.BlackPawn;
                } else if (piece == 'P') {
                    squares[i][j] = Piece.WhitePawn;
                }
                j += 1;
            }
        }
        var color: Color = Color.None;
        if (pieces_pointer.next()) |c| {
            if (std.mem.eql(u8, c, "b")) {
                color = Color.Black;
            } else {
                color = Color.White;
            }
        }

        var castle_rules: ?[]const u8 = null;
        if (pieces_pointer.next()) |cr| {
            if (!std.mem.eql(u8, cr, "-")) {
                castle_rules = cr;
            }
        }

        var en_passent: ?[]const u8 = null;
        if (pieces_pointer.next()) |en| {
            if (!std.mem.eql(u8, en, "-")) {
                en_passent = en;
            }
        }

        var half_move_clock: u8 = 0;
        if (pieces_pointer.next()) |hl| {
            half_move_clock = try std.fmt.parseInt(u8, hl, 10);
        }

        var full_move_clock: u8 = 0;
        if (pieces_pointer.next()) |fl| {
            full_move_clock = try std.fmt.parseInt(u8, fl, 10);
        }

        return Self{
            .squares = squares,
            .allocator = allocator,
            .turn = color,
            .castling = castle_rules,
            .en_passent = en_passent,
            .half_move_clock = half_move_clock,
            .full_move_clock = full_move_clock,
        };
    }

    pub fn info(self: *Self) !void {
        try stdout.print("Turn = {s}\n", .{@tagName(self.turn)});
        try stdout.print("Castling rules = {?s}\n", .{self.castling});
        try stdout.print("En Passent = {?s}\n", .{self.en_passent});
        try stdout.print("Half Move Clock = {d}\n", .{self.half_move_clock});
        try stdout.print("Full Move Clock = {d}\n", .{self.full_move_clock});
    }

    pub fn play(self: *Self, s: []u8, copy: bool) !void {
        const move = try self.parse(s);
        const color = self.check_peice_color(move.from);
        if (color != Color.None) {
            if (color != self.turn) {
                try stdout.print("It is {s}'s turn\n", .{@tagName(self.turn)});
                return;
            }
        } else {
            // Modulus to prevent over and underflow
            try stdout.print("No piece in the position {c}{}\n", .{ u8cast(move.from.col) % 159 + 97, 8 - u8cast(move.from.row) % 8 });
            return;
        }
        var moves = std.ArrayList(Move).init(self.allocator);
        defer moves.deinit();

        try self.generate_legal_moves(move.from, &moves);
        var can_move = false;
        for (moves.items) |m| {
            if (move.compare(m)) {
                can_move = true;
                break;
            }
        }

        var en_passent = false;
        if (can_move == false and (self.squares[move.from.row][move.from.col] == Piece.BlackPawn or self.squares[move.from.row][move.from.col] == Piece.WhitePawn)) {
            if (self.en_passent) |en| {
                const m_ = try self.parse(@constCast(en));
                if (m_.from.row == move.to.row and m_.from.col == move.to.col) {
                    can_move = true;
                    en_passent = true;
                }
            }
        }

        var castle: ?u8 = null;
        if (self.squares[move.from.row][move.from.col] == Piece.BlackKing or self.squares[move.from.row][move.from.col] == Piece.WhiteKing) {
            castle = self.check_castle(move);
            if (castle) |_| {
                can_move = true;
            }
        }

        if (!copy and try self.is_in_check(s)) {
            try stdout.print("You are in check, not a valid move\n", .{});
        } else if (can_move) {
            // Unset the en_passent
            if (self.en_passent) |_| {
                self.en_passent = null;
            }

            // Setting en passent
            if (self.squares[move.from.row][move.from.col] == Piece.WhitePawn and move.from.row - move.to.row == 2) {
                self.en_passent = try std.fmt.allocPrint(self.allocator, "{c}{c}", .{ 97 + u8cast(move.from.col), 56 - u8cast(move.from.row) + 1 });
            } else if (self.squares[move.from.row][move.from.col] == Piece.BlackPawn and move.to.row - move.from.row == 2) {
                self.en_passent = try std.fmt.allocPrint(self.allocator, "{c}{c}", .{ 97 + u8cast(move.from.col), 56 - u8cast(move.from.row) - 1 });
            }

            try self.do_move(move);
            if (castle) |c| {
                try self.do_castle(c);
            }

            // Unset Castling after move
            if (self.castling) |_| {
                if (self.squares[move.from.row][move.from.col] == Piece.BlackKing) {
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "k", "");
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "q", "");
                } else if (self.squares[move.from.row][move.from.col] == Piece.WhiteKing) {
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "K", "");
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "Q", "");
                }
                if (self.squares[move.from.row][move.from.col] == Piece.WhiteRook and move.from.row == 7 and move.from.col == 7) {
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "K", "");
                } else if (self.squares[move.from.row][move.from.col] == Piece.WhiteRook and move.from.row == 7 and move.from.col == 0) {
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "Q", "");
                } else if (self.squares[move.from.row][move.from.col] == Piece.BlackRook and move.from.row == 0 and move.from.col == 7) {
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "k", "");
                } else if (self.squares[move.from.row][move.from.col] == Piece.BlackRook and move.from.row == 0 and move.from.col == 0) {
                    self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "q", "");
                }
                if (std.mem.eql(u8, self.castling.?, "")) {
                    self.castling = null;
                }
            }

            if (self.turn == Color.White) {
                self.turn = Color.Black;
                // Checking is move was a en passent
                if (en_passent) {
                    self.squares[move.to.row + 1][move.to.col] = null;
                    en_passent = false;
                }
            } else {
                self.turn = Color.White;
                // Checking is move was a en passent
                if (en_passent) {
                    self.squares[move.to.row - 1][move.to.col] = null;
                    en_passent = false;
                }
                self.full_move_clock += 1;
            }
            if (!copy) {
                try self.print();
            }
        } else {
            try stdout.print("Not a valid move\n", .{});
        }
        try stdout.print("\n", .{});
    }

    fn check_castle(self: *Self, move: Move) ?u8 {
        if (diff(move.from.col, move.to.col) > 2) {
            return null;
        }
        if (self.castling) |castle| {
            if (std.mem.containsAtLeast(u8, castle, 1, "k") and move.from.col < move.to.col and self.squares[move.from.row][move.from.col] == Piece.BlackKing and self.squares[move.to.row][move.to.col] == null and self.squares[move.to.row][move.to.col - 1] == null) {
                return 'k';
            } else if (std.mem.containsAtLeast(u8, castle, 1, "K") and move.from.col < move.to.col and self.squares[move.from.row][move.from.col] == Piece.WhiteKing and self.squares[move.to.row][move.to.col] == null and self.squares[move.to.row][move.to.col - 1] == null) {
                return 'K';
            } else if (std.mem.containsAtLeast(u8, castle, 1, "q") and move.from.col > move.to.col and self.squares[move.from.row][move.from.col] == Piece.BlackKing and self.squares[move.to.row][move.to.col] == null and self.squares[move.to.row][move.to.col + 1] == null) {
                return 'q';
            } else if (std.mem.containsAtLeast(u8, castle, 1, "Q") and move.from.col > move.to.col and self.squares[move.from.row][move.from.col] == Piece.WhiteKing and self.squares[move.to.row][move.to.col] == null and self.squares[move.to.row][move.to.col + 1] == null) {
                return 'Q';
            }
        }
        return null;
    }

    fn is_in_check(self: *Self, move: []u8) anyerror!bool {
        var copy = self.clone();
        try copy.play(move, true);

        var moves_list = std.ArrayList(Move).init(self.allocator);
        defer moves_list.deinit();

        var king: Position = undefined;
        for (0..8) |i| {
            for (0..8) |j| {
                const from = Position{ .row = i, .col = j };
                if (copy.turn == Color.Black) {
                    if (copy.check_peice_color(from) == Color.Black) {
                        try copy.generate_legal_moves(from, &moves_list);
                    }
                    if (copy.squares[i][j]) |p| {
                        if (p == Piece.WhiteKing) {
                            king = .{
                                .row = i,
                                .col = j,
                            };
                        }
                    }
                } else {
                    if (copy.check_peice_color(.{ .row = i, .col = j }) == Color.White) {
                        try copy.generate_legal_moves(from, &moves_list);
                    }
                    if (copy.squares[i][j]) |p| {
                        if (p == Piece.BlackKing) {
                            king = .{
                                .row = i,
                                .col = j,
                            };
                        }
                    }
                }
            }
        }
        for (moves_list.items) |m| {
            if (m.to.row == king.row and m.to.col == king.col) {
                return true;
            }
        }
        return false;
    }

    fn do_castle(self: *Self, c: u8) !void {
        if (c == 'k') {
            try self.do_move(.{
                .from = .{
                    .row = 0,
                    .col = 7,
                },
                .to = .{
                    .row = 0,
                    .col = 5,
                },
            });
            self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "k", "");
            if (std.mem.containsAtLeast(u8, self.castling.?, 1, "q")) {
                self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "q", "");
            }
        } else if (c == 'q') {
            try self.do_move(.{
                .from = .{
                    .row = 0,
                    .col = 0,
                },
                .to = .{
                    .row = 0,
                    .col = 3,
                },
            });
            self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "q", "");
            if (std.mem.containsAtLeast(u8, self.castling.?, 1, "k")) {
                self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "k", "");
            }
        } else if (c == 'K') {
            try self.do_move(.{
                .from = .{
                    .row = 7,
                    .col = 7,
                },
                .to = .{
                    .row = 7,
                    .col = 5,
                },
            });
            self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "q", "");
            if (std.mem.containsAtLeast(u8, self.castling.?, 1, "k")) {
                self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "k", "");
            }
        } else if (c == 'q') {
            try self.do_move(.{
                .from = .{
                    .row = 7,
                    .col = 0,
                },
                .to = .{
                    .row = 7,
                    .col = 3,
                },
            });
            self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "q", "");
            if (std.mem.containsAtLeast(u8, self.castling.?, 1, "k")) {
                self.castling = try std.mem.replaceOwned(u8, self.allocator, self.castling.?, "k", "");
            }
        }
        if (std.mem.eql(u8, self.castling.?, "")) {
            self.castling = null;
        }
    }

    fn check_peice_color(self: *Self, from: Position) Color {
        if (!(from.row < 8 and from.row >= 0 and from.col < 8 and from.col >= 0)) {
            return Color.None;
        }
        if (self.squares[from.row][from.col]) |square| {
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
        self.squares[move.to.row][move.to.col] = self.squares[move.from.row][move.from.col];
        self.squares[move.from.row][move.from.col] = null;
    }

    fn parse(_: *Self, move: []u8) !Move {
        var setting: [6]usize = undefined;
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
                    try stdout.print("Not a valid notation\n", .{});
                },
            }
        }
        return Move{
            .from = .{
                .row = setting[1],
                .col = setting[0],
            },
            .to = .{
                .row = setting[3],
                .col = setting[2],
            },
        };
    }

    fn generate_legal_moves(self: *Self, from: Position, moves_list: *std.ArrayList(Move)) !void {
        if (self.squares[from.row][from.col]) |piece| {
            switch (piece) {
                Piece.WhitePawn => {
                    if (i8cast(from.row) - 1 >= 0 and self.squares[from.row - 1][from.col] == null) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                .row = from.row - 1,
                                .col = from.col,
                            },
                        });
                        if (from.row == 6 and self.squares[from.row - 2][from.col] == null) {
                            try moves_list.append(Move{
                                .from = from,
                                .to = .{
                                    .row = from.row - 2,
                                    .col = from.col,
                                },
                            });
                        }
                    }
                    if (i8cast(from.row) - 1 >= 0 and i8cast(from.col) - 1 >= 0 and self.check_peice_color(.{ .row = from.row - 1, .col = from.col - 1 }) == Color.Black) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                .row = from.row - 1,
                                .col = from.col - 1,
                            },
                        });
                    }
                    if (i8cast(from.row) - 1 >= 0 and from.col + 1 < 8 and self.check_peice_color(.{ .row = from.row - 1, .col = from.col + 1 }) == Color.Black) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                .row = from.row - 1,
                                .col = from.col + 1,
                            },
                        });
                    }
                },
                Piece.BlackPawn => {
                    if (from.row + 1 < 8 and self.squares[from.row + 1][from.col] == null) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                .row = from.row + 1,
                                .col = from.col,
                            },
                        });
                        if (from.row == 1 and self.squares[from.row + 2][from.col] == null) {
                            try moves_list.append(Move{
                                .from = from,
                                .to = .{
                                    .row = from.row + 2,
                                    .col = from.col,
                                },
                            });
                        }
                    }
                    if (from.row + 1 < 8 and i8cast(from.col) - 1 >= 0 and self.check_peice_color(.{ .row = from.row + 1, .col = from.col - 1 }) == Color.White) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                .row = from.row + 1,
                                .col = from.col - 1,
                            },
                        });
                    }
                    if (from.row + 1 < 8 and from.col + 1 < 8 and self.check_peice_color(.{ .row = from.row + 1, .col = from.col + 1 }) == Color.White) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                .row = from.row + 1,
                                .col = from.col + 1,
                            },
                        });
                    }
                },
                Piece.WhiteKnight => {
                    const offsets = [_][2]i8{ .{ -2, -1 }, .{ -2, 1 }, .{ -1, 2 }, .{ 1, 2 }, .{ 2, -1 }, .{ 2, 1 }, .{ -1, -2 }, .{ 1, -2 } };
                    try self.non_sliding_piece(from, @constCast(&offsets), moves_list, Color.White);
                },
                Piece.BlackKnight => {
                    const offsets = [_][2]i8{ .{ -2, -1 }, .{ -2, 1 }, .{ -1, 2 }, .{ 1, 2 }, .{ 2, -1 }, .{ 2, 1 }, .{ -1, -2 }, .{ 1, -2 } };
                    try self.non_sliding_piece(from, @constCast(&offsets), moves_list, Color.Black);
                },
                Piece.WhiteBishop => {
                    const offsets = [_][2]i8{ .{ -1, -1 }, .{ -1, 1 }, .{ 1, -1 }, .{ 1, 1 } };
                    try self.sliding_piece(from, @constCast(&offsets), moves_list, Color.Black);
                },
                Piece.BlackBishop => {
                    const offsets = [_][2]i8{ .{ -1, -1 }, .{ -1, 1 }, .{ 1, -1 }, .{ 1, 1 } };
                    try self.sliding_piece(from, @constCast(&offsets), moves_list, Color.White);
                },
                Piece.WhiteRook => {
                    const offsets = [_][2]i8{ .{ -1, 0 }, .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 } };
                    try self.sliding_piece(from, @constCast(&offsets), moves_list, Color.Black);
                },
                Piece.BlackRook => {
                    const offsets = [_][2]i8{ .{ -1, 0 }, .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 } };
                    try self.sliding_piece(from, @constCast(&offsets), moves_list, Color.White);
                },
                Piece.WhiteQueen => {
                    // Bishop + Rook offsets = Queen offset
                    const offsets = [_][2]i8{ .{ -1, 0 }, .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 }, .{ -1, -1 }, .{ -1, 1 }, .{ 1, -1 }, .{ 1, 1 } };
                    try self.sliding_piece(from, @constCast(&offsets), moves_list, Color.Black);
                },
                Piece.BlackQueen => {
                    // Bishop + Rook offsets = Queen offset
                    const offsets = [_][2]i8{ .{ -1, 0 }, .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 }, .{ -1, -1 }, .{ -1, 1 }, .{ 1, -1 }, .{ 1, 1 } };
                    try self.sliding_piece(from, @constCast(&offsets), moves_list, Color.White);
                },
                Piece.WhiteKing => {
                    const offsets = [_][2]i8{ .{ -1, -1 }, .{ -1, 0 }, .{ -1, 1 }, .{ 0, -1 }, .{ 0, 1 }, .{ 1, -1 }, .{ 1, 0 }, .{ 1, 1 } };
                    try self.non_sliding_piece(from, @constCast(&offsets), moves_list, Color.White);
                },
                Piece.BlackKing => {
                    const offsets = [_][2]i8{ .{ -1, -1 }, .{ -1, 0 }, .{ -1, 1 }, .{ 0, -1 }, .{ 0, 1 }, .{ 1, -1 }, .{ 1, 0 }, .{ 1, 1 } };
                    try self.non_sliding_piece(from, @constCast(&offsets), moves_list, Color.Black);
                },
            }
        } else {
            try stdout.print("No Piece here\n", .{});
            try stdout.print("{} {}\n", .{ from.row, from.col });
            try stdout.print("{any}", .{self.squares[from.row][from.col]});
        }
    }

    fn non_sliding_piece(self: *Self, from: Position, offsets: [][2]i8, moves_list: *std.ArrayList(Move), own_color: Color) !void {
        for (offsets) |offset| {
            const x = i8cast(from.row) + offset[0];
            const y = i8cast(from.col) + offset[1];
            if (!self.check_bounds(x, y)) {
                continue;
            }
            const pos = Position{
                .row = @as(usize, @intCast(x)),
                .col = @as(usize, @intCast(y)),
            };
            if (self.check_peice_color(pos) != own_color) {
                try moves_list.append(Move{
                    .from = from,
                    .to = pos,
                });
            }
        }
    }

    fn sliding_piece(self: *Self, from: Position, offsets: [][2]i8, moves_list: *std.ArrayList(Move), enemy_color: Color) !void {
        for (offsets) |offset| {
            var x = i8cast(from.row);
            var y = i8cast(from.col);
            for (0..8) |_| {
                x = x + offset[0];
                y = y + offset[1];
                if (!self.check_bounds(x, y)) {
                    break;
                }
                const pos = Position{
                    .row = @as(usize, @intCast(x)),
                    .col = @as(usize, @intCast(y)),
                };
                if (self.check_peice_color(pos) == Color.None) {
                    try moves_list.append(Move{
                        .from = from,
                        .to = pos,
                    });
                } else if (self.check_peice_color(pos) == enemy_color) {
                    try moves_list.append(Move{
                        .from = from,
                        .to = pos,
                    });
                    break;
                }
            }
        }
    }

    fn check_bounds(_: *Self, x: i16, y: i16) bool {
        if (x < 8 and x >= 0 and y < 8 and y >= 0) {
            return true;
        }
        return false;
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

fn diff(x: usize, y: usize) usize {
    if (x > y) {
        return x - y;
    } else {
        return y - x;
    }
}

fn i8cast(x: usize) i8 {
    return @as(i8, @intCast(x));
}

fn u8cast(x: usize) u8 {
    return @as(u8, @intCast(x));
}
