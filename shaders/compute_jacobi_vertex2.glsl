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

float fetch_from_cache(uvec3 idx) {
    return shared_x[1+idx.z][1+idx.y][1+idx.x];
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

    for (uint k = 0; k < 2; k++) for (uint j = 0; j < 2; j++) for (uint i = 0; i < 2; i++) {
        uvec3 lid = lid + 8*uvec3(i, j, k);
        uvec3 gid = 16*wid + lid;

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