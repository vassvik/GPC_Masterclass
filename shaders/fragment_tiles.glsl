#version 430 core

layout(binding = 1) uniform sampler3D lighting_texture;

out vec4 color;

in vec3 tile_color;

in vec3 tex_uvw;

void main() {
    color = vec4(tile_color, 1.0);
}