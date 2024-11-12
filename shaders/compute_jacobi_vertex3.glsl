#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform uvec3 u_size;
layout(location = 1) uniform float u_omega;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_divergence_texture;

layout(binding = 0) writeonly uniform image3D u_pressure_image;

shared float shared_x[18][18][18];

void cache_internal(uvec3 wid, uvec3 lid) {
    uvec3 gid = 16*wid + lid;
    float x = texelFetch(u_pressure_texture, ivec3(gid), 0).x;
    shared_x[1+lid.z][1+lid.y][1+lid.x] = x;
}

void cache_boundary(uvec3 wid, uvec3 lid) {
    uvec3 gid = 16*wid + lid;
    
    if (any(greaterThanEqual(gid, u_size))) {
        shared_x[1+lid.z][1+lid.y][1+lid.x] = 0.0;
        return;
    } 

    float x = texelFetch(u_pressure_texture, ivec3(gid), 0).x;
    shared_x[1+lid.z][1+lid.y][1+lid.x] = x;
}

float decode2(uvec3 idx) {
    return shared_x[idx.z][idx.y][idx.x];
}

#define bfe(value, offset, bits) bitfieldExtract((value), (offset), (bits))

void main() {
    uvec3 lid = gl_LocalInvocationID;
    uvec3 wid = gl_WorkGroupID;
    uint lindex = gl_LocalInvocationIndex;
    
    cache_internal(wid, lid + uvec3(0, 0, 0));
    cache_internal(wid, lid + uvec3(8, 0, 0));
    cache_internal(wid, lid + uvec3(0, 8, 0));
    cache_internal(wid, lid + uvec3(8, 8, 0));
    cache_internal(wid, lid + uvec3(0, 0, 8));
    cache_internal(wid, lid + uvec3(8, 0, 8));
    cache_internal(wid, lid + uvec3(0, 8, 8));
    cache_internal(wid, lid + uvec3(8, 8, 8));

    {
        // Faces
        uvec3 lid = uvec3(
                    bfe(lindex, 0, 4), 
                    bfe(lindex, 4, 4), 
            -1 + 17*bfe(lindex, 8, 1)
        );
        cache_boundary(wid, lid.xyz); // Z-faces
        cache_boundary(wid, lid.xzy); // Y-faces
        cache_boundary(wid, lid.zxy); // X-faces
    }

    if (lindex < 3*64) {
        // Edges
        uvec3 lid = uvec3(
                    bfe(lindex, 0, 4), 
            -1 + 17*bfe(lindex, 4, 1), 
            -1 + 17*bfe(lindex, 5, 1)
        );
             if (lindex < 1*64) cache_boundary(wid, lid.xyz); // YZ-edges
        else if (lindex < 2*64) cache_boundary(wid, lid.yxz); // XZ-edges
        else if (lindex < 3*64) cache_boundary(wid, lid.yzx); // XY-edges
    } else if (lindex < 3*64 + 8) {
        // Corners
        uvec3 lid = uvec3(
            -1 + 17*bfe(lindex, 0, 1), 
            -1 + 17*bfe(lindex, 1, 1), 
            -1 + 17*bfe(lindex, 2, 1)
        );
        cache_boundary(wid, lid);
    }

    memoryBarrierShared();
    barrier();

    {
        uvec3 lid = uvec3(
              bitfieldExtract(lindex, 0, 4), 
              bitfieldExtract(lindex, 4, 4), 
            8*bitfieldExtract(lindex, 8, 1)
        );
        uvec3 index = 16*wid + lid;

        float x_mmm = decode2(1+lid+uvec3(-1, -1, -1));
        float x_pmm = decode2(1+lid+uvec3(+1, -1, -1));
        float x_mpm = decode2(1+lid+uvec3(-1, +1, -1));
        float x_ppm = decode2(1+lid+uvec3(+1, +1, -1));
        float x_m0m = decode2(1+lid+uvec3(-1, +0, -1));
        float x_p0m = decode2(1+lid+uvec3(+1, +0, -1));
        float x_0mm = decode2(1+lid+uvec3(+0, -1, -1));
        float x_0pm = decode2(1+lid+uvec3(+0, +1, -1));
        float x_00m = decode2(1+lid+uvec3(+0, +0, -1));

        float x_mm0 = decode2(1+lid+uvec3(-1, -1, +0));
        float x_pm0 = decode2(1+lid+uvec3(+1, -1, +0));
        float x_mp0 = decode2(1+lid+uvec3(-1, +1, +0));
        float x_pp0 = decode2(1+lid+uvec3(+1, +1, +0));
        float x_m00 = decode2(1+lid+uvec3(-1, +0, +0));
        float x_p00 = decode2(1+lid+uvec3(+1, +0, +0));
        float x_0m0 = decode2(1+lid+uvec3(+0, -1, +0));
        float x_0p0 = decode2(1+lid+uvec3(+0, +1, +0));
        float x_000 = decode2(1+lid+uvec3(+0, +0, +0));

        for (uint k = 0; k < 8; k++) {
            float b = texelFetch(u_divergence_texture, ivec3(index), 0).x;

            float x_mmp = decode2(1+lid+uvec3(-1, -1, +1));
            float x_pmp = decode2(1+lid+uvec3(+1, -1, +1));
            float x_mpp = decode2(1+lid+uvec3(-1, +1, +1));
            float x_ppp = decode2(1+lid+uvec3(+1, +1, +1));
            float x_m0p = decode2(1+lid+uvec3(-1, +0, +1));
            float x_p0p = decode2(1+lid+uvec3(+1, +0, +1));
            float x_0mp = decode2(1+lid+uvec3(+0, -1, +1));
            float x_0pp = decode2(1+lid+uvec3(+0, +1, +1));
            float x_00p = decode2(1+lid+uvec3(+0, +0, +1));

            float x = 16.0 * b;
            x += (3*x_ppp + x_pp0 + x_p0p + x_0pp - x_p00 - x_0p0 - x_00p);
            x += (3*x_ppm + x_pp0 + x_p0m + x_0pm - x_p00 - x_0p0 - x_00m);
            x += (3*x_pmp + x_pm0 + x_p0p + x_0mp - x_p00 - x_0m0 - x_00p);
            x += (3*x_pmm + x_pm0 + x_p0m + x_0mm - x_p00 - x_0m0 - x_00m);
            x += (3*x_mpp + x_mp0 + x_m0p + x_0pp - x_m00 - x_0p0 - x_00p);
            x += (3*x_mpm + x_mp0 + x_m0m + x_0pm - x_m00 - x_0p0 - x_00m);
            x += (3*x_mmp + x_mm0 + x_m0p + x_0mp - x_m00 - x_0m0 - x_00p);
            x += (3*x_mmm + x_mm0 + x_m0m + x_0mm - x_m00 - x_0m0 - x_00m);
            x /= 24.0;
            x = mix(x_000, x, u_omega);
            
            if (any(equal(index, uvec3(0)))) x = 0.0;
            imageStore(u_pressure_image, ivec3(index), vec4(x, 0.0, 0.0, 0.0));

            if (k < 7) {
                x_mmm = x_mm0;
                x_pmm = x_pm0;
                x_mpm = x_mp0;
                x_ppm = x_pp0;
                x_m0m = x_m00;
                x_p0m = x_p00;
                x_0mm = x_0m0;
                x_0pm = x_0p0;
                x_00m = x_000;

                x_mm0 = x_mmp;
                x_pm0 = x_pmp;
                x_mp0 = x_mpp;
                x_pp0 = x_ppp;
                x_m00 = x_m0p;
                x_p00 = x_p0p;
                x_0m0 = x_0mp;
                x_0p0 = x_0pp;
                x_000 = x_00p;

                lid.z += 1;
                index.z += 1;
            }
        }
    }
}