package benchmarks

import "core:fmt";
import "core:os";
import "core:math/linalg";
import "core:strings";
import "base:runtime";

import glfw "vendor:glfw";
import gl "vendor:OpenGL";

@(export, link_name="NvOptimusEnablement")
NvOptimusEnablement: u32 = 0x00000001;

@(export, link_name="AmdPowerXpressRequestHighPerformance")
AmdPowerXpressRequestHighPerformance: i32 = 1;

error_callback :: proc"c"(error: i32, desc: cstring) {
    context = runtime.default_context();
    fmt.printf("Error code %d: %s\n", error, desc);
}

Program :: struct {
    local_size: [3]u32,
    handle: u32,
    filename: string,
}

main :: proc() {
    glfw.SetErrorCallback(error_callback);

    if !glfw.Init() do return
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    window := glfw.CreateWindow(1280, 720, "Masterclass", nil, nil);
    if window == nil do return;
    defer glfw.DestroyWindow(window)

    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    // OpenGL    
    gl.load_up_to(4, 6, glfw.gl_set_proc_address);

    fmt.println(gl.GetString(gl.VENDOR))
    fmt.println(gl.GetString(gl.RENDERER))
    fmt.println(gl.GetString(gl.VERSION))

    replace_placeholder :: proc(str, placeholder, replacement: string, allocator := context.allocator) -> string {
        found := strings.index(str, placeholder)
        if found == -1 do return ""

        return strings.concatenate({
            str[:found], 
            replacement, 
            str[found+len(placeholder):]
        }, allocator)
    }

    readback_single_texel_program := load_compute_program("shaders/readback_single_texel.glsl")
    
    init_programs: [dynamic]Program
    {
        filename := "shaders/init_solver.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            outer1: for s := 32; s <= 1024; s *= 2 {
                for k := 1; k <= 16; k *= 2 {
                    for j := 1; j <= 16; j *= 2 {
                        for i := 1; i <= 16; i *= 2 {
                            if i*j*k != s do continue

                            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
                            replacement := fmt.tprintf(format, i, j, k)
                            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

                            program := load_compute_source(replaced_source)
                            if program == 0 do break outer1
                            append(&init_programs, Program{{u32(i), u32(j), u32(k)}, program, strings.clone(filename)})
                        }
                    }
                }
            }
        }
    }

    jacobi_programs: [dynamic]Program
    {
        filename := "shaders/iterate_jacobi1.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            outer2: for s := 32; s <= 1024; s *= 2 {
                for k := 1; k <= 16; k *= 2 {
                    for j := 1; j <= 16; j *= 2 {
                        for i := 1; i <= 16; i *= 2 {
                            if i*j*k != s do continue

                            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
                            replacement := fmt.tprintf(format, i, j, k)
                            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

                            program := load_compute_source(replaced_source)
                            if program == 0 do break outer2
                            append(&jacobi_programs, Program{{u32(i), u32(j), u32(k)}, program, strings.clone(filename)})
                        }
                    }
                }
            }
        }
    }

    jacobi_programs1_multi: [dynamic]Program
    {
        filename := "shaders/iterate_jacobi1_multi.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            for mode := 0; mode < 8; mode += 1 {
                replacement := fmt.tprintf("%d", mode)
                replaced_source := replace_placeholder(string(source), "<mode>", replacement, context.temp_allocator)

                //fmt.println(replaced_source)
                program := load_compute_source(replaced_source)
                if program == 0 do break
                append(&jacobi_programs1_multi, Program{{u32(8+(mode&1)<<3), u32(8+(mode&2)<<2), u32(8+(mode&4)<<1)}, program, strings.clone(filename)})
            }
        }
    }

    //for program in jacobi_programs1_multi do fmt.println(program)

    jacobi_programs2: [dynamic]Program
    {
        filename := "shaders/iterate_jacobi2.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            outer3: for s := 32; s <= 1024; s *= 2 {
                for k := 1; k <= 16; k *= 2 {
                    for j := 1; j <= 16; j *= 2 {
                        for i := 1; i <= 16; i *= 2 {
                            if i*j*k != s do continue

                            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
                            replacement := fmt.tprintf(format, i, j, k)
                            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

                            program := load_compute_source(replaced_source)
                            if program == 0 do break outer3
                            append(&jacobi_programs2, Program{{u32(i), u32(j), u32(k)}, program, strings.clone(filename)})
                        }
                    }
                }
            }
        }
    }

    jacobi_programs2_multi: [dynamic]Program
    {
        filename := "shaders/iterate_jacobi2_multi.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            for mode := 0; mode < 8; mode += 1 {
                replacement := fmt.tprintf("%d", mode)
                replaced_source := replace_placeholder(string(source), "<mode>", replacement, context.temp_allocator)

                //fmt.println(replaced_source)
                program := load_compute_source(replaced_source)
                if program == 0 do break
                append(&jacobi_programs2_multi, Program{{u32(8+(mode&1)<<3), u32(8+(mode&2)<<2), u32(8+(mode&4)<<1)}, program, strings.clone(filename)})
            }
        }
    }


    box_blur_programs: [dynamic]Program
    {
        filename := "shaders/box_blur1.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 8, 8, 8
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(i), u32(j), u32(k)}, program, strings.clone(filename)})
            }
        }
    }
    {
        filename := "shaders/box_blur2.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 8, 8, 8
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(i), u32(j), u32(k)}, program, strings.clone(filename)})
            }
        }
    }
    {
        filename := "shaders/box_blur3.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 8, 8, 8
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(i), u32(j), u32(k)}, program, strings.clone(filename)})
            }
        }
    }
    {
        filename := "shaders/box_blur4.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 8, 8, 8
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }
    {
        filename := "shaders/box_blur5.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 8, 8, 8
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }
    {
        filename := "shaders/box_blur6.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 8, 8, 8
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    {
        filename := "shaders/box_blur7.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 4, 4, 4
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    {
        filename := "shaders/box_blur8.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 4, 4, 4
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    {
        filename := "shaders/box_blur8a.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 4, 4, 4
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    {
        filename := "shaders/box_blur8b.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 4, 4, 4
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    {
        filename := "shaders/box_blur8c.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 4, 4, 4
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    {
        filename := "shaders/box_blur9.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 4, 4, 4
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    {
        filename := "shaders/box_blur10.glsl"
        source, ok := os.read_entire_file(filename, context.temp_allocator)
        if ok {
            i, j, k := 4, 4, 4
            format := "layout(local_size_x = %d, local_size_y = %d, local_size_z = %d) in;"
            replacement := fmt.tprintf(format, i, j, k)
            replaced_source := replace_placeholder(string(source), "<local_size>", replacement, context.temp_allocator)

            program := load_compute_source(replaced_source)
            if program != 0 {
                append(&box_blur_programs, Program{{u32(2*i), u32(2*j), u32(2*k)}, program, strings.clone(filename)})
            }
        }
    }

    init_2D_program := load_compute_program("shaders/init_2D.glsl")
    reduce1_program := load_compute_program("shaders/reduce1.glsl")
    if (init_2D_program == 0 || reduce1_program == 0) do return;

    Handle :: u32

    Texture_Internal_Format :: enum u32 {
        R16F = gl.R16F,
        R32F = gl.R32F,
        RGBA32F = gl.RGBA32F,
    } 

    Texture :: struct {
        size: [3]u32,
        handle: Handle,
        internal_format: Texture_Internal_Format,
    }

    Texture2D :: struct {
        size: [2]u32,
        handle: Handle,
        internal_format: Texture_Internal_Format,
    }

    make_texture :: proc(size: [3]u32, internal_format: Texture_Internal_Format) -> Texture {
        handle: u32;
        gl.CreateTextures(gl.TEXTURE_3D, 1, &handle);
        gl.TextureParameteri(handle, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.TextureParameteri(handle, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TextureStorage3D(handle, 1, u32(internal_format), expand_values(linalg.to_i32(size)));
        gl.ClearTexImage(handle, 0, gl.RED, gl.FLOAT, nil)
        return {size = size, handle = handle, internal_format = internal_format};
    }

    make_texture2D :: proc(size: [2]u32, levels: i32, internal_format: Texture_Internal_Format) -> Texture2D {
        handle: u32;
        gl.CreateTextures(gl.TEXTURE_2D, 1, &handle);
        gl.TextureParameteri(handle, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.TextureParameteri(handle, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TextureStorage2D(handle, levels, u32(internal_format), expand_values(linalg.to_i32(size)));
        gl.ClearTexImage(handle, 0, gl.RED, gl.FLOAT, nil)
        return {size = size, handle = handle, internal_format = internal_format};
    }

    init_queries()
    
    verify_buffer: u32
    gl.CreateBuffers(1, &verify_buffer)
    gl.NamedBufferData(verify_buffer, size_of(f32)*1024, nil, gl.STATIC_READ)

    query: u32
    gl.GenQueries(1, &query);

    @(deferred_in=end_query_block)
    query_block :: proc(query: u32, results: ^[dynamic]u64) {
        #force_inline begin_query_block(query, results);
    }

    begin_query_block :: proc(query: u32, results: ^[dynamic]u64) {
        gl.BeginQuery(gl.TIME_ELAPSED, query);
    }

    end_query_block :: proc(query: u32, results: ^[dynamic]u64) {
        gl.EndQuery(gl.TIME_ELAPSED);
        result: u64
        gl.GetQueryObjectui64v(query, gl.QUERY_RESULT, &result);
        append(results, result)
    }

    readback_single_texel :: proc(texture: Texture, buffer: u32, program: u32) -> f32 {
        gl.UseProgram(program)
        gl.BindTextureUnit(0, texture.handle)
        gl.Uniform3i(0, expand_values(linalg.to_i32(texture.size/2)))
        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, buffer);
        gl.DispatchCompute(1, 1, 1)

        data: f32
        gl.GetNamedBufferSubData(buffer, 0, 4, &data)

        return data
    }

    reduce_queries :: proc(results: []u64, mem_size: int) -> (f64, f64) {
        avg_time := f64(0.0);
        for time in results do avg_time += f64(time);
        avg_time /= f64(len(results));
        avg_time *= 1.0e-9;

        time := avg_time * 1.0e3
        bandwidth := f64(mem_size) / avg_time * 1e-9;

        return time, bandwidth
    }

    if false {
        glfw.SwapBuffers(window);

        mip_chain_texture := make_texture2D({4096, 4096}, 13, .RGBA32F)
        flush_texture     := make_texture2D({2*4096, 2*4096}, 13, .R32F)

        {
            GL_LABEL_BLOCK("Execute")

            {
                GL_LABEL_BLOCK("Initialize")

                gl.UseProgram(init_2D_program)
                gl.BindImageTexture(0, mip_chain_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, u32(mip_chain_texture.internal_format))
                gl.DispatchCompute(expand_values(mip_chain_texture.size / {16, 16}), 1)
            }
            {
                GL_LABEL_BLOCK("Init Flush")

                gl.UseProgram(init_2D_program)
                gl.BindImageTexture(0, flush_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, u32(flush_texture.internal_format))
                gl.DispatchCompute(expand_values(flush_texture.size / {16, 16}), 1)
            }
            {
                GL_LABEL_BLOCK("Reduce")
                gl.UseProgram(reduce1_program)

                for i in 0..<12 {
                    GL_LABEL_BLOCK(fmt.tprintf("Reduce %d -> %d", i, i+1))

                    size := mip_chain_texture.size / (u32(2) << u32(i))
                    fmt.println(i, size)
                    gl.Uniform1i(0, i32(i))
                    gl.BindTextureUnit(0, mip_chain_texture.handle)
                    gl.BindImageTexture(0, mip_chain_texture.handle, i32(i+0), gl.TRUE, 0, gl.READ_ONLY,  u32(mip_chain_texture.internal_format))
                    gl.BindImageTexture(1, mip_chain_texture.handle, i32(i+1), gl.TRUE, 0, gl.WRITE_ONLY, u32(mip_chain_texture.internal_format))
                    gl.MemoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT)
                    gl.DispatchCompute(expand_values((size + 15) / {16, 16}), 1)
                }
            }

            {
                GL_LABEL_BLOCK("Reduce")
                gl.UseProgram(reduce1_program)

                for i in 0..<12 {
                    GL_LABEL_BLOCK(fmt.tprintf("Reduce %d -> %d", i, i+1))

                    size := mip_chain_texture.size / (u32(2) << u32(i))
                    fmt.println(i, size)
                    gl.Uniform1i(0, i32(i))
                    gl.BindTextureUnit(0, mip_chain_texture.handle)
                    gl.BindImageTexture(0, mip_chain_texture.handle, i32(i+0), gl.TRUE, 0, gl.READ_ONLY,  u32(mip_chain_texture.internal_format))
                    gl.BindImageTexture(1, mip_chain_texture.handle, i32(i+1), gl.TRUE, 0, gl.WRITE_ONLY, u32(mip_chain_texture.internal_format))
                    gl.MemoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT)
                    gl.DispatchCompute(expand_values((size + 15) / {16, 16}), 1)
                }
            }
        }

        glfw.SwapBuffers(window);
        glfw.SwapBuffers(window);
        glfw.SwapBuffers(window);

    }
    {

    }

    for Nz := u32(512); Nz >= 32; Nz /= 2 do for Ny := u32(512); Ny >= 32; Ny /= 2 do for Nx := u32(512); Nx >= 32; Nx /= 2 {
        Nz = Nx
        Ny = Nx
        defer {
            //Nx, Ny, Nz = 1, 1, 1
        }

        //if true do break
        N := min(Nx, Ny, Nz)
        dx := 1.0 / f32(N)

        fmt.println()
        fmt.println()
        fmt.println()
        fmt.println("N", Nx, Ny, Nz)
        lhs_texture_r16f := make_texture({Nx, Ny, Nz}, .R16F)
        lhs_texture2_r16f := make_texture({Nx, Ny, Nz}, .R16F)
        rhs_texture_r16f := make_texture({Nx, Ny, Nz}, .R16F)

        lhs_texture_r32f := make_texture({Nx, Ny, Nz}, .R32F)
        lhs_texture2_r32f := make_texture({Nx, Ny, Nz}, .R32F)
        rhs_texture_r32f := make_texture({Nx, Ny, Nz}, .R32F)
        defer {
            gl.DeleteTextures(1, &lhs_texture_r16f.handle)
            gl.DeleteTextures(1, &lhs_texture2_r16f.handle)
            gl.DeleteTextures(1, &rhs_texture_r16f.handle)
            gl.DeleteTextures(1, &lhs_texture_r32f.handle)
            gl.DeleteTextures(1, &lhs_texture2_r32f.handle)
            gl.DeleteTextures(1, &rhs_texture_r32f.handle)
        }


        for internal_format in ([2]u32{gl.R16F, gl.R32F}) {
            format_size := 2 if internal_format == gl.R16F else 4
            fmt.println(internal_format == gl.R16F ? "R16F" : "R32F")

            lhs_texture  := internal_format == gl.R16F ? lhs_texture_r16f  : lhs_texture_r32f
            lhs_texture2 := internal_format == gl.R16F ? lhs_texture2_r16f : lhs_texture2_r32f
            rhs_texture  := internal_format == gl.R16F ? rhs_texture_r16f  : rhs_texture_r32f
            if false {
                fmt.println("Init")
                label_programs1: for program in init_programs {
                    if !(program.local_size == {8, 8, 8} || program.local_size == {4, 4, 4}) do continue
                    fmt.printf("% 2v = % 4d \t", program.local_size, program.local_size.x*program.local_size.y*program.local_size.z)
                    
                    elapsed := make([dynamic]u64, context.temp_allocator)
                    for i in 0..<100 {
                        glfw.PollEvents()
                        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do break label_programs1
                        {
                            query_block(query, &elapsed)
                            gl.UseProgram(program.handle)
                            gl.Uniform1i(2, 0)
                            gl.Uniform1f(0, dx)
                            gl.Uniform3f(1, expand_values(1.0 / linalg.to_f32(lhs_texture.size + 1)))
                            gl.BindImageTexture(0, lhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                            gl.BindImageTexture(1, rhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                            gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
                            gl.DispatchCompute(expand_values((lhs_texture.size + program.local_size-1) / program.local_size))
                        }
                    }

                    {
                        data := readback_single_texel(lhs_texture, verify_buffer, readback_single_texel_program)

                        time, bw := reduce_queries(elapsed[3:], int(Nx)*int(Ny)*int(Nz)*format_size*2)
                        
                        fmt.printf("%f \t%.1f \t%.9f\n", time, bw, data)
                    }
                }

                //gl.Flush();
            }
            if false {
                fmt.println("Jacobi")
                label_programs2: for program in jacobi_programs {
                    if !(program.local_size == {8, 8, 8} || program.local_size == {4, 4, 4}) do continue
                    fmt.printf("% 2v = % 4d \t", program.local_size, program.local_size.x*program.local_size.y*program.local_size.z)
                    
                    {
                        init_program := init_programs[len(init_programs)-1]
                        gl.UseProgram(init_program.handle)
                        gl.Uniform1i(2, 0)
                        gl.Uniform1f(0, dx)
                        gl.Uniform3f(1, expand_values(1.0 / linalg.to_f32(lhs_texture.size + 1)))
                        gl.BindImageTexture(0, lhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.BindImageTexture(1, rhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.DispatchCompute(expand_values((lhs_texture.size + init_program.local_size-1) / init_program.local_size))
                    }

                    elapsed := make([dynamic]u64, context.temp_allocator)
                    for i in 0..<100 {
                        glfw.PollEvents()
                        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do break label_programs2
                        {
                            query_block(query, &elapsed)
                            gl.UseProgram(program.handle)
                            gl.Uniform3ui(0, expand_values(lhs_texture.size))
                            gl.BindTextureUnit(0, lhs_texture.handle)
                            gl.BindTextureUnit(1, rhs_texture.handle)
                            gl.BindImageTexture(0, lhs_texture2.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                            gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
                            gl.DispatchCompute(expand_values((lhs_texture.size + program.local_size-1) / program.local_size))
                        }
                        lhs_texture, lhs_texture2 = lhs_texture2, lhs_texture
                    }

                    {
                        data := readback_single_texel(lhs_texture, verify_buffer, readback_single_texel_program)

                        time, bw := reduce_queries(elapsed[3:], int(Nx)*int(Ny)*int(Nz)*format_size*3)
                        
                        fmt.printf("%f \t%.1f \t%.9f\n", time, bw, data)
                    }
                }

                //gl.Flush();
            }

            if false {
                fmt.println("Jacobi 1 Multi")
                label_programs4: for program in jacobi_programs1_multi {
                    fmt.printf("% 2v = % 4d \t", program.local_size, program.local_size.x*program.local_size.y*program.local_size.z)
                    
                    {
                        init_program := init_programs[len(init_programs)-1]
                        gl.UseProgram(init_program.handle)
                        gl.Uniform1i(2, 0)
                        gl.Uniform1f(0, dx)
                        gl.Uniform3f(1, expand_values(1.0 / linalg.to_f32(lhs_texture.size + 1)))
                        gl.BindImageTexture(0, lhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.BindImageTexture(1, rhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.DispatchCompute(expand_values((lhs_texture.size + init_program.local_size-1) / init_program.local_size))
                    }

                    elapsed := make([dynamic]u64, context.temp_allocator)
                    for i in 0..<100 {
                        glfw.PollEvents()
                        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do break label_programs4
                        {
                            query_block(query, &elapsed)
                            gl.UseProgram(program.handle)
                            gl.Uniform3ui(0, expand_values(lhs_texture.size))
                            gl.BindTextureUnit(0, lhs_texture.handle)
                            gl.BindTextureUnit(1, rhs_texture.handle)
                            gl.BindImageTexture(0, lhs_texture2.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                            gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
                            gl.DispatchCompute(expand_values((lhs_texture.size + program.local_size-1) / program.local_size))
                        }
                        lhs_texture, lhs_texture2 = lhs_texture2, lhs_texture
                    }

                    {
                        data := readback_single_texel(lhs_texture, verify_buffer, readback_single_texel_program)

                        time, bw := reduce_queries(elapsed[3:], int(Nx)*int(Ny)*int(Nz)*format_size*3)
                        
                        fmt.printf("%f \t%.1f \t%.9f\n", time, bw, data)
                    }
                }

                //gl.Flush();
            }

            if false {
                fmt.println("Jacobi 2")
                label_programs3: for program in jacobi_programs2 {
                    if !(program.local_size == {8, 8, 8} || program.local_size == {4, 4, 4}) do continue
                    fmt.printf("% 2v = % 4d \t", program.local_size, program.local_size.x*program.local_size.y*program.local_size.z)
                    
                    {
                        init_program := init_programs[len(init_programs)-1]
                        gl.UseProgram(init_program.handle)
                        gl.Uniform1i(2, 0)
                        gl.Uniform1f(0, dx)
                        gl.Uniform3f(1, expand_values(1.0 / linalg.to_f32(lhs_texture.size + 1)))
                        gl.BindImageTexture(0, lhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.BindImageTexture(1, rhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.DispatchCompute(expand_values((lhs_texture.size + init_program.local_size-1) / init_program.local_size))
                    }

                    elapsed := make([dynamic]u64, context.temp_allocator)
                    for i in 0..<100 {
                        glfw.PollEvents()
                        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do break label_programs3
                        {
                            query_block(query, &elapsed)
                            gl.UseProgram(program.handle)
                            gl.Uniform3ui(0, expand_values(lhs_texture.size))
                            gl.BindTextureUnit(0, lhs_texture.handle)
                            gl.BindTextureUnit(1, rhs_texture.handle)
                            gl.BindImageTexture(0, lhs_texture2.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                            gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
                            gl.DispatchCompute(expand_values((lhs_texture.size + program.local_size-1) / program.local_size))
                        }
                        lhs_texture, lhs_texture2 = lhs_texture2, lhs_texture
                    }

                    {
                        data := readback_single_texel(lhs_texture, verify_buffer, readback_single_texel_program)

                        time, bw := reduce_queries(elapsed[3:], int(Nx)*int(Ny)*int(Nz)*format_size*3)
                        
                        fmt.printf("%f \t%.1f \t%.9f\n", time, bw, data)
                    }
                }
            }
            if false {
                fmt.println("Jacobi 2 Multi")
                label_programs5: for program in jacobi_programs2_multi {
                    fmt.printf("% 2v = % 4d \t", program.local_size, program.local_size.x*program.local_size.y*program.local_size.z)
                    
                    {
                        init_program := init_programs[len(init_programs)-1]
                        gl.UseProgram(init_program.handle)
                        gl.Uniform1i(2, 0)
                        gl.Uniform1f(0, dx)
                        gl.Uniform3f(1, expand_values(1.0 / linalg.to_f32(lhs_texture.size + 1)))
                        gl.BindImageTexture(0, lhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.BindImageTexture(1, rhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.DispatchCompute(expand_values((lhs_texture.size + init_program.local_size-1) / init_program.local_size))
                    }

                    elapsed := make([dynamic]u64, context.temp_allocator)
                    for i in 0..<100 {
                        glfw.PollEvents()
                        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do break label_programs5
                        {
                            query_block(query, &elapsed)
                            gl.UseProgram(program.handle)
                            gl.Uniform3ui(0, expand_values(lhs_texture.size))
                            gl.BindTextureUnit(0, lhs_texture.handle)
                            gl.BindTextureUnit(1, rhs_texture.handle)
                            gl.BindImageTexture(0, lhs_texture2.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                            gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
                            gl.DispatchCompute(expand_values((lhs_texture.size + program.local_size-1) / program.local_size))
                        }
                        lhs_texture, lhs_texture2 = lhs_texture2, lhs_texture
                    }

                    {
                        data := readback_single_texel(lhs_texture, verify_buffer, readback_single_texel_program)

                        time, bw := reduce_queries(elapsed[3:], int(Nx)*int(Ny)*int(Nz)*format_size*3)
                        
                        fmt.printf("%f \t%.1f \t%.9f\n", time, bw, data)
                    }
                }

                //gl.Flush();
            }
            if true {
                fmt.println("Box Blur")
                label_programs6: for program, j in box_blur_programs {
                    fmt.printf("% 2v = % 4d \t", program.local_size, program.local_size.x*program.local_size.y*program.local_size.z)
                    
                    {
                        init_program := init_programs[len(init_programs)-1]
                        gl.UseProgram(init_program.handle)
                        gl.Uniform1f(0, dx)
                        gl.Uniform3f(1, expand_values(1.0 / linalg.to_f32(lhs_texture.size + 1)))
                        gl.Uniform1i(2, 1)
                        gl.BindImageTexture(0, lhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.BindImageTexture(1, rhs_texture.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                        gl.DispatchCompute(expand_values((lhs_texture.size + init_program.local_size-1) / init_program.local_size))
                    }

                    elapsed := make([dynamic]u64, context.temp_allocator)
                    for i in 0..<100 {
                        glfw.PollEvents()
                        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do break label_programs6
                        {
                            gl.UseProgram(program.handle)
                            if j >= 2 {
                                gl.Uniform3ui(0, expand_values(linalg.to_u32(lhs_texture.size)))
                            } else {
                                gl.Uniform3i(0, expand_values(linalg.to_i32(lhs_texture.size)))
                            }
                            gl.BindTextureUnit(0, lhs_texture.handle)
                            gl.BindImageTexture(0, lhs_texture2.handle, 0, gl.TRUE, 0, gl.WRITE_ONLY, internal_format);
                            gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
                            query_block(query, &elapsed)
                            gl.DispatchCompute(expand_values((lhs_texture.size + program.local_size-1) / program.local_size))
                        }
                        lhs_texture, lhs_texture2 = lhs_texture2, lhs_texture
                    }

                    {
                        data := readback_single_texel(lhs_texture, verify_buffer, readback_single_texel_program)

                        time, bw := reduce_queries(elapsed[3:], int(Nx)*int(Ny)*int(Nz)*format_size*2)
                        
                        fmt.printf("%f \t%.1f \t%.9f   %s\n", time, bw, data, program.filename)
                    }
                }

                //gl.Flush();
            }

            glfw.SwapBuffers(window);
            glfw.SwapBuffers(window);
            glfw.SwapBuffers(window);
        }
    }
}

load_compute_program :: proc(filenames: string) -> u32 {
    program, success := gl.load_compute_file(filenames);
    if !success {
        fmt.println("Filename:", filenames)
        return 0;
    }
    return program;
}

load_compute_source :: proc(source: string, loc := #caller_location) -> u32 {
    program, success := gl.load_compute_source(source);
    if !success {
        fmt.println("Location:", loc)
        return 0;
    }
    return program;
}

BEGIN_GL_LABEL_BLOCK :: proc(name: string) {
    gl.PushDebugGroup(gl.DEBUG_SOURCE_APPLICATION, 0, i32(len(name)), strings.unsafe_string_to_cstring(name));
}

END_GL_LABEL_BLOCK :: proc() {
    gl.PopDebugGroup();
}

@(deferred_out=END_GL_LABEL_BLOCK)
GL_LABEL_BLOCK :: proc(name: string) {
    BEGIN_GL_LABEL_BLOCK(name);
}