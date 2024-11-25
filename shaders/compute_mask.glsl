#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) uniform sampler3D u_input_texture;

layout(binding = 0) writeonly uniform image3D u_output_image;
layout(binding = 1) writeonly uniform image3D u_output_image2;


shared bool s_mask;
shared bool s_mask4[2][2][2];

void main() {
    ivec3 lid = ivec3(gl_LocalInvocationID);
    if (gl_LocalInvocationIndex == 0) s_mask = false;
    if (all(lessThan(lid, ivec3(2)))) {
        s_mask4[lid.z][lid.y][lid.x] = false;
    }
    memoryBarrierShared();
    barrier();

    ivec3 gid = ivec3(gl_GlobalInvocationID);
    bool mask = texelFetch(u_input_texture, gid, 0).x != 0.0;
    if (mask) {
        s_mask = true;
        s_mask4[lid.z/4][lid.y/4][lid.x/4] = true;

    }
    
    memoryBarrierShared();
    barrier();

    if (gl_LocalInvocationIndex == 0) {
        imageStore(u_output_image, gid/8, vec4(float(s_mask)));
    }
    if (all(lessThan(lid, ivec3(2)))) {

        imageStore(u_output_image2, 2*(gid/8) + lid, vec4(float(s_mask4[lid.z][lid.y][lid.x])));
    }
}