package masterclass

import "core:fmt";
import "core:os";
import "core:c";
import "core:math";
import "core:math/linalg";
import "core:mem";
import "core:path/filepath";
import "core:strings";
import "base:runtime";
import glfw "vendor:glfw";
import gl "vendor:OpenGL";

STRIP_MOST_QUERIES :: false

@(export, link_name="NvOptimusEnablement")
NvOptimusEnablement: u32 = 0x00000001;

@(export, link_name="AmdPowerXpressRequestHighPerformance")
AmdPowerXpressRequestHighPerformance: i32 = 1;


Resolution :: enum {
    X1  = 0,
    X2  = 1,
    X4  = 2,
}


Binary_Format :: enum u16 {
    f32,
    f16,

    u24,
    u16,
    u8,

    s24,
    s16,
    s8,
}

Binary_Header :: struct {
    Nx: u16,
    Ny: u16,
    Nz: u16,
    format: Binary_Format,

    is_sparse:  b16,
    block_size: u16,
    num_tiles:  u32,

    normalization:    f32,
    offsets:       [3]i32,
}


ctx: struct {
    vao: u32,

    raster_programs:  map[string]Raster_Program,
    compute_programs: map[string]Compute_Program,

    bufs: [2]u32,
    reduced_smoke_texture1: u32,
    lighting_texture1: u32,
    attenuation_texture1: u32,
    
    mask_texture: u32,
    mask_texture4: u32,
    
    envmap_buffer: u32,
    envmap_texture: u32,
    stats_buffer: u32,

    voxel_size: f32,
    density_scale_base: f32,

    PVM: matrix[4, 4]f32,
    eye: [3]f32,

    theta: f32,
    phi: f32,
    distance: f32,
    smoke_weight: f32,

    sizes: [Resolution][3]i32,
    num_voxels: [Resolution]i32,

    velocity_x_textures:  [Resolution]u32,
    velocity_y_textures:  [Resolution]u32,
    velocity_z_textures:  [Resolution]u32,
    smoke_textures:       [Resolution]u32,
    aux_textures:         [Resolution][4]u32,


    font: Font,

    main_window: Window,


    timestep: int,
    frame: int,

    pre_smooths0: int,
    pre_smooths1: int,
    solves2: int,
    post_smooths1: int,
    post_smooths0: int,
    post_solves0: int,
    post_corrections0: int,

    pause: bool,
    should_reset: bool,
    should_step: bool,

    header: Binary_Header,

    use_optimizations: bool,
} = {
    pre_smooths0 = 2,
    pre_smooths1 = 3,
    solves2 = 16,
    post_smooths1 = 2,
    post_smooths0 = 1,
    post_solves0 = 1,
    post_corrections0 = 1,

    pause = true,
    should_reset = true,
}

Window :: struct {
    handle: glfw.WindowHandle,

    width, height: i32,

    fbo: u32,
    render_texture: u32,

    input: Input,

    closed: bool,
}

update_camera :: proc() {
    
    cp := math.cos(math.to_radians(ctx.phi))
    sp := math.sin(math.to_radians(ctx.phi))
    ct := math.cos(math.to_radians(ctx.theta))
    st := math.sin(math.to_radians(ctx.theta))
    eye := ctx.distance*[3]f32{cp*st, sp*st, ct}

    at := [3]f32{0, 0, 0}

    M := linalg.matrix4_translate_f32(-linalg.to_f32(ctx.sizes[.X1])/2.0)
    V := linalg.matrix4_look_at_f32(eye, at, {0, 0, 1})
    P := linalg.matrix4_perspective_f32(math.to_radians(f32(60.0)), f32(ctx.main_window.width) / f32(ctx.main_window.height), 0.1, 10000.0)

    ctx.PVM = P*V*M
    ctx.eye = eye
}

