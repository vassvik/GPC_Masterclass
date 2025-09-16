#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) uniform sampler3D u_velocity_x_texture;
layout(binding = 1) uniform sampler3D u_velocity_y_texture;
layout(binding = 2) uniform sampler3D u_velocity_z_texture;

layout(binding = 0) writeonly uniform image3D u_divergence_image;

layout(location=0) uniform bool u_compute_stats;

shared int s_stats[32];

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float vxm = texelFetch(u_velocity_x_texture, gid + ivec3(-1,  0,  0), 0).x;
    float vxp = texelFetch(u_velocity_x_texture, gid + ivec3( 0,  0,  0), 0).x;

    float vym = texelFetch(u_velocity_y_texture, gid + ivec3( 0, -1,  0), 0).x;
    float vyp = texelFetch(u_velocity_y_texture, gid + ivec3( 0,  0,  0), 0).x;

    float vzm = texelFetch(u_velocity_z_texture, gid + ivec3( 0,  0, -1), 0).x;
    float vzp = texelFetch(u_velocity_z_texture, gid + ivec3( 0,  0,  0), 0).x;
    
    float divergence = (vxp - vxm) + (vyp - vym) + (vzp - vzm);
    if (any(equal(gid, ivec3(0)))) divergence = 0.0;
    
    imageStore(u_divergence_image, gid, vec4(-divergence));
}