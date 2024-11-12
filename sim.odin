package masterclass 

import "core:fmt"
import "core:math/linalg"
import gl "vendor:OpenGL";


do_sim_step :: proc() {
    if (ctx.pause && !ctx.should_step) do return

    num_voxels := ctx.sizes[.X1].x*ctx.sizes[.X1].y*ctx.sizes[.X1].z
    mem_vcycle2 := 16*2*mem_sor/64.0
    mem_vcycle1 := (2*mem_jacobi + mem_residual + mem_restrict + mem_zero/8.0 + mem_prolongate + 2*mem_jacobi)/8.0 + mem_vcycle2
    mem_vcycle0 := (2*mem_jacobi + mem_residual + mem_restrict + mem_zero/8.0 + mem_prolongate + 2*mem_jacobi)/1.0 + mem_vcycle1
    mem_poisson := mem_zero + mem_vcycle0 + mem_sor*2*2 + mem_jacobi*f64(ctx.post_corrections0)
    mem_projection := int(mem_divergence + mem_poisson + mem_gradient)*int(num_voxels)
    mem_advection := int(16.0)*int(num_voxels)
    mem_simulation := mem_advection + mem_projection

    block_query("simulation", ctx.timestep, mem_simulation, .Simulation)
    
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    {
        GL_LABEL_BLOCK("Advection");
        //fmt.println("Advected", ctx.timestep)

        gl.BindTextureUnit(0, ctx.velocity_x_textures[.X1]);
        gl.BindTextureUnit(1, ctx.velocity_y_textures[.X1]);
        gl.BindTextureUnit(2, ctx.velocity_z_textures[.X1]);
        gl.BindTextureUnit(3, ctx.smoke_textures[.X1]);
        gl.BindTextureUnit(4, ctx.mask_texture);
        gl.BindImageTexture(0, ctx.aux_textures[.X1][0], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.BindImageTexture(1, ctx.aux_textures[.X1][1], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.BindImageTexture(2, ctx.aux_textures[.X1][2], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.BindImageTexture(3, ctx.aux_textures[.X1][3], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        
        program := ctx.compute_programs["advection"]
        gl.UseProgram(program.handle)

        dt := f32(1.0)
        gl.Uniform3i(0, expand_values(ctx.sizes[.X1]));
        gl.Uniform3f(1, expand_values(1.0 / linalg.to_f32(ctx.sizes[.X1])));
        gl.Uniform1f(2, dt);
        gl.Uniform1f(3, ctx.voxel_size);
        gl.Uniform1f(4, ctx.smoke_weight * (dt/60.0) / ctx.voxel_size);

        block_query("advection", ctx.timestep, mem_advection, .Simulation)
        gl.DispatchCompute(expand_values(linalg.to_u32((ctx.sizes[.X1] + program.local_size - 1) / program.local_size)))

        swap(&ctx.velocity_x_textures[.X1],  &ctx.aux_textures[.X1][0])
        swap(&ctx.velocity_y_textures[.X1],  &ctx.aux_textures[.X1][1])
        swap(&ctx.velocity_z_textures[.X1],  &ctx.aux_textures[.X1][2])
        swap(&ctx.smoke_textures[.X1],       &ctx.aux_textures[.X1][3])
    }
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    {
        GL_LABEL_BLOCK("Reducing Data");
        gl.UseProgram(ctx.compute_programs["reduction"].handle)

        gl.BindTextureUnit(0, ctx.smoke_textures[.X1]);
        gl.BindImageTexture(0, ctx.reduced_smoke_texture1, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);

        block_query("reduce data", ctx.frame, int(2*ctx.num_voxels[.X1] + 2*ctx.num_voxels[.X2]), .Render)
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X2]/4)))
    }
    {
        GL_LABEL_BLOCK("Computing Mask");
        gl.UseProgram(ctx.compute_programs["mask"].handle)

        gl.BindTextureUnit(0, ctx.smoke_textures[.X1]);
        gl.BindImageTexture(0, ctx.mask_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R8);

        block_query("compute mask", ctx.frame, int(2*ctx.num_voxels[.X1] + 1*ctx.num_voxels[.X1]/(8*8*8)), .Render)
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X1]/8)))
    }
    {
        GL_LABEL_BLOCK("Projection");
        divergence_texture    := &ctx.aux_textures[.X1][0]
        pressure_ping_texture := &ctx.aux_textures[.X1][1]
        pressure_pong_texture := &ctx.aux_textures[.X1][2]
        divergence_texture2   := &ctx.aux_textures[.X1][3]
        
        {
            block_query("projection", ctx.timestep, mem_projection, .Simulation)
            do_divergence2(divergence_texture^, ctx.velocity_x_textures[.X1], ctx.velocity_y_textures[.X1], ctx.velocity_z_textures[.X1], ctx.sizes[.X1], false)
            {
                block_query("poisson", ctx.timestep, int(mem_poisson)*int(ctx.num_voxels[.X1]), .Simulation)
                gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
                do_zero_pressure(pressure_ping_texture^, ctx.sizes[.X1])
                vcycle(.X1, .X4)
                do_sor(pressure_ping_texture, pressure_pong_texture, divergence_texture^, 1.9, ctx.sizes[.X1], ctx.post_solves0)
                do_jacobi_vertex3(pressure_ping_texture, pressure_pong_texture, divergence_texture^, 0.5, ctx.sizes[.X1], ctx.post_corrections0)
            }
            do_gradient(pressure_ping_texture^, ctx.velocity_x_textures[.X1], ctx.velocity_y_textures[.X1], ctx.velocity_z_textures[.X1], ctx.sizes[.X1])
        }

        if ctx.should_step {
            do_divergence(divergence_texture2^, ctx.velocity_x_textures[.X1], ctx.velocity_y_textures[.X1], ctx.velocity_z_textures[.X1], ctx.sizes[.X1], true)
            do_compare_divergence(divergence_texture^, divergence_texture2^, ctx.velocity_x_textures[.X1], ctx.velocity_y_textures[.X1], ctx.velocity_z_textures[.X1], ctx.sizes[.X1])
        }
    }

    ctx.should_step = false
    ctx.timestep += 1
}

