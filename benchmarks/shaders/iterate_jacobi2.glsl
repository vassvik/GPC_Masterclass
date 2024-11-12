#version 460 core

<local_size>

layout(location = 0) uniform uvec3 u_size;

layout(binding = 0) uniform sampler3D u_lhs_texture;
layout(binding = 1) uniform sampler3D u_rhs_texture;

layout(binding = 0) writeonly uniform image3D u_lhs_image;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float b = texelFetch(u_rhs_texture, gid, 0).x;

    float x = b;
    for (int k = -1; k <= +1; k++) for (int j = -1; j <= +1; j++) for (int i = -1; i <= +1; i++) {
        float y = texelFetch(u_lhs_texture, gid+ivec3(i,  j,  k), 0).x;
        if (any(greaterThanEqual(uvec3(gid + ivec3(i, j, k)), u_size))) y = 0.0;
        x += y;
    }
    imageStore(u_lhs_image, gid, vec4(x / 26.0));
}
