#version 460 core

layout(local_size_x = 4, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform ivec3 u_size;
layout(location = 1) uniform float u_omega;
layout(location = 2) uniform int u_offset;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_divergence_texture;

layout(binding = 0) writeonly uniform image3D u_pressure_image;

float fetch_pressure(ivec3 gid) {
    if (any(greaterThanEqual(uvec3(gid), uvec3(u_size)))) return 0.0;
    return texelFetch(u_pressure_texture, gid, 0).x;
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    gid.x = 2*gid.x + u_offset;

    float divergence = texelFetch(u_divergence_texture, gid, 0).x;

    float p_mmm = fetch_pressure(gid + ivec3(-1, -1, -1));
    float p_pmm = fetch_pressure(gid + ivec3(+1, -1, -1));
    float p_mpm = fetch_pressure(gid + ivec3(-1, +1, -1));
    float p_ppm = fetch_pressure(gid + ivec3(+1, +1, -1));
    float p_000 = fetch_pressure(gid + ivec3( 0,  0,  0));
    float p_mmp = fetch_pressure(gid + ivec3(-1, -1, +1));
    float p_pmp = fetch_pressure(gid + ivec3(+1, -1, +1));
    float p_mpp = fetch_pressure(gid + ivec3(-1, +1, +1));
    float p_ppp = fetch_pressure(gid + ivec3(+1, +1, +1));

    float p = 4.0 * divergence;
    p += p_ppp;
    p += p_ppm;
    p += p_pmp;
    p += p_pmm;
    p += p_mpp;
    p += p_mpm;
    p += p_mmp;
    p += p_mmm;
    p /= 8.0;

    p = mix(p_000, p, u_omega);

    if (any(equal(gid, ivec3(0)))) p = 0.0;
    imageStore(u_pressure_image, gid, vec4(p));
}