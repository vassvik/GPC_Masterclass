#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform ivec3 u_size;
layout(location = 1) uniform float u_omega;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_divergence_texture;

layout(binding = 0) writeonly uniform image3D u_pressure_image;

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
    float p_mmp = fetch_pressure(gid + ivec3(-1, -1, +1));
    float p_pmp = fetch_pressure(gid + ivec3(+1, -1, +1));
    float p_mpp = fetch_pressure(gid + ivec3(-1, +1, +1));
    float p_ppp = fetch_pressure(gid + ivec3(+1, +1, +1));
    float pC = p_mmm + p_pmm + p_mpm + p_ppm + p_mmp + p_pmp + p_mpp + p_ppp;

    float p_0mm = fetch_pressure(gid + ivec3( 0, -1, -1));
    float p_0pm = fetch_pressure(gid + ivec3( 0, +1, -1));
    float p_0mp = fetch_pressure(gid + ivec3( 0, -1, +1));
    float p_0pp = fetch_pressure(gid + ivec3( 0, +1, +1));
    float p_m0m = fetch_pressure(gid + ivec3(-1,  0, -1));
    float p_p0m = fetch_pressure(gid + ivec3(+1,  0, -1));
    float p_m0p = fetch_pressure(gid + ivec3(-1,  0, +1));
    float p_p0p = fetch_pressure(gid + ivec3(+1,  0, +1));
    float p_mm0 = fetch_pressure(gid + ivec3(-1, -1,  0));
    float p_pm0 = fetch_pressure(gid + ivec3(+1, -1,  0));
    float p_mp0 = fetch_pressure(gid + ivec3(-1, +1,  0));
    float p_pp0 = fetch_pressure(gid + ivec3(+1, +1,  0));
    float pE = p_0mm + p_0pm + p_0mp + p_0pp + p_m0m + p_p0m + p_m0p + p_p0p + p_mm0 + p_pm0 + p_mp0 + p_pp0;

    float p_00m = fetch_pressure(gid + ivec3( 0,  0, -1));
    float p_0m0 = fetch_pressure(gid + ivec3( 0, -1,  0));
    float p_m00 = fetch_pressure(gid + ivec3(-1,  0,  0));
    float p_p00 = fetch_pressure(gid + ivec3(+1,  0,  0));
    float p_0p0 = fetch_pressure(gid + ivec3( 0, +1,  0));
    float p_00p = fetch_pressure(gid + ivec3( 0,  0, +1));
    float pF = p_00m + p_0m0 + p_m00 + p_p00 + p_0p0 + p_00p;

    float p_000 = fetch_pressure(gid + ivec3( 0,  0,  0));

    float p = (16.0 * divergence + 3*pC + 2*pE - 4*pF) / 24.0;
    p = mix(p_000, p, u_omega);

    if (any(equal(gid, ivec3(0)))) p = 0.0;
    imageStore(u_pressure_image, gid, vec4(p));
}