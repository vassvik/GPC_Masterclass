#version 460 core

// glDispatchCompute(u_size.x / 8, u_size.y / 8, u_size.z / 8)
layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(location = 0) uniform uvec3 u_size;

layout(binding = 0) uniform sampler3D u_tex;

layout(binding = 0) writeonly uniform image3D u_img;

shared float s_x[10][10][10];

void cache_internal(uvec3 wid, uvec3 lid) {
    uvec3 gid = 8*wid + lid;
    float x = texelFetch(u_tex, ivec3(gid), 0).x;
    s_x[1+lid.z][1+lid.y][1+lid.x] = x;
}

void cache_boundary(uvec3 wid, uvec3 lid) {
    uvec3 gid = 8*wid + lid;
    
    if (any(greaterThanEqual(gid, u_size))) {
        // two-sided out of bounds check
        s_x[1+lid.z][1+lid.y][1+lid.x] = 0.0;
        return;
    } 

    float x = texelFetch(u_tex, ivec3(gid), 0).x;
    s_x[1+lid.z][1+lid.y][1+lid.x] = x;
}

float fetch_from_cache(uvec3 lid) {
    return s_x[1+lid.z][1+lid.y][1+lid.x];
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

    if (tid < 3*128) 
    {
        // Faces
        uvec3 idx = uvec3(
                   bfe(tid, 0, 3), // idx.x:  [0, 8)
                   bfe(tid, 3, 3), // idx.y:  [0, 8)
            -1 + 9*bfe(tid, 6, 1)  // idx.z:  {-1, +8}
        );
             if (tid < 1*128) cache_boundary(wid, idx.xyz); // Z-faces (Blue)
        else if (tid < 2*128) cache_boundary(wid, idx.xzy); // Y-faces (Green)
        else if (tid < 3*128) cache_boundary(wid, idx.zxy); // X-faces (Red)
    } 
    else if (tid < 3*128 + 3*32) 
    {
        // Edges
        uvec3 idx = uvec3(
                   bfe(tid, 0, 3), // idx.x:  [0, 8)
            -1 + 9*bfe(tid, 3, 1), // idx.y:  {-1, +8}
            -1 + 9*bfe(tid, 4, 1)  // idx.z:  {-1, +8}
        );
             if (tid < 3*128 + 1*32) cache_boundary(wid, idx.xyz); // YZ-edges (Cyan)
        else if (tid < 3*128 + 2*32) cache_boundary(wid, idx.yxz); // XZ-edges (Magenta)
        else if (tid < 3*128 + 3*32) cache_boundary(wid, idx.yzx); // XY-edges (Yellow)
    } 
    else if (tid < 3*128 + 3*32 + 8) 
    {
        // Corners
        uvec3 idx = uvec3(
            -1 + 9*bfe(tid, 0, 1), // idx.x: {-1, +8}
            -1 + 9*bfe(tid, 1, 1), // idx.y: {-1, +8}
            -1 + 9*bfe(tid, 2, 1)  // idx.z: {-1, +8}
        );
        cache_boundary(wid, idx); // All corners (White)
    }

    memoryBarrierShared();
    barrier();

    float sum = 0.0;
    for (int k = -1; k <= +1; k++) {
        for (int j = -1; j <= +1; j++) {
            for (int i = -1; i <= +1; i++) {
                sum += fetch_from_cache(lid+uvec3(i, j, k));
            }
        }
    }

    imageStore(u_img, ivec3(8*wid + lid), vec4(sum / 27.0));
}

// https://shader-playground.timjones.io/1df1f94495218915a24d162a75d47311
//   sgpr_count(30)
//   vgpr_count(32)
// Maximum # VGPR used  30, VGPRs allocated by HW:  32 (30 requested)
// 
// Instructions: 298

