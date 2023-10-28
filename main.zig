const std = @import("std");
const c = @import("c.zig");

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const CELL_SIZE = 10;
const GRID_WIDTH = WINDOW_WIDTH/CELL_SIZE;
const GRID_HEIGHT = WINDOW_HEIGHT/CELL_SIZE;

const FAST_FORWARD_KEY = c.KEY_SPACE;
const FAST_FORWARD_MULTIPLIER = 2.5;
const DEFAULT_DELAY = std.time.ns_per_ms * 200;

const WRAPPING = true;

const DYING_COLOR = c.GRAY;
const OFF_COLOR = c.WHITE;
const ON_COLOR = c.BLACK;

const CellState = enum {
    on,
    dying,
    off
};

fn shouldBirth(grid: [GRID_HEIGHT*GRID_WIDTH]CellState, x: i32, y: i32) bool {
    var alive_count: usize = 0;
    // hack because zig's ranges have to be usize
    const map = [_]i32{-1, 0, 1};
    for (0..3) |y_offset_idx| {
        for (0..3) |x_offset_idx| {
            const cell = blk: {
                const x_offset = map[x_offset_idx];
                const y_offset = map[y_offset_idx];
                if (x_offset == 0 and y_offset == 0) continue;
                var new_y: i32 = y + y_offset;
                var new_x: i32 = x + x_offset;
                if (new_y < 0 or new_x < 0) break :blk null;
                if (new_y >= GRID_HEIGHT or new_x >= GRID_WIDTH) break :blk null;
                break :blk grid[@intCast(new_y*GRID_HEIGHT+new_x)];
            };
            if (cell) |ce| {
                if (ce == .on) {
                    alive_count += 1;
                    if (alive_count > 2) return false;
                }
            }
        }
    }
    return alive_count == 2;
}

fn next(grid: *[GRID_HEIGHT*GRID_WIDTH]CellState) void {
    var grid_copy = grid.*;
    for (0..GRID_HEIGHT) |y| {
        for (0..GRID_WIDTH) |x| {
            const cell = &grid.*[y*GRID_HEIGHT+x];
            switch (cell.*) {
                .on => cell.* = .dying,
                .dying => cell.* = .off,
                .off => {
                    if (shouldBirth(grid_copy, @intCast(x), @intCast(y))) cell.* = .on;
                },
            }
        }
    }
    if (WRAPPING) {
        for (0..GRID_HEIGHT) |y| {
            if (shouldBirth(grid_copy, -1,         @intCast(y))) grid[y*GRID_HEIGHT+GRID_WIDTH-1] = .on;
            if (shouldBirth(grid_copy, GRID_WIDTH, @intCast(y))) grid[y*GRID_HEIGHT+0] = .on;
        }
        for (0..GRID_WIDTH) |x| {
            if (shouldBirth(grid_copy, @intCast(x), -1)) grid[GRID_HEIGHT*GRID_HEIGHT+x] = .on;
            if (shouldBirth(grid_copy, @intCast(x), GRID_HEIGHT)) grid[0*GRID_HEIGHT+x] = .on;
        }
    }
}

pub fn main() !void {
    var seed: u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var pga = std.rand.Pcg.init(seed);
    const rand = pga.random();

    var grid: [GRID_HEIGHT*GRID_WIDTH]CellState = undefined;
    // initialize half the board as on and the rest as off
    for (&grid) |*e| e.* = if (rand.float(f32) >= 0.40) .off else if (rand.boolean()) .on else .dying;

    c.SetTargetFPS(60);
    c.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "welp");
    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
            c.ClearBackground(OFF_COLOR);
            inline for (0..GRID_HEIGHT) |y| {
                for (0..GRID_WIDTH) |x| {
                    const cell = grid[y*GRID_HEIGHT+x];
                    const pixel_x = x*CELL_SIZE;
                    const pixel_y = y*CELL_SIZE;
                    const color = switch (cell) {
                        .off  => null,
                        .on  => ON_COLOR,
                        .dying  => DYING_COLOR,
                    };
                    if (color) |col| c.DrawRectangle(@intCast(pixel_x), @intCast(pixel_y), CELL_SIZE, CELL_SIZE, col);
                }
            }
        c.EndDrawing();
        const sleepy_time: u64 = if (c.IsKeyDown(FAST_FORWARD_KEY)) @divFloor(DEFAULT_DELAY, FAST_FORWARD_MULTIPLIER) else DEFAULT_DELAY;
        std.time.sleep(sleepy_time);
        next(&grid);
    }
    c.CloseWindow();
}
