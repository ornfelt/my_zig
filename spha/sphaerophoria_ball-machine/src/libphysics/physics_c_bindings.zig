const std = @import("std");
const physics = @import("physics");
const Pos2 = physics.Pos2;
const Vec2 = physics.Vec2;
const Ball = physics.Ball;
const Surface = physics.Surface;
const c = @cImport({
    @cInclude("physics.h");
});

fn assertTypesAreSame(comptime T: type, comptime U: type) void {
    if (T == U) {
        return;
    }

    if (@typeInfo(T) == .Pointer) {
        assertTypesAreSame(@typeInfo(T).Pointer.child, @typeInfo(U).Pointer.child);
        return;
    }

    std.debug.assert(@sizeOf(T) == @sizeOf(U));
    std.debug.assert(@bitSizeOf(T) == @bitSizeOf(U));
    std.debug.assert(@alignOf(T) == @alignOf(U));

    std.debug.assert(std.meta.fields(T).len == std.meta.fields(U).len);

    inline for (std.meta.fields(T)) |field| {
        std.debug.assert(@offsetOf(T, field.name) == @offsetOf(U, field.name));
        const t_idx = std.meta.fieldIndex(T, field.name).?;
        const u_idx = std.meta.fieldIndex(T, field.name).?;
        const t_field = std.meta.fields(T)[t_idx];
        const u_field = std.meta.fields(U)[u_idx];
        assertTypesAreSame(t_field.type, u_field.type);
    }
}

fn assertFnSignitures() void {
    inline for (@typeInfo(@This()).Struct.decls) |decl| {
        if (@hasDecl(c, decl.name)) {
            const c_fn = @field(c, decl.name);
            const this_fn = @field(@This(), decl.name);

            const c_info = @typeInfo(@TypeOf(c_fn)).Fn;
            const this_info = @typeInfo(@TypeOf(this_fn)).Fn;

            std.debug.assert(c_info.params.len == this_info.params.len);
            assertTypesAreSame(c_info.return_type.?, this_info.return_type.?);

            inline for (0..c_info.params.len) |i| {
                assertTypesAreSame(c_info.params[i].type.?, this_info.params[i].type.?);
            }
        }
    }
}

comptime {
    assertFnSignitures();
}

pub export fn pos2_add(p: *const Pos2, v: *const Vec2) Pos2 {
    return p.add(v.*);
}

pub export fn pos2_sub(a: *const Pos2, b: *const Pos2) Vec2 {
    return a.sub(b.*);
}

pub export fn vec2_length_2(self: *const Vec2) f32 {
    return self.length_2();
}

pub export fn vec2_length(self: *const Vec2) f32 {
    return self.length();
}

pub export fn vec2_add(a: *const Vec2, b: *const Vec2) Vec2 {
    return a.add(b.*);
}

pub export fn vec2_sub(a: *const Vec2, b: *const Vec2) Vec2 {
    return a.sub(b.*);
}

pub export fn vec2_mul(self: *const Vec2, val: f32) Vec2 {
    return self.mul(val);
}

pub export fn vec2_dot(a: *const Vec2, b: *const Vec2) f32 {
    return a.dot(b.*);
}

pub export fn vec2_normalized(self: *const Vec2) Vec2 {
    return self.normalized();
}

pub export fn surface_collision_resolution(surface: *const Surface, p: *const Pos2, v: *const Vec2, out: *Vec2) bool {
    if (surface.collisionResolution(p.*, v.*)) |res| {
        out.* = res;
        return true;
    }
    return false;
}

pub export fn surface_push_if_colliding(surface: *const Surface, ball: *Ball, obj_velocity: *const Vec2, delta: f32, max_push: f32) void {
    return surface.pushIfColliding(ball, obj_velocity.*, delta, max_push);
}

pub export fn surface_normal(surface: *const Surface) Vec2 {
    return surface.normal();
}

pub export fn apply_ball_collision(ball: *Ball, resolution: *const Vec2, obj_normal: *const Vec2, obj_velocity: *const Vec2, delta: f32, elasticity: f32) void {
    physics.applyCollision(ball, resolution.*, obj_normal.*, obj_velocity.*, delta, elasticity);
}

pub export fn apply_ball_ball_collision(a: *Ball, b: *Ball) void {
    physics.applyBallCollision(a, b);
}

pub export fn apply_gravity(ball: *Ball, delta: f32) void {
    physics.applyGravity(ball, delta);
}
