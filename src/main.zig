const std = @import("std");
const ubu = @import("ubu");
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const range = ubu.range;

fn Value(comptime T: type, comptime domain: []const T, comptime index_for_value_fn: *const fn (val: T) anyerror!usize) type {
    return struct {
        const Self = @This();
        value: [domain.len]bool = [_]bool{false} ** domain.len,

        pub fn init(values: []const T) !Self {
            var result = Self{};
            for (values) |value| {
                try result.set(value);
            }
            return result;
        }

        pub fn init_full() Self {
            var result = Self{};
            for (result.value) |*v| {
                v.* = true;
            }
            return result;
        }

        pub fn init_single_value(value: T) !Self {
            var result = Self{};
            try result.set(value);
            return result;
        }

        pub fn len(self: *Self) usize {
            var c: usize = 0;
            for (self.value) |v| {
                if (v) {
                    c += 1;
                }
            }

            return c;
        }

        pub fn set_single_value(self: *Self, value: T) !void {
            var idx = try index_for_value_fn(value);
            var i: usize = 0;
            while (i < domain.len) : (i += 1) {
                self.value[i] = i == idx;
            }
        }

        pub fn get_single_value_index(self: *Self) !usize {
            if (self.len() == 1) {
                var idx: usize = 0;
                for (self.value) |v| {
                    if (v) {
                        return idx;
                    }
                    idx += 1;
                }
            }

            return error.NotSingleValued;
        }

        pub fn get_single_value(self: *Self) !T {
            if (self.len() == 1) {
                var idx: usize = 0;
                for (self.value) |v| {
                    if (v) {
                        return domain[idx];
                    }
                    idx += 1;
                }
            }

            return error.NotSingleValued;
        }

        pub fn set(self: *Self, value: T) !void {
            var idx = try index_for_value_fn(value);
            self.value[idx] = true;
        }

        pub fn unset(self: *Self, value: T) !bool {
            var idx = index_for_value_fn(value) catch return false;

            if (self.value[idx]) {
                self.value[idx] = false;
                return true;
            }

            return false;
        }

        pub fn has_value(self: *Self, value: T) bool {
            var idx = index_for_value_fn(value) catch return false;
            return self.value[idx];
        }

        pub fn collapse_random(self: *Self, random: std.rand.Random) void {
            var val = random.intRangeLessThan(usize, 0, self.len());
            var i: usize = 0;
            for (self.value) |*v| {
                if (v.*) {
                    v.* = (i == val);
                    i += 1;
                }
            }
        }

        pub fn print(self: *Self, w: anytype) !void {
            try w.print("[", .{});
            var idx: usize = 0;
            for (self.value) |v| {
                if (v) {
                    try w.print("{}", .{domain[idx]});
                } else {
                    try w.print("-", .{});
                }
                idx += 1;
            }
            try w.print("]", .{});
        }
    };
}

const input_board =
    \\_________
    \\_________
    \\_________
    \\_________
    \\_________
    \\_________
    \\_________
    \\_________
    \\_________
;

