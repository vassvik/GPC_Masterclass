#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout (std430, binding = 0) buffer Stats {
    int b_stats[];
};

layout(binding = 0) uniform sampler3D u_velocity_x_texture;
layout(binding = 1) uniform sampler3D u_velocity_y_texture;
layout(binding = 2) uniform sampler3D u_velocity_z_texture;

layout(binding = 0) writeonly uniform image3D u_divergence_image;

layout(location=0) uniform bool u_compute_stats;

shared int s_stats[32];

shared uvec2 s_v[17][17][17];

uvec2 fetch_and_encode(ivec3 gid) {
    float vx = texelFetch(u_velocity_x_texture, gid, 0).x;
    float vy = texelFetch(u_velocity_y_texture, gid, 0).x;
    float vz = texelFetch(u_velocity_z_texture, gid, 0).x;
    return uvec2(packHalf2x16(vec2(vx, vy)), packHalf2x16(vec2(vz, 0.0)));
}

vec3 decode(ivec3 idx) {
    uvec2 u = s_v[idx.z][idx.y][idx.x];
    return vec3(unpackHalf2x16(u.x), unpackHalf2x16(u.y).x);
}

void main() {
    if (u_compute_stats) {
        if (gl_LocalInvocationIndex < 32) {
            s_stats[gl_LocalInvocationIndex] = 0;
        }
        memoryBarrierShared();
        barrier();
    }
    
    ivec3 lid = ivec3(gl_LocalInvocationID);
    ivec3 wid = ivec3(gl_WorkGroupID);
    int lindex = int(gl_LocalInvocationIndex);

    s_v[1+lid.z+0][1+lid.y+0][1+lid.x+0] = fetch_and_encode(16*wid + lid + ivec3(0, 0, 0));
    s_v[1+lid.z+0][1+lid.y+0][1+lid.x+8] = fetch_and_encode(16*wid + lid + ivec3(8, 0, 0));
    s_v[1+lid.z+0][1+lid.y+8][1+lid.x+0] = fetch_and_encode(16*wid + lid + ivec3(0, 8, 0));
    s_v[1+lid.z+0][1+lid.y+8][1+lid.x+8] = fetch_and_encode(16*wid + lid + ivec3(8, 8, 0));
    s_v[1+lid.z+8][1+lid.y+0][1+lid.x+0] = fetch_and_encode(16*wid + lid + ivec3(0, 0, 8));
    s_v[1+lid.z+8][1+lid.y+0][1+lid.x+8] = fetch_and_encode(16*wid + lid + ivec3(8, 0, 8));
    s_v[1+lid.z+8][1+lid.y+8][1+lid.x+0] = fetch_and_encode(16*wid + lid + ivec3(0, 8, 8));
    s_v[1+lid.z+8][1+lid.y+8][1+lid.x+8] = fetch_and_encode(16*wid + lid + ivec3(8, 8, 8));

    if (lindex < 256)  {
        ivec2 lid = ivec2(lindex % 16, lindex / 16);
        s_v[1+lid.y][0][1+lid.x] = fetch_and_encode(16*wid + ivec3(lid.x, -1, lid.y));
        s_v[1+lid.y][1+lid.x][0] = fetch_and_encode(16*wid + ivec3(-1, lid.x, lid.y));
    } else {
        ivec2 lid = ivec2(lindex % 16, (lindex / 16) - 16);
        s_v[0][1+lid.y][1+lid.x] = fetch_and_encode(16*wid + ivec3(lid.x, lid.y, -1));

        if (lindex < 256 + 1*64) {
            if (lindex < 256 + 0*64 + 16) {
                int lid = lindex % 16;
                s_v[1+lid][0][0] = fetch_and_encode(16*wid + ivec3(-1, -1, lid));
            }
        } else if (lindex < 256 + 2*64) {
            if (lindex < 256 + 1*64 + 16) {
                int lid = lindex % 16;
                s_v[0][1+lid][0] = fetch_and_encode(16*wid + ivec3(-1, lid, -1));
            }
        } else if (lindex < 256 + 3*64) {
            if (lindex < 256 + 2*64 + 16) {
                int lid = lindex % 16;
                s_v[0][0][1+lid] = fetch_and_encode(16*wid + ivec3(lid, -1, -1));
            }
        } else if (lindex < 256 + 4*64) {
            if (lindex < 256 + 3*64 + 1) {
                s_v[0][0][0] = fetch_and_encode(16*wid + ivec3(-1, -1, -1));
            }
        }
    }

    memoryBarrierShared();
    barrier();

    for (int k = 0; k < 2; k++) for (int j = 0; j < 2; j++) for (int i = 0; i < 2; i++) {
        ivec3 lid = lid + 8*ivec3(i, j, k);
        ivec3 index = 16*wid + lid;

        vec3 vENU = decode(1 + lid + ivec3( 0,  0,  0));
        vec3 vWNU = decode(1 + lid + ivec3(-1,  0,  0));
        vec3 vESU = decode(1 + lid + ivec3( 0, -1,  0));
        vec3 vWSU = decode(1 + lid + ivec3(-1, -1,  0));
        vec3 vEND = decode(1 + lid + ivec3( 0,  0, -1));
        vec3 vWND = decode(1 + lid + ivec3(-1,  0, -1));
        vec3 vESD = decode(1 + lid + ivec3( 0, -1, -1));
        vec3 vWSD = decode(1 + lid + ivec3(-1, -1, -1));

        float vE = 0.25 * (vENU.x + vESU.x + vEND.x + vESD.x);
        float vW = 0.25 * (vWNU.x + vWSU.x + vWND.x + vWSD.x);
        float vN = 0.25 * (vENU.y + vWNU.y + vEND.y + vWND.y);
        float vS = 0.25 * (vESU.y + vWSU.y + vESD.y + vWSD.y);
        float vU = 0.25 * (vENU.z + vWNU.z + vESU.z + vWSU.z);
        float vD = 0.25 * (vEND.z + vWND.z + vESD.z + vWSD.z);
        
        float divergence = (vE - vW) + (vN - vS) + (vU - vD);
        if (any(equal(index, ivec3(0)))) divergence = 0.0;

        imageStore(u_divergence_image, index, vec4(-divergence, 0.0, 0.0, 0.0));
        
        if (u_compute_stats) {
            int bin = int(clamp(24 + log2(abs(divergence)), 0, 31));
            atomicAdd(s_stats[bin], 1);
        }
    }
    
    if (u_compute_stats) {
        memoryBarrierShared();
        barrier();

        if (gl_LocalInvocationIndex < 32) {
            atomicAdd(b_stats[gl_LocalInvocationIndex], s_stats[gl_LocalInvocationIndex]);
        }
    }
}