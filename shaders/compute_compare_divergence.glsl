#version 460 core

layout(local_size_x = 16, local_size_y = 8, local_size_z = 8) in;

layout (std430, binding = 0) buffer Stats {
    int b_stats[];
};

layout(binding = 0) uniform sampler3D u_divergence_texture1;
layout(binding = 1) uniform sampler3D u_divergence_texture2;
layout(binding = 2) uniform sampler3D u_velocity_x_texture;
layout(binding = 3) uniform sampler3D u_velocity_y_texture;
layout(binding = 4) uniform sampler3D u_velocity_z_texture;

shared int s_stats[2*32*32];

void main() {
    s_stats[gl_LocalInvocationIndex] = 0;
    s_stats[32*32+gl_LocalInvocationIndex] = 0;
    memoryBarrierShared();
    barrier();

    ivec3 gid = ivec3(gl_GlobalInvocationID);
    float divergence1 = texelFetch(u_divergence_texture1, gid, 0).x;
    float divergence2 = texelFetch(u_divergence_texture2, gid, 0).x;

    float vx = texture(u_velocity_x_texture, (gid + 0.0) / textureSize(u_velocity_x_texture, 0)).x;
    float vy = texture(u_velocity_y_texture, (gid + 0.0) / textureSize(u_velocity_y_texture, 0)).x;
    float vz = texture(u_velocity_z_texture, (gid + 0.0) / textureSize(u_velocity_z_texture, 0)).x;
    float v = length(vec3(vx, vy, vz));

    if (all(notEqual(gid, ivec3(0)))) {
        int bin1 = int(clamp(24 + log2(abs(divergence1)), 0, 31));
        int bin2 = int(clamp(24 + log2(abs(divergence2)), 0, 31));
        int bin3 = int(clamp(24 + log2(abs(v)), 0, 31));

        atomicAdd(s_stats[32*bin1+bin2], 1);
        atomicAdd(s_stats[32*32+32*bin3+bin2], 1);
    }

    memoryBarrierShared();
    barrier();

    atomicAdd(b_stats[gl_LocalInvocationIndex], s_stats[gl_LocalInvocationIndex]);
    atomicAdd(b_stats[32*32+gl_LocalInvocationIndex], s_stats[32*32+gl_LocalInvocationIndex]);
}