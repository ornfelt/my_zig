const std = @import("std");
const physics = @import("physics");
const Ball = physics.Ball;
const Surface = physics.Surface;
const Allocator = std.mem.Allocator;

const Direction = enum(u8) {
    right,
    left,

    pub fn flip(self: *Direction) void {
        if (self.* == .right) {
            self.* = .left;
        } else {
            self.* = .right;
        }
    }
};

const num_platforms = 4;
const platform_ys: [num_platforms]f32 = .{ 0.1, 0.25, 0.4, 0.55 };
const platform_height_norm = 0.03;
const platform_width_norm = 0.3;

pub const State = struct {
    platform_locs: [num_platforms]f32 = .{ 0.5, 0.2, 0.4, 0.7 },
    directions: [num_platforms]Direction = .{ .right, .left, .right, .left },
};

var balls: []Ball = undefined;
var chamber_pixels: []u32 = undefined;
const save_size = 20;
var save_data: [save_size]u8 = undefined;

var state = State{};

pub export fn init(max_balls: usize, max_chamber_pixels: usize) void {
    physics.assertBallLayout();
    balls = std.heap.wasm_allocator.alloc(Ball, max_balls) catch {
        return;
    };

    chamber_pixels = std.heap.wasm_allocator.alloc(u32, max_chamber_pixels) catch {
        return;
    };
}

pub export fn saveSize() usize {
    return save_size;
}

pub export fn saveMemory() [*]u8 {
    return &save_data;
}

pub export fn ballsMemory() [*]Ball {
    return balls.ptr;
}

pub export fn canvasMemory() i32 {
    return @intCast(@intFromPtr(chamber_pixels.ptr));
}

pub export fn save() void {
    for (0..state.platform_locs.len) |i| {
        const start = i * 4;
        const end = start + 4;
        @memcpy(save_data[start..end], std.mem.asBytes(&state.platform_locs[i]));
        save_data[16 + i] = @intFromEnum(state.directions[i]);
    }
}

pub export fn load() void {
    // FIXME: endianness
    var platform_locs: [num_platforms]f32 = undefined;
    var directions: [num_platforms]Direction = undefined;
    for (0..num_platforms) |i| {
        const start = i * 4;
        const end = start + 4;
        platform_locs[i] = std.mem.bytesToValue(f32, save_data[start..end]);
        directions[i] = @enumFromInt(save_data[16 + i]);
    }

    state = .{
        .platform_locs = platform_locs,
        .directions = directions,
    };
}

pub export fn step(num_balls: usize, delta: f32) void {
    const speed = 1.0;

    for (balls[0..num_balls]) |*ball| {
        physics.applyGravity(ball, delta);
    }

    for (0..num_platforms) |i| {
        var movement = speed * delta;

        switch (state.directions[i]) {
            .left => {
                movement *= -1;
            },
            .right => {},
        }

        const obj = Surface{
            .a = .{
                .x = state.platform_locs[i] - platform_width_norm / 2.0,
                .y = platform_ys[i],
            },
            .b = .{
                .x = state.platform_locs[i] + platform_width_norm / 2.0,
                .y = platform_ys[i],
            },
        };

        const obj_normal = obj.normal();
        for (balls[0..num_balls]) |*ball| {
            const ball_collision_point_offs = obj_normal.mul(-ball.r);
            const ball_collision_point = ball.pos.add(ball_collision_point_offs);

            const resolution = obj.collisionResolution(ball_collision_point, ball.velocity.mul(delta));
            if (resolution) |r| {
                ball.velocity.x += (movement / delta - ball.velocity.x) * 0.3;
                physics.applyCollision(ball, r, obj_normal, physics.Vec2.zero, delta, 0.9);
            }

            obj.pushIfColliding(ball, physics.Vec2.zero, delta, 0.001);
        }
        state.platform_locs[i] += movement;
        state.platform_locs[i] = @mod(state.platform_locs[i], 2.0);

        if (state.platform_locs[i] >= 1.0) {
            state.directions[i].flip();
            state.platform_locs[i] = 2.0 - state.platform_locs[i];
        }
    }
}

pub export fn render(canvas_width: usize, canvas_height: usize) void {
    @memset(chamber_pixels, 0xffffffff);
    const canvas_width_f: f32 = @floatFromInt(canvas_width);
    const canvas_height_f: f32 = @floatFromInt(canvas_height);
    const num_y_px: usize = @intFromFloat(platform_height_norm * canvas_width_f);

    for (0..num_platforms) |i| {
        var platform_x_start_norm = state.platform_locs[i] - platform_width_norm / 2.0;
        var platform_x_end_norm = platform_x_start_norm + platform_width_norm;
        platform_x_start_norm = @max(0.0, platform_x_start_norm);
        platform_x_end_norm = @min(1.0, platform_x_end_norm);

        const platform_x_start_px: usize = @intFromFloat(platform_x_start_norm * canvas_width_f);
        const platform_x_end_px: usize = @intFromFloat(platform_x_end_norm * canvas_width_f);

        const y_px_start: usize = @intFromFloat(canvas_height_f - platform_ys[i] * canvas_width_f);

        for (0..num_y_px) |y_offs| {
            const y_px = y_px_start + y_offs;
            const pixel_row_start = y_px * canvas_width;

            for (platform_x_start_px..platform_x_end_px) |x| {
                chamber_pixels[pixel_row_start + x] = 0xff000000;
            }
        }
    }
}
