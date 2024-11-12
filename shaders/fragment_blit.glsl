#version 460 core

layout(binding = 0) uniform sampler2D render_texture;

out vec4 color;

in vec2 a_uv;

void main() {
	color = texture(render_texture, a_uv);
}
