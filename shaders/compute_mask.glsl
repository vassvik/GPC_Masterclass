#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) uniform sampler3D u_input_texture;

layout(binding = 0) writeonly uniform image3D u_output_image;


shared bool s_mask;

void main() {
    if (gl_LocalInvocationIndex == 0) s_mask = false;
    memoryBarrierShared();
    barrier();

    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (texelFetch(u_input_texture, gid, 0).x != 0.0) {
        s_mask = true;
    }
    
    memoryBarrierShared();
    barrier();

    if (gl_LocalInvocationIndex == 0) {
        imageStore(u_output_image, gid/8, vec4(float(s_mask)));
    }
}