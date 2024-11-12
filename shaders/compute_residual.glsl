#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform ivec3 u_size;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_divergence_texture;

layout(binding = 0) writeonly uniform image3D u_residual_image;

float fetch_pressure(ivec3 gid) {
    if (any(greaterThanEqual(uvec3(gid), uvec3(u_size)))) return 0.0;
    return texelFetch(u_pressure_texture, gid, 0).x;
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

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

    float r = 4.0 * divergence;
    r += p_ppp;
    r += p_ppm;
    r += p_pmp;
    r += p_pmm;
    r += p_mpp;
    r += p_mpm;
    r += p_mmp;
    r += p_mmm;
    r -= 8.0 * p_000;
    r /= 4.0;

    if (any(equal(gid, ivec3(0)))) r = 0.0;
    imageStore(u_residual_image, gid, vec4(r));
}