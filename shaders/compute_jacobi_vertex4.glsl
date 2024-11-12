#version 460 core

layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(location = 0) uniform uvec3 u_size;
layout(location = 1) uniform float u_omega;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_divergence_texture;

layout(binding = 0) writeonly uniform image3D u_pressure_image;

shared float s_p[10][10][10];

float fetch_from_cache(uvec3 lid) {
    return s_p[1+lid.z][1+lid.y][1+lid.x];
}

void cache_internal(uvec3 wid, uvec3 lid) {
    uvec3 gid = 8*wid + lid;
    float p = texelFetch(u_pressure_texture, ivec3(gid), 0).x;
    s_p[1+lid.z][1+lid.y][1+lid.x] = p;
}

void cache_boundary(uvec3 wid, uvec3 lid) {
    uvec3 gid = 8*wid + lid;
    
    if (any(greaterThanEqual(gid, u_size))) {
        // two-sided out of bounds check
        s_p[1+lid.z][1+lid.y][1+lid.x] = 0.0;
        return;
    } 

    float p = texelFetch(u_pressure_texture, ivec3(gid), 0).x;
    s_p[1+lid.z][1+lid.y][1+lid.x] = p;
}

#define bfe(v, o, b) bitfieldExtract((v), (o), (b))

void main() {
    uint tid = gl_LocalInvocationIndex; // [0, 512)
    uvec3 lid = gl_LocalInvocationID; // [0, 8) x [0, 8) x [0, 8)
    uvec3 wid = gl_WorkGroupID;         
    
    {
        // Internal (Gray)
        cache_internal(wid, lid);
    }

    if (tid < 3*128) {
        uvec3 idx = uvec3(
                   bfe(tid, 0, 3), // idx.x:  [0, 8)
                   bfe(tid, 3, 3), // idx.y:  [0, 8)
            -1 + 9*bfe(tid, 6, 1)  // idx.z:  {-1, +9}
        );
             if (tid < 1*128) cache_boundary(wid, idx.xyz); // Z-faces (Blue)
        else if (tid < 2*128) cache_boundary(wid, idx.xzy); // Y-faces (Green)
        else if (tid < 3*128) cache_boundary(wid, idx.zxy); // X-faces (Red)
    } else if (tid < 3*128 + 3*32) {
        // Edges
        uvec3 idx = uvec3(
                   bfe(tid, 0, 3), // idx.x:  [0, 8)
            -1 + 9*bfe(tid, 3, 1), // idx.y:  {-1, +9}
            -1 + 9*bfe(tid, 4, 1)  // idx.z:  {-1, +9}
        );
             if (tid < 3*128 + 1*32) cache_boundary(wid, idx.xyz); // YZ-edges (Cyan)
        else if (tid < 3*128 + 2*32) cache_boundary(wid, idx.yxz); // XZ-edges (Magenta)
        else if (tid < 3*128 + 3*32) cache_boundary(wid, idx.yzx); // XY-edges (Yellow)
    } else if (tid < 3*128 + 3*32 + 8) {
        // Corners
        uvec3 idx = uvec3(
            -1 + 9*bfe(tid, 0, 1), // idx.x: {-1, +9}
            -1 + 9*bfe(tid, 1, 1), // idx.y: {-1, +9}
            -1 + 9*bfe(tid, 2, 1)  // idx.z: {-1, +9}
        );
        cache_boundary(wid, idx); // Corners (White)
    }

    memoryBarrierShared();
    barrier();

    {
        uvec3 gid = 8*wid + lid;

        float divergence = texelFetch(u_divergence_texture, ivec3(gid), 0).x;

        float p_mmm = fetch_from_cache(lid + uvec3(-1, -1, -1));
        float p_pmm = fetch_from_cache(lid + uvec3(+1, -1, -1));
        float p_mpm = fetch_from_cache(lid + uvec3(-1, +1, -1));
        float p_ppm = fetch_from_cache(lid + uvec3(+1, +1, -1));
        float p_mmp = fetch_from_cache(lid + uvec3(-1, -1, +1));
        float p_pmp = fetch_from_cache(lid + uvec3(+1, -1, +1));
        float p_mpp = fetch_from_cache(lid + uvec3(-1, +1, +1));
        float p_ppp = fetch_from_cache(lid + uvec3(+1, +1, +1));
        float pC = p_mmm + p_pmm + p_mpm + p_ppm + p_mmp + p_pmp + p_mpp + p_ppp;

        float p_0mm = fetch_from_cache(lid + uvec3( 0, -1, -1));
        float p_0pm = fetch_from_cache(lid + uvec3( 0, +1, -1));
        float p_0mp = fetch_from_cache(lid + uvec3( 0, -1, +1));
        float p_0pp = fetch_from_cache(lid + uvec3( 0, +1, +1));
        float p_m0m = fetch_from_cache(lid + uvec3(-1,  0, -1));
        float p_p0m = fetch_from_cache(lid + uvec3(+1,  0, -1));
        float p_m0p = fetch_from_cache(lid + uvec3(-1,  0, +1));
        float p_p0p = fetch_from_cache(lid + uvec3(+1,  0, +1));
        float p_mm0 = fetch_from_cache(lid + uvec3(-1, -1,  0));
        float p_pm0 = fetch_from_cache(lid + uvec3(+1, -1,  0));
        float p_mp0 = fetch_from_cache(lid + uvec3(-1, +1,  0));
        float p_pp0 = fetch_from_cache(lid + uvec3(+1, +1,  0));
        float pE = p_0mm + p_0pm + p_0mp + p_0pp + p_m0m + p_p0m + p_m0p + p_p0p + p_mm0 + p_pm0 + p_mp0 + p_pp0;

        float p_00m = fetch_from_cache(lid + uvec3( 0,  0, -1));
        float p_0m0 = fetch_from_cache(lid + uvec3( 0, -1,  0));
        float p_m00 = fetch_from_cache(lid + uvec3(-1,  0,  0));
        float p_p00 = fetch_from_cache(lid + uvec3(+1,  0,  0));
        float p_0p0 = fetch_from_cache(lid + uvec3( 0, +1,  0));
        float p_00p = fetch_from_cache(lid + uvec3( 0,  0, +1));
        float pF = p_00m + p_0m0 + p_m00 + p_p00 + p_0p0 + p_00p;

        float p_000 = fetch_from_cache(lid + uvec3( 0,  0,  0));

        float p = (16.0 * divergence + 3*pC + 2*pE - 4*pF) / 24.0;
        p = mix(p_000, p, u_omega);

        if (any(equal(gid, uvec3(0)))) p = 0.0;
        imageStore(u_pressure_image, ivec3(gid), vec4(p));
    }
}