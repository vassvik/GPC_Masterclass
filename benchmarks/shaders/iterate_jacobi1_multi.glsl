#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform uvec3 u_size;

layout(binding = 0) uniform sampler3D u_lhs_texture;
layout(binding = 1) uniform sampler3D u_rhs_texture;

layout(binding = 0) writeonly uniform image3D u_lhs_image;

#define MODE <mode>

#define MODE__8__8__8 0
#define MODE_16__8__8 1
#define MODE__8_16__8 2
#define MODE_16_16__8 3
#define MODE__8__8_16 4
#define MODE_16__8_16 5
#define MODE__8_16_16 6
#define MODE_16_16_16 7

#define WORK_SIZE_X (8+((MODE&1)<<3))
#define WORK_SIZE_Y (8+((MODE&2)<<2))
#define WORK_SIZE_Z (8+((MODE&4)<<1))
#define WORK_SIZE uvec3(WORK_SIZE_X, WORK_SIZE_Y, WORK_SIZE_Z)

#define NUM_PASSES_X (WORK_SIZE_X/8)
#define NUM_PASSES_Y (WORK_SIZE_Y/8)
#define NUM_PASSES_Z (WORK_SIZE_Z/8)

shared float s_cache[2+WORK_SIZE_Z][2+WORK_SIZE_Y][2+WORK_SIZE_X];

void cache(uvec3 anchor, uvec3 lid, bool oob) {
    float x = texelFetch(u_lhs_texture, ivec3(anchor + lid), 0).x;
    if (oob) x = 0.0;
    s_cache[1+lid.z][1+lid.y][1+lid.x] = x;
}

#define bfe(x, a, b) bitfieldExtract(x, a, b)

void main() {
    uvec3 wid = gl_WorkGroupID;
    uvec3 anchor = WORK_SIZE*wid;

    uvec3 lid0 = gl_LocalInvocationID;
    uint lindex = gl_LocalInvocationIndex;


    for (uint k = 0; k < NUM_PASSES_Z; k++) for (uint j = 0; j < NUM_PASSES_Y; j++) for (uint i = 0; i < NUM_PASSES_X; i++) {
        cache(anchor, uvec3(i, j, k)*8 + lid0, false);
    }

    {
        // XY
        uvec3 lid = uvec3(lid0.x, lid0.y, -1+(WORK_SIZE_Z+1)*(lid0.z%2)).xyz;
        for (uint j = 0; j < NUM_PASSES_Y; j++) for (uint i = 0; i < NUM_PASSES_X; i++) {
            uint start = (j*NUM_PASSES_X+i)*(2*64);
            if ((lindex - (start%512)) < 2*64) {
                cache(anchor, uvec3(i, j, 0)*8 + lid, anchor.z+lid.z >= u_size.z);
            }
        }
    }
    {
        // XZ
        uvec3 lid = uvec3(lid0.x, lid0.y, -1+(WORK_SIZE_Y+1)*(lid0.z%2)).xzy;
        for (uint k = 0; k < NUM_PASSES_Z; k++) for (uint i = 0; i < NUM_PASSES_X; i++) {
            uint start = (k*NUM_PASSES_X+i)*(2*64);
            start += NUM_PASSES_X*NUM_PASSES_Y*(2*64);
            if ((lindex - (start%512)) < 2*64) {
                cache(anchor, uvec3(i, 0, k)*8 + lid, anchor.y+lid.y >= u_size.y);
            }
        }
    }
    {
        // YZ
        uvec3 lid = uvec3(lid0.x, lid0.y, -1+(WORK_SIZE_X+1)*(lid0.z%2)).zxy;
        for (uint k = 0; k < NUM_PASSES_Z; k++) for (uint j = 0; j < NUM_PASSES_Y; j++) {
            uint start = (k*NUM_PASSES_Y+j)*(2*64);
            start += NUM_PASSES_X*NUM_PASSES_Y*(2*64);
            start += NUM_PASSES_X*NUM_PASSES_Z*(2*64);
            if ((lindex - (start%512)) < 2*64) {
                cache(anchor, uvec3(0, j, k)*8 + lid, anchor.x+lid.x >= u_size.x);
            }
        }
    }

    memoryBarrierShared();
    barrier();

    for (uint k = 0; k < NUM_PASSES_Z; k++)
    for (uint j = 0; j < NUM_PASSES_Y; j++)
    for (uint i = 0; i < NUM_PASSES_X; i++) {

        uvec3 lid = lid0 + 8*uvec3(i, j, k);

        float b = texelFetch(u_rhs_texture, ivec3(anchor + lid), 0).x;

        float xW = s_cache[1+lid.z][1+lid.y][1+lid.x-1];
        float xE = s_cache[1+lid.z][1+lid.y][1+lid.x+1];
        float xS = s_cache[1+lid.z][1+lid.y-1][1+lid.x];
        float xN = s_cache[1+lid.z][1+lid.y+1][1+lid.x];
        float xD = s_cache[1+lid.z-1][1+lid.y][1+lid.x];
        float xU = s_cache[1+lid.z+1][1+lid.y][1+lid.x];

        float x = (b + xW + xE + xS + xN + xD + xU) / 6.0;
        imageStore(u_lhs_image, ivec3(anchor + lid), vec4(x));
    }
}
