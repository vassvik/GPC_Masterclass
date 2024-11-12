package masterclass

import "core:fmt"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL";

do_lighting :: proc() {
 	gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    {
        GL_LABEL_BLOCK("Lighting 1");

        gl.UseProgram(ctx.compute_programs["lighting1"].handle)

        gl.BindTextureUnit(0, ctx.reduced_smoke_texture1);
        gl.BindImageTexture(0, ctx.attenuation_texture1, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.R16F);
        gl.Uniform3i(0, expand_values(ctx.sizes[.X2]));

        block_query("lighting1", ctx.frame, 1, .Render)
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X2]/16)))
    }
    gl.MemoryBarrier(gl.TEXTURE_FETCH_BARRIER_BIT)
    {
        GL_LABEL_BLOCK("Lighting 2");

        cp := math.cos(math.to_radians(ctx.phi))
        sp := math.sin(math.to_radians(ctx.phi))
        ct := math.cos(math.to_radians(ctx.theta))
        st := math.sin(math.to_radians(ctx.theta))
        eye := ctx.distance*[3]f32{cp*st, sp*st, ct}

        cam_pos0 := eye + linalg.to_f32(ctx.sizes[.X1])/2.0

        gl.UseProgram(ctx.compute_programs["lighting2"].handle)

        gl.BindTextureUnit(0, ctx.attenuation_texture1);
        gl.BindTextureUnit(1, ctx.reduced_smoke_texture1);
        gl.BindImageTexture(0, ctx.lighting_texture1, 0, gl.TRUE, 0, gl.WRITE_ONLY, gl.RGBA16F);
        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, ctx.envmap_buffer)


        gl.Uniform3i(0, expand_values(ctx.sizes[.X2]));
        gl.Uniform3f(1, expand_values(cam_pos0));
        gl.Uniform1f(2, ctx.density_scale_base * f32(ctx.voxel_size));
        block_query("lighting2", ctx.frame, 1, .Render)
        gl.DispatchCompute(expand_values(linalg.to_u32(ctx.sizes[.X2]/8)))
    }
}

do_render:: proc() {
    {
        cp := math.cos(math.to_radians(ctx.phi))
        sp := math.sin(math.to_radians(ctx.phi))
        ct := math.cos(math.to_radians(ctx.theta))
        st := math.sin(math.to_radians(ctx.theta))
        camera_forward := -[3]f32{cp*st, sp*st, ct}
        global_up := [3]f32{0, 0, 1}
        camera_right := linalg.normalize(linalg.cross(camera_forward, global_up))
        camera_up := linalg.cross(camera_right, camera_forward)


        fovy := math.to_radians(f32(60.0))
        ratio := f32(ctx.main_window.width) / f32(ctx.main_window.height)
        tan_half_fovy := math.tan(fovy/2.0)

        //fmt.println(camera_forward, camera_right, camera_up, tan_half_fovy, tan_half_fovy*ratio)

        gl.UseProgram(ctx.raster_programs["background"].handle)
        gl.Uniform3f(0, expand_values(camera_forward));
        gl.Uniform3f(1, expand_values(camera_right*tan_half_fovy*ratio));
        gl.Uniform3f(2, expand_values(camera_up*tan_half_fovy));

        gl.BindTextureUnit(0, ctx.envmap_texture)
        gl.DrawArrays(gl.TRIANGLES, 0, 3);
    }
	{
        GL_LABEL_BLOCK("Render Voxels")

	    gl.Enable(gl.CULL_FACE)
	    gl.CullFace(gl.BACK)

        //gl.ClearColor(expand_values(linalg.pow([3]f32{135,206,235}/255, 2.2)), 1.0)
        //gl.Clear(gl.COLOR_BUFFER_BIT)
      
        // https://gist.github.com/vassvik/f8c1b4fbd5469dc90293a95b279ebacf
        num_tiles := linalg.to_u32(ctx.sizes[.X1]/8);
        tile_count := num_tiles.x * num_tiles.y * num_tiles.z

        cam_pos0 := ctx.eye/8 + linalg.to_f32(num_tiles)/2.0
        cam_pos := cam_pos0
        cam_pos.x = clamp(cam_pos.x, 0.0, f32(num_tiles.x)-1)
        cam_pos.y = clamp(cam_pos.y, 0.0, f32(num_tiles.y)-1)
        cam_pos.z = clamp(cam_pos.z, 0.0, f32(num_tiles.z)-1)

        f := linalg.normalize([3]f32{0.0, 0.0, 0.0} - ctx.eye)

        // slice_axis == 0 --> slice, columns, rows
        // slice_axis == 1 --> columns, slice, rows
        // slice_axis == 2 --> columns, rows, slice
        u_slice_axis         := u32(0 if abs(f.x) > abs(f.y) && abs(f.x) > abs(f.z) else 1 if abs(f.y) > abs(f.z) else 2)
        u_num_slices         := num_tiles[u_slice_axis]
        u_num_tiles_in_slice := tile_count / u_num_slices
        u_num_columns        := num_tiles[1 if u_slice_axis == 0 else 0]
        u_num_rows           := num_tiles[1 if u_slice_axis == 2 else 2]
        u_cam_pos_column     := u32(cam_pos[1 if u_slice_axis == 0 else 0])
        u_cam_pos_row        := u32(cam_pos[1 if u_slice_axis == 2 else 2])
        u_cam_pos_slice      := u32(cam_pos[u_slice_axis])
        
        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
        gl.BlendEquation(gl.FUNC_ADD);

        gl.BindTextureUnit(0, ctx.mask_texture)
        gl.BindTextureUnit(1, ctx.lighting_texture1)
        gl.BindTextureUnit(2, ctx.smoke_textures[.X1])
        
        gl.UseProgram(ctx.raster_programs["voxels"].handle)
        
        gl.UniformMatrix4fv(0, 1, gl.FALSE, &ctx.PVM[0][0])
        gl.Uniform3i(1, expand_values(ctx.sizes[.X1]));
        gl.Uniform1ui(2, u_slice_axis)
        gl.Uniform1ui(3, 1) // u_back_to_front
        gl.Uniform1ui(4, u_num_slices)
        gl.Uniform1ui(5, u_num_tiles_in_slice)
        gl.Uniform1ui(6, u_num_columns)
        gl.Uniform1ui(7, u_num_rows)
        gl.Uniform1ui(8, u_cam_pos_column)
        gl.Uniform1ui(9, u_cam_pos_row)
        gl.Uniform1ui(10, u_cam_pos_slice)
        gl.Uniform3f(11, expand_values(8*cam_pos0));
        gl.Uniform1f(12, ctx.density_scale_base * f32(ctx.voxel_size));

        block_query("render", ctx.frame, 1, .Render)
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 14, ctx.num_voxels[.X1]/(8*8*8))
    }

    {
        GL_LABEL_BLOCK("Render Tiles")

        gl.UseProgram(ctx.raster_programs["tiles"].handle)

        gl.UniformMatrix4fv(0, 1, gl.FALSE, &ctx.PVM[0][0])
        gl.Uniform3i(1, expand_values(ctx.sizes[.X1]));

        gl.DrawArraysInstanced(gl.LINES, 0, 24, 1)
    }
}