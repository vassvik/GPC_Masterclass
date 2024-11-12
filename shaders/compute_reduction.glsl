#version 460 core

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

layout(binding = 0) uniform sampler3D u_input_texture;

layout(binding = 0) writeonly uniform image3D u_output_image;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float x = 0.0;
    x += texelFetch(u_input_texture, 2*gid+ivec3(0,0,0), 0).x;
    x += texelFetch(u_input_texture, 2*gid+ivec3(1,0,0), 0).x;
    x += texelFetch(u_input_texture, 2*gid+ivec3(0,1,0), 0).x;
    x += texelFetch(u_input_texture, 2*gid+ivec3(1,1,0), 0).x;
    x += texelFetch(u_input_texture, 2*gid+ivec3(0,0,1), 0).x;
    x += texelFetch(u_input_texture, 2*gid+ivec3(1,0,1), 0).x;
    x += texelFetch(u_input_texture, 2*gid+ivec3(0,1,1), 0).x;
    x += texelFetch(u_input_texture, 2*gid+ivec3(1,1,1), 0).x;
    x /= 8.0;

    imageStore(u_output_image, gid, vec4(x));
}