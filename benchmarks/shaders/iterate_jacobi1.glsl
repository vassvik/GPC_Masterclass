#version 460 core

<local_size>

layout(location = 0) uniform uvec3 u_size;

layout(binding = 0) uniform sampler3D u_lhs_texture;
layout(binding = 1) uniform sampler3D u_rhs_texture;

layout(binding = 0) writeonly uniform image3D u_lhs_image;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float b = texelFetch(u_rhs_texture, gid, 0).x;

    float xW = texelFetchOffset(u_lhs_texture, gid, 0, ivec3(-1,  0,  0)).x;
    float xE = texelFetchOffset(u_lhs_texture, gid, 0, ivec3(+1,  0,  0)).x;
    float xS = texelFetchOffset(u_lhs_texture, gid, 0, ivec3( 0, -1,  0)).x;
    float xN = texelFetchOffset(u_lhs_texture, gid, 0, ivec3( 0, +1,  0)).x;
    float xD = texelFetchOffset(u_lhs_texture, gid, 0, ivec3( 0,  0, -1)).x;
    float xU = texelFetchOffset(u_lhs_texture, gid, 0, ivec3( 0,  0, +1)).x;
    if (uint(gid.x-1) >= u_size.x) xW = 0.0;
    if (uint(gid.x+1) >= u_size.x) xE = 0.0;
    if (uint(gid.y-1) >= u_size.y) xS = 0.0;
    if (uint(gid.y+1) >= u_size.y) xN = 0.0;
    if (uint(gid.z-1) >= u_size.z) xD = 0.0;
    if (uint(gid.z+1) >= u_size.z) xU = 0.0;

    float x = (b + xW + xE + xS + xN + xD + xU) / 6.0;
    imageStore(u_lhs_image, gid, vec4(x));
}
