package masterclass

import "core:fmt"
import "core:math"
import "core:math/linalg"
import stbi "vendor:stb/image"
import gl "vendor:OpenGL";

RGB :: [3]f32

load_and_process_hdri :: proc() -> ([3][3][3]RGB, u32) {
    x, y, c: i32
    //p := stbi.loadf("hdris/abandoned_parking_4k.hdr", &x, &y, &c, 3)
    //p := stbi.loadf("hdris/derelict_overpass_4k.hdr", &x, &y, &c, 3)
    //p := stbi.loadf("hdris/rogland_clear_night_4k.hdr", &x, &y, &c, 3)
    //p := stbi.loadf("hdris/rosendal_plains_2_4k.hdr", &x, &y, &c, 3)
    //p := stbi.loadf("hdris/sunflowers_4k.hdr", &x, &y, &c, 3)
    //p := stbi.loadf("hdris/lakeside_4k.hdr", &x, &y, &c, 3)
    p := stbi.loadf("hdris/small_empty_room_3_4k.hdr", &x, &y, &c, 3)
    //p := stbi.loadf("hdris/ouchy_pier_4k.hdr", &x, &y, &c, 3)
    defer stbi.image_free(p)

    data: [3][3][3]RGB
    if true && p != nil {
        sum_colors: [3][3][3]RGB
        solid_angles: [3][3][3]f32
        for j in 0..<y {
            partial_sum_colors: [3][3][3]RGB
            partial_solid_angles: [3][3][3]f32
            
            pitch_N := math.PI*f32(j)/f32(y)
            pitch_S := math.PI*f32(j+1)/f32(y)
            pitch := (pitch_S + pitch_N) / 2.0
            
            for i in 0..<x {
                R := p[3*(j*x+i)+0]
                G := p[3*(j*x+i)+1]
                B := p[3*(j*x+i)+2]

                yaw_W := 2*math.PI*f32(i)/f32(x)
                yaw_E := 2*math.PI*f32(i+1)/f32(x)
                yaw := (yaw_W + yaw_E) / 2.0

                r := [3]f32{math.sin(pitch)*math.cos(yaw), math.sin(pitch)*math.sin(yaw), math.cos(pitch)}
                
                closest_ijk: [3]int
                closest_dot: f32 = -1e9
                for K in -1..=+1 do for J in -1..=+1 do for I in -1..=+1 {
                    if K == 0 && J == 0 && I == 0 do continue

                    d := linalg.normalize([3]f32{f32(I), f32(J), f32(K)})
                    dot := linalg.dot(r, d)

                    if dot > closest_dot {
                        closest_dot = dot
                        closest_ijk = {I, J, K}
                    }
                }

                partial_sum_colors[closest_ijk.z+1][closest_ijk.y+1][closest_ijk.x+1] += [3]f32{R, G, B}
                partial_solid_angles[closest_ijk.z+1][closest_ijk.y+1][closest_ijk.x+1] += f32((math.cos(pitch_N) - math.cos(pitch_S)) * (yaw_E - yaw_W))
            }
            sum_colors += partial_sum_colors * (math.cos(pitch_N) - math.cos(pitch_S)) * 2.0*math.PI / f32(x)
            solid_angles += partial_solid_angles
        }

        for k in 0..<3 do for j in 0..<3 do for i in 0..<3 {
            if i == 1 && j == 1 && k == 1 do continue
            data[k][j][i] = sum_colors[k][j][i] / solid_angles[k][j][i]
        }
    } else {
        data = 1.0
    }

    s := RGB{}
    for z in 0..<3 do for y in 0..<3 do for x in 0..<3 do s += data[z][y][x]
    fmt.println("Total env map color:", s)

    tex: u32;
    if p != nil {
        gl.CreateTextures(gl.TEXTURE_2D, 1, &tex);
        gl.TextureParameteri(tex, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.TextureParameteri(tex, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TextureParameteri(tex, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TextureParameteri(tex, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TextureStorage2D(tex, 1, gl.RGB32F, x, y);
        gl.TextureSubImage2D(tex, 0,  0, 0,  x, y,  gl.RGB, gl.FLOAT, p)
    }

    return data, tex
}