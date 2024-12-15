#version 460 core

// glDispatchCompute(u_size.x / 16, u_size.y / 16, u_size.z / 16)
layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(location = 0) uniform uvec3 u_size;

layout(binding = 0) uniform sampler3D u_tex;

layout(binding = 0) writeonly uniform image3D u_img;

shared float s_x[18][18][18];

void cache_internal(uvec3 wid, uvec3 lid) {
    uvec3 gid = 16*wid + lid;
    float x = texelFetch(u_tex, ivec3(gid), 0).x;
    s_x[1+lid.z][1+lid.y][1+lid.x] = x;
}

void cache_boundary(uvec3 wid, uvec3 lid) {
    uvec3 gid = 16*wid + lid;
    
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
        cache_internal(wid, lid + uvec3(0, 0, 0));
        cache_internal(wid, lid + uvec3(8, 0, 0));
        cache_internal(wid, lid + uvec3(0, 8, 0));
        cache_internal(wid, lid + uvec3(8, 8, 0));
        cache_internal(wid, lid + uvec3(0, 0, 8));
        cache_internal(wid, lid + uvec3(8, 0, 8));
        cache_internal(wid, lid + uvec3(0, 8, 8));
        cache_internal(wid, lid + uvec3(8, 8, 8));
    }

    {
        // Faces
        uvec3 idx = uvec3(
                    bfe(tid, 0, 4), // idx.x:  [0, 16)
                    bfe(tid, 4, 4), // idx.y:  [0, 16)
            -1 + 17*bfe(tid, 8, 1)  // idx.z:  {-1, +16}
        );
        cache_boundary(wid, idx.xyz); // Z-faces (Blue)
        cache_boundary(wid, idx.xzy); // Y-faces (Green)
        cache_boundary(wid, idx.zxy); // X-faces (Red)
    } 

    if (tid < 3*64) 
    {
        // Edges
        uvec3 idx = uvec3(
                    bfe(tid, 0, 4), // idx.x:  [0, 16)
            -1 + 17*bfe(tid, 4, 1), // idx.y:  {-1, +16}
            -1 + 17*bfe(tid, 5, 1)  // idx.z:  {-1, +16}
        );
             if (tid < 1*64) cache_boundary(wid, idx.xyz); // YZ-edges (Cyan)
        else if (tid < 2*64) cache_boundary(wid, idx.yxz); // XZ-edges (Magenta)
        else if (tid < 3*64) cache_boundary(wid, idx.yzx); // XY-edges (Yellow)
    } 
    else if (tid < 3*64 + 8) 
    {
        // Corners
        uvec3 idx = uvec3(
            -1 + 17*bfe(tid, 0, 1), // idx.x: {-1, +16}
            -1 + 17*bfe(tid, 1, 1), // idx.y: {-1, +16}
            -1 + 17*bfe(tid, 2, 1)  // idx.z: {-1, +16}
        );
        cache_boundary(wid, idx); // All corners (White)
    }

    memoryBarrierShared();
    barrier();

    for (uint K = 0; K < 2; K++) {
        for (uint J = 0; J < 2; J++) {
            for (uint I = 0; I < 2; I++) {
                uvec3 idx = lid + 8*uvec3(I, J, K);

                float sum = 0.0;
                for (int k = -1; k <= +1; k++) {
                    for (int j = -1; j <= +1; j++) {
                        for (int i = -1; i <= +1; i++) {
                            sum += fetch_from_cache(idx+uvec3(i, j, k));
                        }
                    }
                }

                imageStore(u_img, ivec3(16*wid + idx), vec4(sum / 27.0));
            }
        }
    }
}

// https://shader-playground.timjones.io/92a27a4308f6a5f475996a5681dbcff7
//   sgpr_count(22)
//   vgpr_count(24)
// Maximum # VGPR used  21, VGPRs allocated by HW:  32 (21 requested)
// 
// Instructions: 251