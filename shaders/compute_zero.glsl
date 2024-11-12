#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) writeonly uniform image3D u_output_image;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    imageStore(u_output_image, gid, vec4(0.0));
}