#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) uniform sampler3D u_smoke_texture;
layout(binding = 1) uniform sampler3D u_velocity_z_texture;

layout(binding = 0) writeonly uniform image3D u_velocity_z_image;

layout(location = 0) uniform float u_smoke_weight;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float s0 = texelFetch(u_smoke_texture, gid + ivec3(0, 0, 0), 0).x;
    float s1 = texelFetch(u_smoke_texture, gid + ivec3(0, 0, 1), 0).x;
    float s = (s0 + s1) / 2.0;

    float vz = texelFetch(u_velocity_z_texture, gid + ivec3(0, 0, 0), 0).x;
    vz += s * u_smoke_weight;

    if (gid.x == 0 || gid.y == 0) vz = 0.0;
    imageStore(u_velocity_z_image, gid, vec4(vz, 0, 0, 0));
}