draw :: proc() {
    gl.BindFramebuffer(gl.FRAMEBUFFER, ctx.main_window.fbo)

    do_render() 

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    gl.Disable(gl.BLEND)
    gl.UseProgram(ctx.raster_programs["blit"].handle);
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, ctx.main_window.render_texture)
    gl.DrawArrays(gl.TRIANGLES, 0, 3);

    {
        // Stats and info
        @static old_time: f64;
        time := glfw.GetTime();
        delta_time := time - old_time;
        old_time = time; 

        set_font_state(ctx.vao);

        time_simulation, bw_simulation := process_finished_query("simulation", 100)
        time_lighting1, _ := process_finished_query("lighting1", 100)
        time_lighting2, _ := process_finished_query("lighting2", 100)
        time_render, _ := process_finished_query("render", 100)

        sim_speed := f64(ctx.num_voxels[.X1]) / (1e-3*time_simulation) * 1.0e-9 

        font_color := u16(0)

        pos := f32(10)
        dpos := f32(24)
        draw_string(&ctx.font, 16, {10, pos},  font_color, "GL_RENDERER: %v", gl.GetString(gl.RENDERER)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "GL_VERSION: %v", gl.GetString(gl.VERSION)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "Resolution %v", ctx.sizes[.X1]); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "Density Scale %.3f", ctx.density_scale_base); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "Frame Time %.3f ms", 1000*delta_time); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "Timestep %d", ctx.timestep); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "Simulation                      %.3f ms = %.3f GB/s = %.3f Bvox/s", time_simulation, bw_simulation, sim_speed); pos += dpos
    when !STRIP_MOST_QUERIES {
        draw_string(&ctx.font, 16, {10, pos},  font_color, " Advection                         %.3f ms = %.3f GB/s",                                                             process_finished_query("advection", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, " Reduce data                       %.3f ms = %.3f GB/s",                                                             process_finished_query("reduce data", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, " Compute mask                      %.3f ms = %.3f GB/s",                                                             process_finished_query("compute mask", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, " Projection                        %.3f ms = %.3f GB/s",                                                             process_finished_query("projection", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "  Divergence %s                    %.3f ms = %.3f GB/s", ctx.use_optimizations ? "**" : "  ",                        process_finished_query("divergence", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "  Poisson                          %.3f ms = %.3f GB/s",                                                             process_finished_query("poisson", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "   Zero             level 0        %.3f ms = %.3f GB/s",                                                             process_finished_query("zero 1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "   V-Cycle          level 0        %.3f ms = %.3f GB/s",                                                             process_finished_query("vcycle X1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "    Jacobi          level 0   % 4dx%.3f ms = %.3f GB/s", ctx.pre_smooths0,                                           process_finished_query("jacobi 1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "    Residual        level 0        %.3f ms = %.3f GB/s",                                                             process_finished_query("residual 1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "    Restrict        level 0->1     %.3f ms = %.3f GB/s",                                                             process_finished_query("restrict 1-2", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "    Zero            level 1        %.3f ms = %.3f GB/s",                                                             process_finished_query("zero 2", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "    V-Cycle         level 1        %.3f ms = %.3f GB/s",                                                             process_finished_query("vcycle X2", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "     Jacobi         level 1   % 4dx%.3f ms = %.3f GB/s", ctx.pre_smooths1,                                           process_finished_query("jacobi 2", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "     Residual       level 1        %.3f ms = %.3f GB/s",                                                             process_finished_query("residual 2", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "     Restrict       level 1->2     %.3f ms = %.3f GB/s",                                                             process_finished_query("restrict 2-4", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "     Zero           level 2        %.3f ms = %.3f GB/s",                                                             process_finished_query("zero 4", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "     V-Cycle        level 2        %.3f ms = %.3f GB/s",                                                             process_finished_query("vcycle X4", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "      Sor %s        level 2   % 4dx%.3f ms = %.3f GB/s", ctx.use_optimizations ? "**" : "  ", 2*ctx.solves2,         process_finished_query("sor 4", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "     Prolongate     level 2->1     %.3f ms = %.3f GB/s",                                                             process_finished_query("prolongate 4-2", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "     Jacobi         level 1   % 4dx%.3f ms = %.3f GB/s", ctx.post_smooths1,                                          process_finished_query("jacobi 1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "    Prolongate      level 1->0     %.3f ms = %.3f GB/s",                                                             process_finished_query("prolongate 2-1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "    Jacobi          level 0   % 4dx%.3f ms = %.3f GB/s", ctx.post_smooths0,                                          process_finished_query("jacobi 1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "   Sor              level 0   % 4dx%.3f ms = %.3f GB/s", 2*ctx.post_solves0,                                         process_finished_query("sor 1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "   Jacobi Vertex %s level 0   % 4dx%.3f ms = %.3f GB/s", ctx.use_optimizations ? "**" : "  ", ctx.post_corrections0, process_finished_query("jacobi vertex 1", 100)); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "  Gradient                      %.3f ms = %.3f GB/s",                                                                process_finished_query("gradient", 100)); pos += dpos
    }
        draw_string(&ctx.font, 16, {10, pos},  font_color, "Lighting                        %.3f ms", time_lighting1+time_lighting2); pos += dpos
        draw_string(&ctx.font, 16, {10, pos},  font_color, "Render                          %.3f ms", time_render); pos += 2*dpos

        draw_string(&ctx.font, 16, {10, pos},  font_color, "Active Queries: %d, Pool Size: %d", len(active_queries), len(query_pool)); pos += dpos
    }
}

window_size_callback :: proc"c"(window: glfw.WindowHandle, width, height: c.int) {
    context = runtime.default_context();
    
    if window == ctx.main_window.handle {
        ctx.main_window.width, ctx.main_window.height = width, height
        
        glfw.MakeContextCurrent(ctx.main_window.handle);
        gl.Viewport(0, 0, width, height)
       
        recreate_fbo()
        update_camera()
        draw()
        glfw.SwapBuffers(window);
        
        fmt.println("New size main window:", width, height)
    } 
}

error_callback :: proc"c"(error: i32, desc: cstring) {
    context = runtime.default_context();
    fmt.printf("Error code %d: %s\n", error, desc);
}

main :: proc() {
    ctx.main_window.width, ctx.main_window.height = i32(1920), i32(1080)

    glfw.SetErrorCallback(error_callback);

    if !glfw.Init() do return
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    ctx.main_window.handle = glfw.CreateWindow(ctx.main_window.width, ctx.main_window.height, "Masterclass Main", nil, nil);
    if ctx.main_window.handle == nil do return;
    defer glfw.DestroyWindow(ctx.main_window.handle)

    set_input_callbacks(ctx.main_window.handle);
    glfw.SetWindowSizeCallback(ctx.main_window.handle, window_size_callback);

    glfw.MakeContextCurrent(ctx.main_window.handle);
    glfw.SwapInterval(0);

    // OpenGL    
    gl.load_up_to(4, 6, glfw.gl_set_proc_address);

    fmt.println(gl.GetString(gl.VENDOR))
    fmt.println(gl.GetString(gl.RENDERER))
    fmt.println(gl.GetString(gl.VERSION))

    ctx.font = init_font("gl_font/consola.ttf")
    
    recreate_fbo()

    gl.Enable(gl.FRAMEBUFFER_SRGB)

    fmt.printf("Loading file ... ");
    vdb_file := "vdbs/quarter.bin"
         if vdb_file == "vdbs/quarter.bin"   do ctx.voxel_size = 0.25
    else if vdb_file == "vdbs/eighth.bin"    do ctx.voxel_size = 0.5
    else if vdb_file == "vdbs/sixteenth.bin" do ctx.voxel_size = 1.0
    else                                     do ctx.voxel_size = 1.0
    ctx.density_scale_base = 0.5
    data, ok := os.read_entire_file(vdb_file)

    ctx.header      = mem.slice_data_cast([]Binary_Header, data[                                                       :size_of(Binary_Header)                                 ])[0]
    coordinates    := mem.slice_data_cast([][3]i32,        data[size_of(Binary_Header)                                 :size_of(Binary_Header)+ctx.header.num_tiles*size_of([3]i32)])
    leaf_node_data := mem.slice_data_cast([]f16,           data[size_of(Binary_Header)+ctx.header.num_tiles*size_of([3]i32):                                                       ])
    fmt.println("done")

    {
        data, tex := load_and_process_hdri()
        for k in 0..<3 {
            for j in 0..<3 {
                for i in 0..<3 {
                    fmt.printf("% 6.2f ", data[2-k][2-j][i])
                }
                fmt.println()
            }
            fmt.println()
        }
        if tex != 0 do ctx.envmap_texture = tex

        gl.CreateBuffers(1, &ctx.envmap_buffer)
        gl.NamedBufferData(ctx.envmap_buffer, size_of(data), &data[0], gl.STATIC_READ)
    }

    gl.CreateBuffers(2, &ctx.bufs[0])
    gl.NamedBufferData(ctx.bufs[0], size_of([3]i32)*len(coordinates), &coordinates[0], gl.STATIC_READ)
    gl.NamedBufferData(ctx.bufs[1], size_of(f16)*len(leaf_node_data[:]), &leaf_node_data[0], gl.STATIC_READ)

    

    gl.CreateBuffers(1, &ctx.stats_buffer)
    gl.NamedBufferData(ctx.stats_buffer, 2*32*32*size_of(i32), nil, gl.STATIC_READ)
    
    ctx.sizes[.X1] = ro2([3]i32{i32(ctx.header.Nx), i32(ctx.header.Nz), i32(ctx.header.Ny)}, 32)
    ctx.sizes[.X2] = ctx.sizes[.X1] / 2
    ctx.sizes[.X4] = ctx.sizes[.X1] / 4

    ctx.num_voxels[.X1] = ctx.sizes[.X1].x * ctx.sizes[.X1].y * ctx.sizes[.X1].z
    ctx.num_voxels[.X2] = ctx.sizes[.X2].x * ctx.sizes[.X2].y * ctx.sizes[.X2].z
    ctx.num_voxels[.X4] = ctx.sizes[.X4].x * ctx.sizes[.X4].y * ctx.sizes[.X4].z

    fmt.printf("Creating 3D texture ... ");
    ctx.reduced_smoke_texture1 = make_texture3D(expand_values(ctx.sizes[.X2]),             gl.R16F,    gl.RED,         gl.FLOAT, nil, gl.LINEAR)
    ctx.lighting_texture1      = make_texture3D(expand_values(ctx.sizes[.X2]),             gl.RGBA16F, gl.RED,         gl.FLOAT, nil, gl.LINEAR)
    ctx.attenuation_texture1   = make_texture3D(expand_values(ctx.sizes[.X2] * {3, 3, 3}), gl.R16F,    gl.RED,         gl.FLOAT, nil, gl.LINEAR)
    ctx.mask_texture           = make_texture3D(expand_values(ctx.sizes[.X1]/8),           gl.R8,      gl.RED,         gl.FLOAT, nil, gl.LINEAR)
    ctx.mask_texture4           = make_texture3D(expand_values(ctx.sizes[.X1]/4),           gl.R8,      gl.RED,         gl.FLOAT, nil, gl.LINEAR)
    fmt.println("done")

    ctx.velocity_x_textures[.X1]  = make_texture3D(expand_values(ctx.sizes[.X1]), gl.R16F, gl.RED, gl.FLOAT, nil, gl.LINEAR)
    ctx.velocity_y_textures[.X1]  = make_texture3D(expand_values(ctx.sizes[.X1]), gl.R16F, gl.RED, gl.FLOAT, nil, gl.LINEAR)
    ctx.velocity_z_textures[.X1]  = make_texture3D(expand_values(ctx.sizes[.X1]), gl.R16F, gl.RED, gl.FLOAT, nil, gl.LINEAR)
    ctx.smoke_textures[.X1]       = make_texture3D(expand_values(ctx.sizes[.X1]), gl.R16F, gl.RED, gl.FLOAT, nil, gl.LINEAR)
    
    for i in 0..<4 {
        ctx.aux_textures[.X1][i] = make_texture3D(expand_values(ctx.sizes[.X1]), gl.R16F, gl.RED, gl.FLOAT, nil, gl.LINEAR)
        ctx.aux_textures[.X2][i] = make_texture3D(expand_values(ctx.sizes[.X2]), gl.R16F, gl.RED, gl.FLOAT, nil, gl.LINEAR)
        ctx.aux_textures[.X4][i] = make_texture3D(expand_values(ctx.sizes[.X4]), gl.R16F, gl.RED, gl.FLOAT, nil, gl.LINEAR)
    }

    sum := uint(0)
    sum += 1*2*uint(ctx.num_voxels[.X1])*9/8
    sum += 3*2*uint(ctx.num_voxels[.X1])*1/1
    sum += 4*2*uint(ctx.num_voxels[.X1])*73/64
    sum += 8*uint(ctx.num_voxels[.X2]) + 2*uint(ctx.num_voxels[.X2])*27
    sum += 1*uint(ctx.num_voxels[.X1])/8
    sum += uint(ctx.header.num_tiles*(2*8*8*8 + 12))
    sum += 16*uint(ctx.main_window.width * ctx.main_window.height)
    sum += 16*uint(ctx.main_window.width * ctx.main_window.height)
    fmt.println("VRAM consumption:")
    fmt.println("   Smoke:      ", fmt_large_bytes(1*2*uint(ctx.num_voxels[.X1])*9/8))
    fmt.println("   Velocity:   ", fmt_large_bytes(3*2*uint(ctx.num_voxels[.X1])*1/1))
    fmt.println("   Auxiliary:  ", fmt_large_bytes(4*2*uint(ctx.num_voxels[.X1])*73/64))
    fmt.println("   Lighting:   ", fmt_large_bytes(8*uint(ctx.num_voxels[.X2]) + 2*uint(ctx.num_voxels[.X2])*27))
    fmt.println("   Mask:       ", fmt_large_bytes(1*uint(ctx.num_voxels[.X1])/8))
    fmt.println("   VDB Data:   ", fmt_large_bytes(uint(ctx.header.num_tiles*(2*8*8*8 + 12))))
    fmt.println("   Framebuffer:", fmt_large_bytes(16*uint(ctx.main_window.width * ctx.main_window.height)))
    fmt.println("   Total:      ", fmt_large_bytes(sum))

    // Load shaders

    ctx.raster_programs, ctx.compute_programs = load_all_shaders()

    // Dummy VAO
    gl.GenVertexArrays(1, &ctx.vao);
    gl.BindVertexArray(ctx.vao);

    fmt.printf("size0: % 4d % 13s\n", ctx.sizes[.X1], fmt_large_count(ctx.num_voxels[.X1]))
    fmt.printf("size1: % 4d % 13s\n", ctx.sizes[.X2], fmt_large_count(ctx.num_voxels[.X2]))
    fmt.printf("size2: % 4d % 13s\n", ctx.sizes[.X4], fmt_large_count(ctx.num_voxels[.X4]))

    //1987*1351*2449*2 + 3103288*12 + 1588883456*2 = 16363378794
    //16363378794 / 1024**3 = 15.239584067836404

    init_query_pool()

    ctx.theta = f32(90.0)
    ctx.phi = f32(-30.0)
    ctx.distance = f32(115.0) / f32(ctx.voxel_size)

    // Main Loop

    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for !glfw.WindowShouldClose(ctx.main_window.handle) {
        glfw.PollEvents();
        
        process_active_queries(ctx.timestep)

        for _, &value in ctx.raster_programs do refresh_raster_program(&value)
        for _, &value in ctx.compute_programs do refresh_compute_program(&value)

        {
            // Main window input

            // Input
            input := get_input(ctx.main_window.handle)

            if .RELEASE in input.keys[.ESCAPE] {
                glfw.SetWindowShouldClose(ctx.main_window.handle, true);
            }

            mul := f32(1.0)
            if .DOWN in input.keys[.LEFT_CONTROL] || .DOWN in input.keys[.RIGHT_CONTROL] {
                mul *= 2.0
            }
            if .DOWN in input.keys[.LEFT_SHIFT] || .DOWN in input.keys[.RIGHT_SHIFT] {
                mul *= 2.0
            }
            if .DOWN in input.keys[.LEFT_ALT] || .DOWN in input.keys[.RIGHT_ALT] {
                mul *= 2.0
            }

            if .DOWN in input.keys[.UP] {
                ctx.density_scale_base = min(16.0, ctx.density_scale_base* (1 + mul/100.0))
            }
            if .DOWN in input.keys[.DOWN] {
                ctx.density_scale_base = ctx.density_scale_base / (1 + mul/100.0)
            }

            if .DOWN in input.buttons[0] {
                ctx.phi = math.wrap(ctx.phi - 0.25*input.mouse_position_delta.x, 360.0)
                ctx.theta = clamp(ctx.theta - 0.25*input.mouse_position_delta.y, 0.01, 180.0-0.01)
            }

            if .PRESS in input.keys[.R] {
                ctx.should_reset = true
            }

            if .PRESS in input.keys[.Z] {
                ctx.should_step = true
            }

            if .PRESS in input.keys[.SPACE] {
                ctx.pause = !ctx.pause
            }

            if .PRESS in input.keys[.LEFT] {
                ctx.post_corrections0 = max(0, ctx.post_corrections0-1)
            }

            if .PRESS in input.keys[.RIGHT] {
                ctx.post_corrections0 = ctx.post_corrections0+1
            }

            if .PRESS in input.keys[.F7] {
                print_finished_queries()
            }

            if .PRESS in input.keys[.O] {
                ctx.use_optimizations = !ctx.use_optimizations
            }

            if .PRESS in input.keys[.J] {
                ctx.smoke_weight = ctx.smoke_weight - mul * 1.0
                fmt.println("smoke weight: ", ctx.smoke_weight);
            }

            if .PRESS in input.keys[.K] {
                ctx.smoke_weight = ctx.smoke_weight + mul * 1.0
                fmt.println("smoke weight: ", ctx.smoke_weight);
            }

            ctx.distance *= math.pow(f32(1.04), -input.mousewheel_delta)
            update_camera()
        }

        if ctx.should_reset {
            do_sim_reset()
            ctx.should_reset = false
        }
        do_sim_step()

        do_lighting()

        draw()
        ctx.frame += 1

        glfw.SwapBuffers(ctx.main_window.handle);
        clear_input();
    }
}

