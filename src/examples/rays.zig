const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var camera: delve.graphics.camera.Camera = undefined;

var material_frustum: delve.platform.graphics.Material = undefined;
var material_cube: delve.platform.graphics.Material = undefined;
var material_highlight: delve.platform.graphics.Material = undefined;
var material_hitpoint: delve.platform.graphics.Material = undefined;

var frustum_mesh: delve.graphics.mesh.Mesh = undefined;
var cube_mesh: delve.graphics.mesh.Mesh = undefined;
var hit_mesh: delve.graphics.mesh.Mesh = undefined;
var ray_mesh: delve.graphics.mesh.Mesh = undefined;

var time: f32 = 0.0;

// EMSCRIPTEN HACK! See https://github.com/ziglang/zig/issues/19072
const builtin = @import("builtin");
pub const os = if (builtin.os.tag != .wasi and builtin.os.tag != .emscripten) std.os else struct {
    pub const heap = struct {
        pub const page_allocator = std.heap.c_allocator;
    };
};

pub fn main() !void {
    const example = delve.modules.Module{
        .name = "rays_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
    };

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Ray Collision Example" });
}

pub fn on_init() !void {
    // Create a material out of the texture
    material_frustum = delve.platform.graphics.Material.init(.{
        .shader = delve.platform.graphics.Shader.initDefault(.{}),
        .texture_0 = delve.platform.graphics.createSolidTexture(0x66FFFFFF),
        .cull_mode = .NONE,
        .depth_write_enabled = false,
        .blend_mode = .BLEND,
    });

    material_cube = delve.platform.graphics.Material.init(.{
        .shader = delve.platform.graphics.Shader.initDefault(.{}),
        .texture_0 = delve.platform.graphics.tex_white,
    });

    material_highlight = delve.platform.graphics.Material.init(.{
        .shader = delve.platform.graphics.Shader.initDefault(.{}),
        .texture_0 = delve.platform.graphics.createSolidTexture(0xFF0000CC),
    });

    material_hitpoint = delve.platform.graphics.Material.init(.{
        .shader = delve.platform.graphics.Shader.initDefault(.{}),
        .texture_0 = delve.platform.graphics.createSolidTexture(0xFFFF0000),
    });

    // create our two cameras - one for the real camera, and another just to get a smaller frustum from
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 100.0, 5.0, delve.math.Vec3.up);

    // set initial camera position
    camera.position = delve.math.Vec3.new(0, 30, 32);
    camera.pitch_angle = -50.0;

    cube_mesh = delve.graphics.mesh.createCube(delve.math.Vec3.new(0, 0, 0), delve.math.Vec3.new(1, 1, 1), delve.colors.white, material_cube) catch {
        delve.debug.fatal("Could not create cube mesh!", .{});
        return;
    };

    hit_mesh = delve.graphics.mesh.createCube(delve.math.Vec3.new(0, 0, 0), delve.math.Vec3.new(0.5, 0.5, 0.5), delve.colors.white, material_cube) catch {
        delve.debug.fatal("Could not create cube mesh!", .{});
        return;
    };

    ray_mesh = delve.graphics.mesh.createCube(delve.math.Vec3.new(50, 0, 0), delve.math.Vec3.new(100, 0.1, 0.1), delve.colors.red, material_cube) catch {
        delve.debug.fatal("Could not create cube mesh!", .{});
        return;
    };

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);

    // capture mouse
    delve.platform.app.captureMouse(true);
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    time += delta;

    camera.runSimpleCamera(8 * delta, 120 * delta, true);
}

pub fn on_draw() void {
    const proj_view_matrix = camera.getProjView();

    const ray_start = delve.math.Vec3.new(0, 0, 0);
    var ray_dir = delve.math.Vec3.new(1.0, 0.0, 0.0);
    ray_dir = ray_dir.rotate(time * 10.0, delve.math.Vec3.up);

    const ray = delve.spatial.Ray.init(ray_start, ray_dir);

    for (0..10) |x| {
        for (0..10) |z| {
            const x_f: f32 = @floatFromInt(x);
            const z_f: f32 = @floatFromInt(z);

            const x_offset = std.math.sin((time + z_f) * 5.0) * 0.2;
            const cube_pos = delve.math.Vec3.new(x_f + x_offset, 0, z_f).scale(5.0).sub(delve.math.Vec3.new(25, 0, 25));
            const cube_model_matrix = delve.math.Mat4.translate(cube_pos).mul(delve.math.Mat4.rotate(time * 20.0, delve.math.Vec3.new(1.0, 1.0, 0.0))).mul(delve.math.Mat4.scale(delve.math.Vec3.new(2.0, 1.0, 1.0)));

            const bounds = delve.spatial.OrientedBoundingBox.init(delve.math.Vec3.zero, delve.math.Vec3.new(1, 1, 1), cube_model_matrix);
            const rayhit = ray.intersectOrientedBoundingBox(bounds);

            if (rayhit != null) {
                cube_mesh.drawWithMaterial(&material_highlight, proj_view_matrix, cube_model_matrix);

                const hit_model_matrix = delve.math.Mat4.translate(rayhit.?.hit_pos);
                hit_mesh.drawWithMaterial(&material_hitpoint, proj_view_matrix, hit_model_matrix);
            } else {
                cube_mesh.draw(proj_view_matrix, cube_model_matrix);
            }
        }
    }

    ray_mesh.draw(proj_view_matrix, delve.math.Mat4.rotate(time * 10.0, delve.math.Vec3.up));
}
