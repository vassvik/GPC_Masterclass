#version 430 core

out vec2 a_uv;

void main() {
    // Screen-covering triangle that gets clipped to a screen filling rect
    a_uv = 3.0 * vec2(gl_VertexID % 2, gl_VertexID / 2);

    gl_Position = vec4(2.0 * a_uv - 1.0, 0.0, 1.0);
}