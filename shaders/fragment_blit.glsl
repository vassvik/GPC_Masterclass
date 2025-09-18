#version 460 core

layout(binding = 0) uniform sampler2D u_render_texture;
layout(binding = 1) uniform sampler3D u_velocity_x_texture;
layout(binding = 2) uniform sampler3D u_velocity_y_texture;
layout(binding = 3) uniform sampler3D u_velocity_z_texture;

out vec4 color;

in vec2 a_uv;

layout(location=0) uniform uint u_mode;
layout(location=1) uniform uint u_direction;
layout(location=2) uniform float u_slice;
layout(location=3) uniform float u_scale;

void main() {
	vec3 uvw = vec3(a_uv, u_slice);
	if (u_direction == 0) uvw = uvw.zxy;
	if (u_direction == 1) uvw = uvw.xzy;

	if (u_mode == 0) {
		color = texture(u_render_texture, a_uv);
	} else if (u_mode == 1) {
		color.r = texture(u_velocity_x_texture, uvw).x;
		color.g = texture(u_velocity_y_texture, uvw).x;
		color.b = texture(u_velocity_z_texture, uvw).x;
		color.rgb = (color.rgb*u_scale * 0.5 + 0.5);
		color.a = 1.0;
	} else {
		color = vec4(1.0, 0.0, 0.0, 1.0);
	}
}
