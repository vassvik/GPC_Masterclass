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

    float p_0  = fetch_pressure(gid + ivec3( 0,  0,  0));
    float p_xm = fetch_pressure(gid + ivec3(-1,  0,  0));
    float p_xp = fetch_pressure(gid + ivec3(+1,  0,  0));
    float p_ym = fetch_pressure(gid + ivec3( 0, -1,  0));
    float p_yp = fetch_pressure(gid + ivec3( 0, +1,  0));
    float p_zm = fetch_pressure(gid + ivec3( 0,  0, -1));
    float p_zp = fetch_pressure(gid + ivec3( 0,  0, +1));

    float r = divergence;
    r += p_xm;
    r += p_xp;
    r += p_ym;
    r += p_yp;
    r += p_zm;
    r += p_zp;
    r -= 6.0 * p_0;

    if (any(equal(gid, ivec3(0)))) r = 0.0;
    imageStore(u_residual_image, gid, vec4(r));
}