const Sudoku = struct {
    grid: [9][9]Cell = undefined,
    grid_queue: GridQueue = .{},
    xoshiro: std.rand.Xoshiro256 = undefined,

    const Cell = Value(u8, &[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &index_for_value);
    const GridQueue = ubu.StaticQueue([9][9]Cell, 1024);
    const LineChars = struct {
        horizontal: []const u8 = "─",
        vertical: []const u8 = "│",
        top_left: []const u8 = "┌",
        top_right: []const u8 = "┐",
        bottom_left: []const u8 = "└",
        bottom_right: []const u8 = "┘",
        midle_midle_intersect: []const u8 = "┼",
        middle_top_intersect: []const u8 = "┬",
        middle_left_intersect: []const u8 = "├",
        middle_right_intersect: []const u8 = "┤",
        middle_bottom_intersect: []const u8 = "┴",
    };
    const line_chars = LineChars{};

    pub fn init_with_board(board: []const u8) !Sudoku {
        var s = Sudoku{};

        var row: usize = 0;
        var col: usize = 0;
        for (board) |ch| {
            switch (ch) {
                '_' => {
                    s.grid[row][col] = Cell.init_full();
                    col += 1;
                },
                '0'...'9' => {
                    s.grid[row][col] = try Cell.init_single_value(ch - 48);
                    col += 1;
                },
                '\n' => {
                    row += 1;
                    col = 0;
                },
                else => {},
            }
        }

        s.xoshiro = std.rand.Xoshiro256.init(@intCast(u64, std.time.timestamp()));

        return s;
    }

    pub fn propagate_cells(cells: []const *Cell) !usize {
        var num_collapsed: usize = 0;
        for (range(9)) |i| {
            var current = cells[i];
            if (current.len() == 1) {
                var idx = try current.get_single_value_index();
                for (range(9)) |j| {
                    if (i == j) continue;

                    var cell = cells[j];
                    if (cell.len() > 1) {
                        cell.value[idx] = false;
                        if (cell.len() == 1) {
                            num_collapsed += 1;
                        }
                    } else if (cell.len() == 1) {
                        if (idx == try cell.get_single_value_index()) {
                            return error.RepeatedSingleValue;
                        }
                    } else {
                        return error.EmptyCell;
                    }
                }
            }
        }

        return num_collapsed;
    }

    pub fn propagate_row(self: *Sudoku, row: usize) !usize {
        var cells: [9]*Cell = undefined;

        for (range(9)) |col| {
            cells[col] = &self.grid[row][col];
        }

        return propagate_cells(&cells);
    }

    pub fn propagate_col(self: *Sudoku, col: usize) !usize {
        var cells: [9]*Cell = undefined;

        for (range(9)) |row| {
            cells[row] = &self.grid[row][col];
        }

        return propagate_cells(&cells);
    }

    pub fn propagate_square(self: *Sudoku, row: usize, col: usize) !usize {
        const inc = [3]usize{ 0, 3, 6 };
        var cells: [9]*Cell = undefined;

        var i: usize = 0;
        for (range(3)) |r| {
            for (range(3)) |c| {
                cells[i] = &self.grid[inc[row] + r][inc[col] + c];
                i += 1;
            }
        }

        return propagate_cells(&cells);
    }

    pub fn propagate_rows(self: *Sudoku) !usize {
        var acc: usize = 0;
        for (range(9)) |row| {
            acc += try self.propagate_row(row);
        }

        return acc;
    }

    pub fn propagate_cols(self: *Sudoku) !usize {
        var acc: usize = 0;
        for (range(9)) |col| {
            acc += try self.propagate_col(col);
        }

        return acc;
    }

    pub fn propagate_squares(self: *Sudoku) !usize {
        var acc: usize = 0;
        for (range(3)) |row| {
            for (range(3)) |col| {
                acc += try self.propagate_square(row, col);
            }
        }

        return acc;
    }

    pub fn propagate(self: *Sudoku) !usize {
        var acc: usize = 0;

        acc += try self.propagate_rows();
        acc += try self.propagate_cols();
        acc += try self.propagate_squares();

        return acc;
    }

    pub fn is_complete(self: *Sudoku) bool {
        for (range(9)) |row| {
            for (range(9)) |col| {
                var cell = &self.grid[row][col];
                if (cell.len() != 1) {
                    return false;
                }
            }
        }

        return true;
    }

    pub fn find_cell_with_lowest_entropy(self: *Sudoku) ?*Cell {
        var cell: ?*Cell = null;
        var n: usize = 1000;
        for (range(9)) |row| {
            for (range(9)) |col| {
                var current_cell = &self.grid[row][col];
                var len = current_cell.len();

                if ((cell == null or len < n) and len > 1) {
                    cell = current_cell;
                    n = len;
                }
            }
        }
        return cell;
    }

    pub fn solve(self: *Sudoku) !void {
        var count = self.propagate() catch return error.InvalidInput;

        while (!self.is_complete()) {
            // try self.print_pretty(stdout);
            // try stdout.print("stack len = {}", .{self.grid_stack.len});
            if (count == 0) {
                if (self.find_cell_with_lowest_entropy()) |cell| {
                    // try self.grid_stack.push(self.grid);
                    try self.grid_queue.enqueue(self.grid);
                    std.log.info("queue count = {}", .{self.grid_queue.count()});
                    cell.collapse_random(self.xoshiro.random());
                    count = 1;
                } else {
                    unreachable;
                }
            }

            count = self.propagate() catch {
                self.grid = self.grid_queue.dequeue().?;
                continue;
            };
        }
    }

    pub fn print(self: *Sudoku, w: anytype) !void {
        var row: usize = 0;
        while (row < 9) : (row += 1) {
            var col: usize = 0;
            while (col < 9) : (col += 1) {
                var cell = &self.grid[row][col];
                if (cell.len() == 1) {
                    try w.print("|{}", .{try cell.get_single_value()});
                } else {
                    try w.print("|*", .{});
                }
            }
            try w.print("|\n", .{});
        }

        try w.print("\n", .{});
    }

    pub fn print_full(self: *Sudoku, w: anytype) !void {
        var row: usize = 0;
        while (row < 9) : (row += 1) {
            var col: usize = 0;
            while (col < 9) : (col += 1) {
                var cell = &self.grid[row][col];
                try cell.print(w);
            }
            try w.print("|\n", .{});
        }

        try w.print("\n", .{});
    }

    pub fn print_pretty(self: *Sudoku, w: anytype) !void {
        try w.print("\n{s}", .{line_chars.top_left});
        for (range(7)) |_| {
            try w.print("{s}", .{line_chars.horizontal});
        }

        try w.print("{s}", .{line_chars.middle_top_intersect});

        for (range(7)) |_| {
            try w.print("{s}", .{line_chars.horizontal});
        }

        try w.print("{s}", .{line_chars.middle_top_intersect});

        for (range(7)) |_| {
            try w.print("{s}", .{line_chars.horizontal});
        }

        try w.print("{s}\n", .{line_chars.top_right});

        for (range(9)) |row| {
            if (row > 0 and row % 3 == 0) {
                try w.print("{s}", .{line_chars.middle_left_intersect});
                for (range(7)) |_| {
                    try w.print("{s}", .{line_chars.horizontal});
                }
                try w.print("{s}", .{line_chars.midle_midle_intersect});
                for (range(7)) |_| {
                    try w.print("{s}", .{line_chars.horizontal});
                }
                try w.print("{s}", .{line_chars.midle_midle_intersect});
                for (range(7)) |_| {
                    try w.print("{s}", .{line_chars.horizontal});
                }
                try w.print("{s}", .{line_chars.middle_right_intersect});

                try w.print("\n", .{});
            }

            try w.print("{s}", .{line_chars.vertical});
            for (range(9)) |col| {
                if (col > 0 and col % 3 == 0) {
                    try w.print(" {s}", .{line_chars.vertical});
                }
                var cell = self.grid[row][col];
                if (cell.len() == 1) {
                    try w.print(" {}", .{try self.grid[row][col].get_single_value()});
                } else {
                    try w.print(" *", .{});
                }
            }
            try w.print(" {s}\n", .{line_chars.vertical});
        }

        try w.print("{s}", .{line_chars.bottom_left});
        for (range(7)) |_| {
            try w.print("{s}", .{line_chars.horizontal});
        }
        try w.print("{s}", .{line_chars.middle_bottom_intersect});
        for (range(7)) |_| {
            try w.print("{s}", .{line_chars.horizontal});
        }
        try w.print("{s}", .{line_chars.middle_bottom_intersect});
        for (range(7)) |_| {
            try w.print("{s}", .{line_chars.horizontal});
        }
        try w.print("{s}", .{line_chars.bottom_right});
    }
};

fn index_for_value(value: u8) !usize {
    if (value < 1 or value > 9) {
        return error.OutOfRange;
    }

    return value - 1;
}

pub fn main() !void {
    var args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    var grid: []const u8 = input_board;
    var buf: [1024]u8 = undefined;
    var len: usize = 0;
    if (args.len >= 2) {
        var f = std.fs.cwd().openFile(args[1], .{}) catch {
            try stderr.print("Failed to open file!", .{});
            std.os.exit(1);
        };
        len = try f.readAll(&buf);
        grid = buf[0..len];
    }

    var s = try Sudoku.init_with_board(grid);
    try s.print_pretty(stdout);
    try s.solve();
    try s.print_pretty(stdout);
}
