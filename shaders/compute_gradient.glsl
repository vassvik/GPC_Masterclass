#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_velocity_x_texture;
layout(binding = 2) uniform sampler3D u_velocity_y_texture;
layout(binding = 3) uniform sampler3D u_velocity_z_texture;

layout(binding = 0) writeonly uniform image3D u_velocity_x_image;
layout(binding = 1) writeonly uniform image3D u_velocity_y_image;
layout(binding = 2) writeonly uniform image3D u_velocity_z_image;

layout(location = 0) uniform ivec3 u_size;

float fetch_pressure(ivec3 gid) {
    if (any(greaterThanEqual(uvec3(gid), uvec3(u_size)))) return 0.0;
    return texelFetch(u_pressure_texture, gid, 0).x;
}

vec3 fetch_velocity(ivec3 gid) {
    float vx = texelFetch(u_velocity_x_texture, gid, 0).x;
    float vy = texelFetch(u_velocity_y_texture, gid, 0).x;
    float vz = texelFetch(u_velocity_z_texture, gid, 0).x;
    return vec3(vx, vy, vz);
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float p_000 = fetch_pressure(gid + ivec3( 0,  0,  0));
    float p_100 = fetch_pressure(gid + ivec3(+1,  0,  0));
    float p_010 = fetch_pressure(gid + ivec3( 0, +1,  0));
    float p_110 = fetch_pressure(gid + ivec3(+1, +1,  0));
    float p_001 = fetch_pressure(gid + ivec3( 0,  0, +1));
    float p_101 = fetch_pressure(gid + ivec3(+1,  0, +1));
    float p_011 = fetch_pressure(gid + ivec3( 0, +1, +1));
    float p_111 = fetch_pressure(gid + ivec3(+1, +1, +1));

    float pW = 0.25 * (p_000 + p_010 + p_001 + p_011);
    float pE = 0.25 * (p_100 + p_110 + p_101 + p_111);
    float pS = 0.25 * (p_000 + p_100 + p_001 + p_101);
    float pN = 0.25 * (p_010 + p_110 + p_011 + p_111);
    float pD = 0.25 * (p_000 + p_100 + p_010 + p_110);
    float pU = 0.25 * (p_001 + p_101 + p_011 + p_111);

    vec3 v = fetch_velocity(gid) - vec3(pE - pW, pN - pS, pU - pD);

    imageStore(u_velocity_x_image, gid, vec4(v.x));
    imageStore(u_velocity_y_image, gid, vec4(v.y));
    imageStore(u_velocity_z_image, gid, vec4(v.z));
}