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

vec3 fetch_velocity(ivec3 gid) {
    float vx = texelFetch(u_velocity_x_texture, gid, 0).x;
    float vy = texelFetch(u_velocity_y_texture, gid, 0).x;
    float vz = texelFetch(u_velocity_z_texture, gid, 0).x;
    return vec3(vx, vy, vz);
}

void main() {
    if (u_compute_stats) {
        if (gl_LocalInvocationIndex < 32) {
            s_stats[gl_LocalInvocationIndex] = 0;
        }
        memoryBarrierShared();
        barrier();
    }
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    vec3 vENU = fetch_velocity(gid + ivec3( 0,  0,  0));
    vec3 vWNU = fetch_velocity(gid + ivec3(-1,  0,  0));
    vec3 vESU = fetch_velocity(gid + ivec3( 0, -1,  0));
    vec3 vWSU = fetch_velocity(gid + ivec3(-1, -1,  0));
    vec3 vEND = fetch_velocity(gid + ivec3( 0,  0, -1));
    vec3 vWND = fetch_velocity(gid + ivec3(-1,  0, -1));
    vec3 vESD = fetch_velocity(gid + ivec3( 0, -1, -1));
    vec3 vWSD = fetch_velocity(gid + ivec3(-1, -1, -1));

    float vE = 0.25 * (vENU.x + vESU.x + vEND.x + vESD.x);
    float vW = 0.25 * (vWNU.x + vWSU.x + vWND.x + vWSD.x);
    float vN = 0.25 * (vENU.y + vWNU.y + vEND.y + vWND.y);
    float vS = 0.25 * (vESU.y + vWSU.y + vESD.y + vWSD.y);
    float vU = 0.25 * (vENU.z + vWNU.z + vESU.z + vWSU.z);
    float vD = 0.25 * (vEND.z + vWND.z + vESD.z + vWSD.z);
    
    float divergence = (vE - vW) + (vN - vS) + (vU - vD);
    if (any(equal(gid, ivec3(0)))) divergence = 0.0;
    
    imageStore(u_divergence_image, gid, vec4(-divergence));

    if (u_compute_stats) {
        int bin = int(clamp(24 + log2(abs(divergence)), 0, 31));
        atomicAdd(s_stats[bin], 1);

        memoryBarrierShared();
        barrier();

        if (gl_LocalInvocationIndex < 32) {
            atomicAdd(b_stats[gl_LocalInvocationIndex], s_stats[gl_LocalInvocationIndex]);
        }
    }
}