#version 460 core

<local_size>

// glDispatchCompute(u_size.x / 8, u_size.y / 8, u_size.z / 8)
//layout(local_size_x=4, local_size_y=4, local_size_z=4) in;

layout(location = 0) uniform uvec3 u_size;

layout(binding = 0) uniform sampler3D u_tex;

layout(binding = 0) writeonly uniform image3D u_img;

shared float s_x[12][12][12];

void cache_internal(uvec3 wid, uvec3 lid) {
    uvec3 gid = 8*wid + lid;
    float x = texelFetch(u_tex, ivec3(gid), 0).x;
    s_x[2+lid.z][2+lid.y][2+lid.x] = x;
}

void cache_boundary(uvec3 wid, uvec3 lid) {
    uvec3 gid = 8*wid + lid;
    
    if (any(greaterThanEqual(gid, u_size))) {
        // two-sided out of bounds check
        s_x[2+lid.z][2+lid.y][2+lid.x] = 0.0;
        return;
    } 

    float x = texelFetch(u_tex, ivec3(gid), 0).x;
    s_x[2+lid.z][2+lid.y][2+lid.x] = x;
}

float fetch_from_cache(uvec3 lid) {
    return s_x[2+lid.z][2+lid.y][2+lid.x];
}

#define bfe(v, o, b) bitfieldExtract((v), (o), (b))

