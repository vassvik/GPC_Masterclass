#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform ivec3 u_coarse_size;

layout(binding = 0) uniform sampler3D u_coarse_pressure_texture;
layout(binding = 1) uniform sampler3D u_fine_pressure_texture;

layout(binding = 0) writeonly uniform image3D u_fine_pressure_image;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    vec3 uvw = (gid/2.0 + 0.5) / vec3(u_coarse_size);
    float e = texture(u_coarse_pressure_texture, uvw).x;
    float x = texelFetch(u_fine_pressure_texture, gid, 0).x;

    imageStore(u_fine_pressure_image, gid, vec4(x + e));
}

// fine     | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | A | B | C | D | E | F | - |
// coarse |   0   |   1   |   2   |   3   |   4   |   5   |   6   |   7   |   -   |