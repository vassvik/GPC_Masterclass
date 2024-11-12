#version 430 core

layout (location = 0) uniform mat4x4 u_PVM;
layout (location = 1) uniform ivec3  u_size;

// 0x787833 == 0b011110000111100000110011
// 0x1E1E0F == 0b000111100001111000001111
// 0xFF55   == 0b000000001111111101010101
vec3 index_to_unit_cube_wireframe(uint i) {
    return vec3(notEqual(uvec3(0x787833, 0x1E1E0F, 0xFF55) & (1 << i), uvec3(0U)));
}

out vec3 tile_color;
out vec3 tex_uvw;

void main() {
    uint vdx = gl_VertexID;
    uint idx = gl_InstanceID;

    vec3 position;
    vec3 size;
    vec3 uvw = index_to_unit_cube_wireframe(vdx);

    {
        // bounding box
        position = vec3(0.0);
        size = u_size;
        tile_color = vec3(0.6, 1.0, 0.1);
    }

    position = position + uvw * size;
    tex_uvw = position / u_size;

    gl_Position = u_PVM * vec4(position, 1.0);
}