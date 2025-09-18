#version 460 core

layout(binding = 0) uniform sampler2D u_render_texture;
layout(binding = 1) uniform sampler3D u_velocity_x_texture;
layout(binding = 2) uniform sampler3D u_velocity_y_texture;
layout(binding = 3) uniform sampler3D u_velocity_z_texture;
layout(binding = 4) uniform sampler3D u_initial_divergence_texture;
layout(binding = 5) uniform sampler3D u_final_divergence_texture;

out vec4 color;

in vec2 a_uv;

layout(location=0) uniform uint u_mode;
layout(location=1) uniform uint u_direction;
layout(location=2) uniform float u_slice;
layout(location=3) uniform float u_scale;
layout(location=4) uniform uvec2 u_mouse_pos;

layout (std430, binding = 0) buffer Stats {
    float debug[];
};

vec3 logspace_color_map(float v) {
    float logv = log(abs(v)) / log(10.0);
    float f = floor(logv + 7.0);
    float i = floor(4 * ((logv + 7.0) - f));

    if (f < 0.0) return vec3(0.0);
    if (f < 1.0) return mix(vec3(1.0, 0.0, 0.0), vec3(1.0), i / 4.0);
    if (f < 2.0) return mix(vec3(0.0, 1.0, 0.0), vec3(1.0), i / 4.0);
    if (f < 3.0) return mix(vec3(0.0, 0.0, 1.0), vec3(1.0), i / 4.0);
    if (f < 4.0) return mix(vec3(1.0, 1.0, 0.0), vec3(1.0), i / 4.0);
    if (f < 5.0) return mix(vec3(1.0, 0.0, 1.0), vec3(1.0), i / 4.0);
    if (f < 6.0) return mix(vec3(0.0, 1.0, 1.0), vec3(1.0), i / 4.0);
    if (f < 7.0) return mix(vec3(1.0, 0.5, 0.0), vec3(1.0), i / 4.0);
    if (f < 8.0) return mix(vec3(1.0, 1.0, 1.0), vec3(1.0), i / 4.0);
    return vec3(1.0);
}

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
		if (uvec2(gl_FragCoord.xy) == u_mouse_pos) {
			debug[0] = color.r;
			debug[1] = color.g;
			debug[2] = color.b;
			debug[3] = color.a;
		}
		color.rgb = (color.rgb*u_scale * 0.5 + 0.5);
		color.a = 1.0;
	} else if (u_mode == 2) {
		float divergence = texture(u_initial_divergence_texture, uvw).x;
		if (uvec2(gl_FragCoord.xy) == u_mouse_pos) {
			debug[0] = divergence;
			debug[1] = 0.0;
			debug[2] = 0.0;
			debug[3] = 0.0;
		}
		color.rgb = logspace_color_map(u_scale*divergence);
		color.a = 1.0;
	} else if (u_mode == 3) {
		float divergence = texture(u_final_divergence_texture, uvw).x;
		if (uvec2(gl_FragCoord.xy) == u_mouse_pos) {
			debug[0] = divergence;
			debug[1] = 0.0;
			debug[2] = 0.0;
			debug[3] = 0.0;
		}
		color.rgb = logspace_color_map(u_scale*divergence);
		color.a = 1.0;
	} else {
		color = vec4(1.0, 0.0, 0.0, 1.0);
	}
	
}
