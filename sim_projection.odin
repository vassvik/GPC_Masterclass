package masterclass

import "core:fmt"
import "core:math/linalg"
import gl "vendor:OpenGL";


mem_divergence := 8.0
mem_jacobi := 6.0
mem_sor := mem_jacobi
mem_residual := mem_jacobi
mem_restrict := (1.0 + 1.0/8.0) * 2.0
mem_prolongate := (1.0/8.0 + 1.0 + 1.0) * 2.0
mem_gradient := 14.0
mem_zero := 2.0

do_divergence :: proc(divergence_texture, velocity_x_texture, velocity_y_texture, velocity_z_texture: u32, size: [3]i32, compute_stats: bool) {
    GL_LABEL_BLOCK("Divergence");
    //query_block(.Divergence);

    gl.BindTextureUnit(0, velocity_x_texture);
    gl.BindTextureUnit(1, velocity_y_texture);
    gl.BindTextureUnit(2, velocity_z_texture);
    gl.BindImageTexture(0, divergence_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    
    gl.UseProgram(ctx.compute_programs["divergence"].handle)
    gl.Uniform1i(0, i32(compute_stats));
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    if compute_stats {
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
    } else {
        block_query("divergence", ctx.timestep, int(size.x*size.y*size.z)*8, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
    }
}

do_divergence2 :: proc(divergence_texture, velocity_x_texture, velocity_y_texture, velocity_z_texture: u32, size: [3]i32, compute_stats: bool) {
    GL_LABEL_BLOCK("Divergence");
    //query_block(.Divergence);

    gl.BindTextureUnit(0, velocity_x_texture);
    gl.BindTextureUnit(1, velocity_y_texture);
    gl.BindTextureUnit(2, velocity_z_texture);
    gl.BindImageTexture(0, divergence_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    
    gl.UseProgram(ctx.compute_programs["divergence2"].handle)
    gl.Uniform1i(0, i32(compute_stats));
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    if compute_stats {
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8} / 2))
    } else {
        block_query("divergence", ctx.timestep, int(size.x*size.y*size.z)*8, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8} / 2))
    }
}

do_compare_divergence :: proc(divergence_texture1, divergence_texture2, velocity_x_texture, velocity_y_texture, velocity_z_texture: u32, size: [3]i32) {
    //if true do return
    gl.ClearNamedBufferSubData(ctx.stats_buffer, gl.R32I, 0, 2*32*32*size_of(i32), gl.RED_INTEGER, gl.INT, nil)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, ctx.stats_buffer)

    gl.BindTextureUnit(0, divergence_texture1);
    gl.BindTextureUnit(1, divergence_texture2);

    gl.UseProgram(ctx.compute_programs["compare_divergence"].handle)
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    gl.DispatchCompute(ro2(u32(size.x), 16)/16, ro2(u32(size.y), 8)/8, ro2(u32(size.z), 8)/8)

    stats: [2*32][32]i32
    gl.GetNamedBufferSubData(ctx.stats_buffer, 0, 2*32*32*size_of(i32), &stats[0])


    max_j, max_i := 0, 0
    for j in 0..<32 {
        for i in 0..<32 {
            if stats[i][j] != 0 {
                max_i = max(max_i, i+1)
                max_j = max(max_j, j+1)
            }
        }
    }

    max_k := 0
    for j in 0..<32 {
        for i in 0..<32 {
            if stats[32+i][j] != 0 {
                max_k = max(max_k, i+1)
            }
        }
    }

    if false {
        s := fmt.tprintf("    ")
        for i in -max_i+1..<max_j {
            s = fmt.tprintf("%s% +7d\t", s, i)
        }
        s = fmt.tprintf("%s\n", s)
        for i in 0..<max_i {
            s = fmt.tprintf("%s% +3d\t", s, i-24)
            for j in -max_i+1..<max_j {
                if i+j < 0 || i+j >= max_j {
                    s = fmt.tprintf("%s       \t", s)
                } else {
                    s = fmt.tprintf("%s% 7d\t", s, min(9999999, stats[i][i+j])); //1000000 * f32(stats[i]) / f32(sum))
                }
            } 
        /*
        */
            s = fmt.tprintf("%s\n", s)
        }
        fmt.println(s)
    }
    if false {
        s := fmt.tprintf("    ")
        for i in 0..<max_i {
            s = fmt.tprintf("%s% +7d\t", s, i-24)
        }
        s = fmt.tprintf("%s\n", s)

        for j in -max_i+1..<max_j {
            s = fmt.tprintf("%s% +3d\t", s, j)
            for i in 0..<max_i {
                if i+j < 0 || i+j >= max_j {
                    s = fmt.tprintf("%s       \t", s)
                } else {
                    s = fmt.tprintf("%s% 7d\t", s, min(9999999, stats[i][i+j])); //1000000 * f32(stats[i]) / f32(sum))
                }
            } 
            s = fmt.tprintf("%s\n", s)
        }
        fmt.println(s)
    }
    {
        s := fmt.tprintf("%s    ", "")
        for i in 0..<max_i {
            s = fmt.tprintf("%s% +7d\t", s, i-24)
        }
        s = fmt.tprintf("%s\n", s)

        sum2: [32]i32
        for j in 0..<max_j {
            sum := i32(0)
            s = fmt.tprintf("%s% +3d\t", s, j-24)
            for i in 0..<max_i {
                s = fmt.tprintf("%s% 7d\t", s, min(9999999, stats[i][j])); //1000000 * f32(stats[i]) / f32(sum))
                sum += stats[i][j]
                sum2[i] += stats[i][j]
            } 
            s = fmt.tprintf("%s% 7d\t", s, min(9999999, sum)); //1000000 * f32(stats[i]) / f32(sum))
            s = fmt.tprintf("%s\n", s)
        }
        s = fmt.tprintf("%s    ", s)
        for i in 0..<max_i {
            s = fmt.tprintf("%s% 7d\t", s, min(9999999, sum2[i]))
        }
        s = fmt.tprintf("%s\n", s)
        fmt.println(s)
    }

    {
        s := fmt.tprintf("%s    ", "")
        for i in 0..<max_k {
            s = fmt.tprintf("%s% +7d\t", s, i-24)
        }
        s = fmt.tprintf("%s\n", s)

        sum2: [32]i32
        for j in 0..<max_j {
            sum := i32(0)
            s = fmt.tprintf("%s% +3d\t", s, j-24)
            for i in 0..<max_k {
                s = fmt.tprintf("%s% 7d\t", s, min(9999999, stats[32+i][j])); //1000000 * f32(stats[i]) / f32(sum))
                sum += stats[32+i][j]
                sum2[i] += stats[32+i][j]
            } 
            s = fmt.tprintf("%s% 7d\t", s, min(9999999, sum)); //1000000 * f32(stats[i]) / f32(sum))
            s = fmt.tprintf("%s\n", s)
        }
        s = fmt.tprintf("%s    ", s)
        for i in 0..<max_i {
            s = fmt.tprintf("%s% 7d\t", s, min(9999999, sum2[i]))
        }
        s = fmt.tprintf("%s\n", s)
        fmt.println(s)
    }



}

