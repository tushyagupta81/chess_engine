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
        if (can_move == false and (self.squares[move.from.@"0"][move.from.@"1"] == Piece.BlackPawn or self.squares[move.from.@"0"][move.from.@"1"] == Piece.WhitePawn)) {
            if (self.en_passent) |en| {
                const m_ = try self.parse(@constCast(en));
                if (m_.from.@"0" == move.to.@"0" and m_.from.@"1" == move.to.@"1") {
                    can_move = true;
                    en_passent = true;
                }
            }
        }

        if (can_move) {
            // Unset the en_passent
            if (self.en_passent) |_| {
                self.en_passent = null;
            }

            // Setting en passent
            if (self.squares[move.from.@"0"][move.from.@"1"] == Piece.WhitePawn and move.from.@"0" - move.to.@"0" == 2) {
                self.en_passent = try std.fmt.allocPrint(self.allocator, "{c}{c}", .{ 97 + move.from.@"1", 56 - move.from.@"0" + 1 });
            } else if (self.squares[move.from.@"0"][move.from.@"1"] == Piece.BlackPawn and move.to.@"0" - move.from.@"0" == 2) {
                self.en_passent = try std.fmt.allocPrint(self.allocator, "{c}{c}", .{ 97 + move.from.@"1", 56 - move.from.@"0" - 1 });
            }

            try self.do_move(move);

            if (self.turn == Color.White) {
                self.turn = Color.Black;
                // Checking is move was a en passent
                if (en_passent) {
                    self.squares[move.to.@"0" + 1][move.to.@"1"] = null;
                    en_passent = false;
                }
            } else {
                self.turn = Color.White;
                // Checking is move was a en passent
                if (en_passent) {
                    self.squares[move.to.@"0" - 1][move.to.@"1"] = null;
                    en_passent = false;
                }
                self.full_move_clock += 1;
            }
            try self.print();
        } else {
            try stdout.print("Not a valid move\n", .{});
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

    pub fn generate_legal_moves(self: *Self, from: struct { u8, u8 }, moves_list: *std.ArrayList(Move)) !void {
        if (self.squares[from.@"0"][from.@"1"]) |piece| {
            switch (piece) {
                Piece.WhitePawn => {
                    if (@as(i16, from.@"0") - 1 >= 0 and self.squares[from.@"0" - 1][from.@"1"] == null) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                from.@"0" - 1,
                                from.@"1",
                            },
                        });
                        if (from.@"0" == 6 and self.squares[from.@"0" - 2][from.@"1"] == null) {
                            try moves_list.append(Move{
                                .from = from,
                                .to = .{
                                    from.@"0" - 2,
                                    from.@"1",
                                },
                            });
                        }
                    }
                    if (@as(i16, from.@"0") - 1 >= 0 and @as(i16, from.@"1") - 1 >= 0 and self.check_peice_color(.{ from.@"0" - 1, from.@"1" - 1 }) == Color.Black) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                from.@"0" - 1,
                                from.@"1" - 1,
                            },
                        });
                    }
                    if (@as(i16, from.@"0" - 1) >= 0 and from.@"1" + 1 < 8 and self.check_peice_color(.{ from.@"0" - 1, from.@"1" + 1 }) == Color.Black) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                from.@"0" - 1,
                                from.@"1" + 1,
                            },
                        });
                    }
                },
                Piece.BlackPawn => {
                    if (from.@"0" + 1 < 8 and self.squares[from.@"0" + 1][from.@"1"] == null) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                from.@"0" + 1,
                                from.@"1",
                            },
                        });
                        if (from.@"0" == 1 and self.squares[from.@"0" + 2][from.@"1"] == null) {
                            try moves_list.append(Move{
                                .from = from,
                                .to = .{
                                    from.@"0" + 2,
                                    from.@"1",
                                },
                            });
                        }
                    }
                    if (from.@"0" + 1 < 8 and @as(i16, from.@"1") - 1 >= 0 and self.check_peice_color(.{ from.@"0" + 1, from.@"1" - 1 }) == Color.White) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                from.@"0" + 1,
                                from.@"1" - 1,
                            },
                        });
                    }
                    if (from.@"0" + 1 < 8 and from.@"1" + 1 < 8 and self.check_peice_color(.{ from.@"0" + 1, from.@"1" + 1 }) == Color.White) {
                        try moves_list.append(Move{
                            .from = from,
                            .to = .{
                                from.@"0" + 1,
                                from.@"1" + 1,
                            },
                        });
                    }
                },
                Piece.WhiteKnight => {
                    const offsets = [_][2]i8{ .{ -2, -1 }, .{ -2, 1 }, .{ -1, 2 }, .{ 1, 2 }, .{ 2, -1 }, .{ 2, 1 }, .{ -1, -2 }, .{ 1, -2 } };
                    for (0..8) |i| {
                        const x = @max(0, @as(i8, @intCast(from.@"0")) + offsets[i][0]);
                        const y = @max(0, @as(i8, @intCast(from.@"1")) + offsets[i][1]);
                        if (self.check_bounds(x, y) and self.check_peice_color(.{ x, y }) != Color.White) {
                            try moves_list.append(Move{
                                .from = from,
                                .to = .{
                                    x,
                                    y,
                                },
                            });
                        }
                    }
                },
                Piece.BlackKnight => {
                    const offsets = [_][2]i8{ .{ -2, -1 }, .{ -2, 1 }, .{ -1, 2 }, .{ 1, 2 }, .{ 2, -1 }, .{ 2, 1 }, .{ -1, -2 }, .{ 1, -2 } };
                    for (0..8) |i| {
                        const x = @max(0, @as(i8, @intCast(from.@"0")) + offsets[i][0]);
                        const y = @max(0, @as(i8, @intCast(from.@"1")) + offsets[i][1]);
                        if (self.check_bounds(x, y) and self.check_peice_color(.{ x, y }) != Color.Black) {
                            try moves_list.append(Move{
                                .from = from,
                                .to = .{
                                    x,
                                    y,
                                },
                            });
                        }
                    }
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
            try stdout.print("{} {}\n", .{ from.@"0", from.@"1" });
            try stdout.print("{any}", .{self.squares[from.@"0"][from.@"1"]});
        }
    }

    fn non_sliding_piece(self: *Self, from: struct { u8, u8 }, offsets: [][2]i8, moves_list: *std.ArrayList(Move), own_color: Color) !void {
        for (offsets) |offset| {
            const x = @max(0, @as(i8, @intCast(from.@"0")) + offset[0]);
            const y = @max(0, @as(i8, @intCast(from.@"1")) + offset[1]);
            if (!self.check_bounds(x, y)) {
                break;
            }
            if (self.check_peice_color(.{ @as(u8, @intCast(x)), @as(u8, @intCast(y)) }) != own_color) {
                try moves_list.append(Move{
                    .from = from,
                    .to = .{
                        @as(u8, @intCast(x)),
                        @as(u8, @intCast(y)),
                    },
                });
            }
        }
    }

    fn sliding_piece(self: *Self, from: struct { u8, u8 }, offsets: [][2]i8, moves_list: *std.ArrayList(Move), enemy_color: Color) !void {
        for (offsets) |offset| {
            var x = @as(i8, @intCast(from.@"0"));
            var y = @as(i8, @intCast(from.@"1"));
            for (0..8) |_| {
                x = @max(0, x + offset[0]);
                y = @max(0, y + offset[1]);
                if (!self.check_bounds(x, y)) {
                    break;
                }
                if (self.check_peice_color(.{ @as(u8, @intCast(x)), @as(u8, @intCast(y)) }) == Color.None) {
                    try moves_list.append(Move{
                        .from = from,
                        .to = .{
                            @as(u8, @intCast(x)),
                            @as(u8, @intCast(y)),
                        },
                    });
                } else if (self.check_peice_color(.{ @as(u8, @intCast(x)), @as(u8, @intCast(y)) }) == enemy_color) {
                    try moves_list.append(Move{
                        .from = from,
                        .to = .{
                            @as(u8, @intCast(x)),
                            @as(u8, @intCast(y)),
                        },
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
