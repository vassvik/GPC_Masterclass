#version 460 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(binding = 0) uniform sampler3D u_texture;

layout(location = 0) uniform ivec3 u_position;

layout (std430, binding = 0) buffer Values {
    float value;
};

void main() {
    value = texelFetch(u_texture, u_position, 0).x;
}
