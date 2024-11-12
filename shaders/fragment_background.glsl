#version 460 core

layout(binding = 0) uniform sampler2D envmap_texture;

out vec4 color;

layout(location = 0) uniform vec3 u_camera_forward;
layout(location = 1) uniform vec3 u_camera_right;
layout(location = 2) uniform vec3 u_camera_up; 

in vec2 a_uv;

void main() {
	vec2 ndc = 2.0 * a_uv - 1.0;
	vec3 dir = normalize(u_camera_forward + u_camera_right*ndc.x + u_camera_up*ndc.y);

	float y = acos(dir.z) / 3.14159265359;
	float x = atan(dir.y, dir.x) / 6.28318530718;
	color = texture(envmap_texture, vec2(x, y));
	//color = texture(envmap_texture, a_uv);
}