do_sim_reset :: proc() {
    fmt.println("Resetting Data")
    {
        GL_LABEL_BLOCK("Zero All Data");
        
        gl.UseProgram(ctx.compute_programs["zero"].handle)
        gl.BindImageTexture(0, ctx.smoke_textures[.X1], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X1] / 8)))
        gl.BindImageTexture(0, ctx.velocity_x_textures[.X1], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X1] / 8)))
        gl.BindImageTexture(0, ctx.velocity_y_textures[.X1], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X1] / 8)))
        gl.BindImageTexture(0, ctx.velocity_z_textures[.X1], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X1] / 8)))
    }

    gl.MemoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT)
    {
        GL_LABEL_BLOCK("Copy Leaf Data");
        gl.UseProgram(ctx.compute_programs["copy_leaves"].handle)

        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, ctx.bufs[0])
        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, ctx.bufs[1])

        gl.BindImageTexture(0, ctx.smoke_textures[.X1], 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);

        gl.DispatchCompute(ctx.header.num_tiles, 1, 1)
    }
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    {
        GL_LABEL_BLOCK("Reducing Data");
        gl.UseProgram(ctx.compute_programs["reduction"].handle)

        gl.BindTextureUnit(0, ctx.smoke_textures[.X1]);
        gl.BindImageTexture(0, ctx.reduced_smoke_texture1, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);

        block_query("reduce data", ctx.frame, int(2*ctx.num_voxels[.X1] + 2*ctx.num_voxels[.X2]), .Render)
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X2]/4)))
    }
    {
        GL_LABEL_BLOCK("Computing Mask");
        gl.UseProgram(ctx.compute_programs["mask"].handle)

        gl.BindTextureUnit(0, ctx.smoke_textures[.X1]);
        gl.BindImageTexture(0, ctx.mask_texture, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R8);

        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X1]/8)))
    }
}