do_gradient :: proc(pressure_texture, velocity_x_texture, velocity_y_texture, velocity_z_texture: u32, size: [3]i32) {
    GL_LABEL_BLOCK("Gradient");
    //query_block(.Gradient);

    gl.BindTextureUnit(0, pressure_texture);
    gl.BindTextureUnit(1, velocity_x_texture);
    gl.BindTextureUnit(2, velocity_y_texture);
    gl.BindTextureUnit(3, velocity_z_texture);
    gl.BindImageTexture(0, velocity_x_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    gl.BindImageTexture(1, velocity_y_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    gl.BindImageTexture(2, velocity_z_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    
    gl.UseProgram(ctx.compute_programs["gradient"].handle)
    gl.Uniform3i(0, expand_values(size));
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    block_query("gradient", ctx.timestep, int(size.x*size.y*size.z)*14, .Simulation)
    gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
}

do_zero_pressure :: proc(pressure_ping_texture: u32, size: [3]i32){
    GL_LABEL_BLOCK("Zero Pressure");
    
    gl.BindImageTexture(0, pressure_ping_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);

    gl.UseProgram(ctx.compute_programs["zero"].handle)
    block_query(fmt.tprintf("zero %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*2, .Simulation)
    gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
}

do_jacobi :: proc(ping_texture, pong_texture: ^u32, divergence_texture: u32, omega: f32, size: [3]i32, iterations: int) {
    GL_LABEL_BLOCK("Jacobi");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["jacobi"].handle)
    gl.Uniform3i(0, expand_values(size));
    gl.Uniform1f(1, omega);
    gl.BindTextureUnit(1, divergence_texture);
    for i in 0..<iterations {
        gl.BindTextureUnit(0, ping_texture^);
        gl.BindImageTexture(0, pong_texture^, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
        block_query(fmt.tprintf("jacobi %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
        swap(ping_texture, pong_texture)
    }
}

do_jacobi_vertex :: proc(ping_texture, pong_texture: ^u32, divergence_texture: u32, omega: f32, size: [3]i32, iterations: int) {
    GL_LABEL_BLOCK("Jacobi Vertex");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["jacobi_vertex"].handle)
    gl.Uniform3i(0, expand_values(size));
    gl.Uniform1f(1, omega);
    gl.BindTextureUnit(1, divergence_texture);
    for i in 0..<iterations {
        gl.BindTextureUnit(0, ping_texture^);
        gl.BindImageTexture(0, pong_texture^, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
        block_query(fmt.tprintf("jacobi vertex %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
        swap(ping_texture, pong_texture)
    }
}

do_jacobi_vertex2 :: proc(ping_texture, pong_texture: ^u32, divergence_texture: u32, omega: f32, size: [3]i32, iterations: int) {
    GL_LABEL_BLOCK("Jacobi Vertex");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["jacobi_vertex2"].handle)
    gl.Uniform3ui(0, expand_values(linalg.to_u32(size)));
    gl.Uniform1f(1, omega);
    gl.BindTextureUnit(1, divergence_texture);
    for i in 0..<iterations {
        gl.BindTextureUnit(0, ping_texture^);
        gl.BindImageTexture(0, pong_texture^, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
        block_query(fmt.tprintf("jacobi vertex %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8} / 2))
        swap(ping_texture, pong_texture)
    }
}

do_jacobi_vertex3 :: proc(ping_texture, pong_texture: ^u32, divergence_texture: u32, omega: f32, size: [3]i32, iterations: int) {
    GL_LABEL_BLOCK("Jacobi Vertex");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["jacobi_vertex3"].handle)
    gl.Uniform3ui(0, expand_values(linalg.to_u32(size)));
    gl.Uniform1f(1, omega);
    gl.BindTextureUnit(1, divergence_texture);
    for i in 0..<iterations {
        gl.BindTextureUnit(0, ping_texture^);
        gl.BindImageTexture(0, pong_texture^, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
        block_query(fmt.tprintf("jacobi vertex %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8} / 2))
        swap(ping_texture, pong_texture)
    }
}

do_jacobi_vertex4 :: proc(ping_texture, pong_texture: ^u32, divergence_texture: u32, omega: f32, size: [3]i32, iterations: int) {
    GL_LABEL_BLOCK("Jacobi Vertex");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["jacobi_vertex4"].handle)
    gl.Uniform3ui(0, expand_values(linalg.to_u32(size)));
    gl.Uniform1f(1, omega);
    gl.BindTextureUnit(1, divergence_texture);
    for i in 0..<iterations {
        gl.BindTextureUnit(0, ping_texture^);
        gl.BindImageTexture(0, pong_texture^, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
        block_query(fmt.tprintf("jacobi vertex %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
        swap(ping_texture, pong_texture)
    }
}

do_sor :: proc(ping_texture, pong_texture: ^u32, divergence_texture: u32, omega: f32, size: [3]i32, iterations: int) {
    GL_LABEL_BLOCK("SOR");
    //query_block(.Jacobi);
    program := ctx.compute_programs["sor"]
    gl.UseProgram(program.handle)
    gl.Uniform3i(0, expand_values(size));
    gl.Uniform1f(1, omega);
    gl.BindTextureUnit(1, divergence_texture);
    for i in 0..<2*iterations {
        gl.BindTextureUnit(0, ping_texture^);
        gl.BindImageTexture(0, ping_texture^, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.Uniform1i(2, i32(i%2));
        gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
        block_query(fmt.tprintf("sor %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
    }
}

do_sor2 :: proc(ping_texture, pong_texture: ^u32, divergence_texture: u32, omega: f32, size: [3]i32, iterations: int) {
    GL_LABEL_BLOCK("SOR");
    //query_block(.Jacobi);
    program := ctx.compute_programs["sor2"]
    gl.UseProgram(program.handle)
    gl.Uniform3i(0, expand_values(size));
    gl.Uniform1f(1, omega);
    gl.BindTextureUnit(1, divergence_texture);
    for i in 0..<1*iterations {
        gl.BindTextureUnit(0, ping_texture^);
        gl.BindImageTexture(0, pong_texture^, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
        block_query(fmt.tprintf("sor %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6*2, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
        swap(ping_texture, pong_texture)
    }
}

do_residual :: proc(ping_texture, pong_texture: u32, divergence_texture: u32, size: [3]i32)  {
    GL_LABEL_BLOCK("Residual");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["residual"].handle)
    gl.Uniform3i(0, expand_values(size));
    gl.BindTextureUnit(1, divergence_texture);
    gl.BindTextureUnit(0, ping_texture);
    gl.BindImageTexture(0, pong_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    block_query(fmt.tprintf("residual %d", ctx.sizes[.X1].x/size.x), ctx.timestep, int(size.x*size.y*size.z)*6, .Simulation)
    gl.DispatchCompute(expand_values(linalg.to_u32(size) / {8, 8, 8}))
}

do_restrict :: proc(residual_texture: u32, divergence_texture: u32, fine_size, coarse_size: [3]i32)  {
    GL_LABEL_BLOCK("Restrict");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["restrict"].handle)
    gl.Uniform3i(0, expand_values(fine_size));
    gl.BindTextureUnit(0, residual_texture);
    gl.BindImageTexture(0, divergence_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    block_query(fmt.tprintf("restrict %d-%d", ctx.sizes[.X1].x/fine_size.x, ctx.sizes[.X1].x/coarse_size.x), ctx.timestep, int(coarse_size.x*coarse_size.y*coarse_size.z)*(8+1)*2, .Simulation)
    gl.DispatchCompute(expand_values(linalg.to_u32(coarse_size) / {8, 8, 8}))
}

do_prolongate :: proc(coarse_pressure_texture, fine_pressure_texture: u32, coarse_size, fine_size: [3]i32)  {
    GL_LABEL_BLOCK("Prolongate");
    //query_block(.Jacobi);
    gl.UseProgram(ctx.compute_programs["prolongate"].handle)
    gl.Uniform3i(0, expand_values(coarse_size));
    gl.BindTextureUnit(0, coarse_pressure_texture);
    gl.BindTextureUnit(1, fine_pressure_texture);
    gl.BindImageTexture(0, fine_pressure_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    block_query(fmt.tprintf("prolongate %d-%d", ctx.sizes[.X1].x/coarse_size.x, ctx.sizes[.X1].x/fine_size.x), ctx.timestep, int(coarse_size.x*coarse_size.y*coarse_size.z)*(1+8+8)*2, .Simulation)
    gl.DispatchCompute(expand_values(linalg.to_u32(fine_size) / {8, 8, 8}))
}

vcycle :: proc(current_level, max_level: Resolution) {
    num_voxels := ctx.sizes[.X1].x*ctx.sizes[.X1].y*ctx.sizes[.X1].z
    mem_vcycle2 := 16*2*mem_sor/64.0
    mem_vcycle1 := (2*mem_jacobi + mem_residual + mem_restrict + mem_zero/8.0 + mem_prolongate + 2*mem_jacobi)/8.0 + mem_vcycle2
    mem_vcycle0 := (2*mem_jacobi + mem_residual + mem_restrict + mem_zero/8.0 + mem_prolongate + 2*mem_jacobi)/1.0 + mem_vcycle1
    mem_cycles := [Resolution]f64 {.X1 = mem_vcycle0, .X2 = mem_vcycle1, .X4 = mem_vcycle2}
    
    block_query(fmt.tprintf("vcycle %v", current_level), ctx.timestep, int(mem_cycles[current_level])*int(ctx.num_voxels[.X1]), .Simulation)

    if current_level == max_level {
        divergence_texture    := &ctx.aux_textures[current_level][0]
        pressure_ping_texture := &ctx.aux_textures[current_level][1]
        pressure_pong_texture := &ctx.aux_textures[current_level][2]

        do_sor2(pressure_ping_texture, pressure_pong_texture, divergence_texture^, 1.8, ctx.sizes[current_level], ctx.solves2)
        return
    }

    next_level := Resolution(int(current_level)+1)
    divergence_texture0    := &ctx.aux_textures[current_level][0]
    pressure_ping_texture0 := &ctx.aux_textures[current_level][1]
    pressure_pong_texture0 := &ctx.aux_textures[current_level][2]

    divergence_texture1    := &ctx.aux_textures[next_level][0]
    pressure_ping_texture1 := &ctx.aux_textures[next_level][1]
    pressure_pong_texture1 := &ctx.aux_textures[next_level][2]

    do_jacobi(pressure_ping_texture0, pressure_pong_texture0, divergence_texture0^, 8.0/9.0, ctx.sizes[current_level], ctx.pre_smooths0 if current_level == .X1 else ctx.pre_smooths1)

    do_residual(pressure_ping_texture0^, pressure_pong_texture0^, divergence_texture0^, ctx.sizes[current_level])
    do_restrict(pressure_pong_texture0^, divergence_texture1^, ctx.sizes[current_level], ctx.sizes[next_level])
    do_zero_pressure(pressure_ping_texture1^, ctx.sizes[next_level])
    
    vcycle(next_level, max_level)
    
    do_prolongate(pressure_ping_texture1^, pressure_ping_texture0^, ctx.sizes[next_level], ctx.sizes[current_level])
    
    do_jacobi(pressure_ping_texture0, pressure_pong_texture0, divergence_texture0^, 8.0/9.0, ctx.sizes[current_level], ctx.post_smooths0 if current_level == .X2 else ctx.post_smooths1)
}