void main() {
    uint tid = gl_LocalInvocationIndex; // [0, 64)
    uvec3 lid = gl_LocalInvocationID; // [0, 4) x [0, 4) x [0, 4)
    uvec3 wid = gl_WorkGroupID;         
    
    {
        // Internal (Gray)
        uvec3 idx = uvec3(
            bfe(tid, 0, 3), // idx.x:  [0, 8)
            bfe(tid, 3, 3), // idx.y:  [0, 8)
            0
        );
        cache_internal(wid, idx + uvec3(0, 0, 0));
        cache_internal(wid, idx + uvec3(0, 0, 1));
        cache_internal(wid, idx + uvec3(0, 0, 2));
        cache_internal(wid, idx + uvec3(0, 0, 3));
        cache_internal(wid, idx + uvec3(0, 0, 4));
        cache_internal(wid, idx + uvec3(0, 0, 5));
        cache_internal(wid, idx + uvec3(0, 0, 6));
        cache_internal(wid, idx + uvec3(0, 0, 7));
    }

    {
        // Faces
        uvec3 idx = uvec3(
            bfe(tid, 0, 3), // idx.x:  [0, 8)
            bfe(tid, 3, 3), // idx.y:  [0, 8)
            0
        );
        cache_boundary(wid, idx.xyz + uvec3( 0,  0, -2)); // Z-faces (Blue)
        cache_boundary(wid, idx.xyz + uvec3( 0,  0, -1)); // Z-faces (Blue)
        cache_boundary(wid, idx.xyz + uvec3( 0,  0, +8)); // Z-faces (Blue)
        cache_boundary(wid, idx.xyz + uvec3( 0,  0, +9)); // Z-faces (Blue)

        cache_boundary(wid, idx.xzy + uvec3( 0, -2,  0)); // Y-faces (Green)
        cache_boundary(wid, idx.xzy + uvec3( 0, -1,  0)); // Y-faces (Green)
        cache_boundary(wid, idx.xzy + uvec3( 0, +8,  0)); // Y-faces (Green)
        cache_boundary(wid, idx.xzy + uvec3( 0, +9,  0)); // Y-faces (Green)

        cache_boundary(wid, idx.zxy + uvec3(-2,  0,  0)); // X-faces (Red)
        cache_boundary(wid, idx.zxy + uvec3(-1,  0,  0)); // X-faces (Red)
        cache_boundary(wid, idx.zxy + uvec3(+8,  0,  0)); // X-faces (Red)
        cache_boundary(wid, idx.zxy + uvec3(+9,  0,  0)); // X-faces (Red)
    } 

    {   
        // Edges
        uvec3 idx = uvec3(
                   bfe(tid, 0, 3), // idx.x:  [0, 8)
                   bfe(tid, 3, 1), // idx.y:  [0, 2)
                   bfe(tid, 4, 1)  // idx.z:  [0, 2)
        );
        if (tid < 32) cache_boundary(wid, idx.xyz+uvec3( 0, -2, -2)); // YZ-edges (Cyan)
        else          cache_boundary(wid, idx.xyz+uvec3( 0, +8, -2)); // YZ-edges (Cyan)
        if (tid < 32) cache_boundary(wid, idx.xyz+uvec3( 0, -2, +8)); // YZ-edges (Cyan)
        else          cache_boundary(wid, idx.xyz+uvec3( 0, +8, +8)); // YZ-edges (Cyan)

        if (tid < 32) cache_boundary(wid, idx.yxz+uvec3(-2,  0, -2)); // XZ-edges (Magenta)
        else          cache_boundary(wid, idx.yxz+uvec3(+8,  0, -2)); // XZ-edges (Magenta)
        if (tid < 32) cache_boundary(wid, idx.yxz+uvec3(-2,  0, +8)); // XZ-edges (Magenta)
        else          cache_boundary(wid, idx.yxz+uvec3(+8,  0, +8)); // XZ-edges (Magenta)

        if (tid < 32) cache_boundary(wid, idx.yzx+uvec3(-2, -2,  0)); // XY-edges (Yellow)
        else          cache_boundary(wid, idx.yzx+uvec3(+8, -2,  0)); // XY-edges (Yellow)
        if (tid < 32) cache_boundary(wid, idx.yzx+uvec3(-2, +8,  0)); // XY-edges (Yellow)
        else          cache_boundary(wid, idx.yzx+uvec3(+8, +8,  0)); // XY-edges (Yellow)
    } 
    {
        // Corners
        uvec3 idx1 = uvec3(
            bfe(tid, 0, 1), // idx.x: [0, 2)
            bfe(tid, 1, 1), // idx.y: [0, 2)
            bfe(tid, 2, 1)  // idx.z: [0, 2)
        );
        uvec3 idx2 = uvec3(
            bfe(tid, 3, 1), // idx.x: [0, 2)
            bfe(tid, 4, 1), // idx.y: [0, 2)
            bfe(tid, 5, 1)  // idx.z: [0, 2)
        );
        cache_boundary(wid, -2 + idx1 + 10*idx2); // All corners (White)
    }

    memoryBarrierShared();
    barrier();

    {
        uvec3 idx = uvec3(
              bfe(tid, 0, 3), // idx.x: [0, 8)
              bfe(tid, 3, 3), // idx.y: [0, 8)
              0
        );        

        float sum_bottom = 0.0;
        float sum_middle = 0.0;
        for (int j = -1; j <= +1; j++) {
            for (int i = -1; i <= +1; i++) {
                sum_bottom += fetch_from_cache(idx+uvec3(i, j, -1));
                sum_middle += fetch_from_cache(idx+uvec3(i, j,  0));
            }
        }

        for (int K = 0; K < 8; K++) {
            float sum_top = 0.0;
            for (int j = -1; j <= +1; j++) {
                for (int i = -1; i <= +1; i++) {
                    sum_top  += fetch_from_cache(idx+uvec3(i, j, +1));
                }
            }

            float sum = sum_bottom + sum_middle + sum_top;
            imageStore(u_img, ivec3(8*wid + idx), vec4(sum / 27.0));
            sum_bottom = sum_middle;
            sum_middle = sum_top;
            idx.z += 1;
        }
    }
}

// https://shader-playground.timjones.io/92a27a4308f6a5f475996a5681dbcff7
//   sgpr_count(22)
//   vgpr_count(24)
// Maximum # VGPR used  21, VGPRs allocated by HW:  32 (21 requested)
// 
// Instructions: 251