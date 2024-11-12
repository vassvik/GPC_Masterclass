#version 430 core

layout(binding = 1) uniform sampler3D lighting_texture;
layout(binding = 2) uniform sampler3D density_texture;

layout(location = 1) uniform ivec3 u_size;

layout(location = 11) uniform vec3 u_cam_pos;
layout(location = 12) uniform float u_density_scale;

out vec4 color;

in vec3 tile_color;

in vec3 tex_uvw;
in vec3 v_uvw;

in vec3 v_entry_position;

void main() {
    vec3 unnormalized_dir = v_entry_position - u_cam_pos;
    vec3 dir = normalize(unnormalized_dir);

    float dist_entry = length(unnormalized_dir);

    vec3 t_exits = (mix(vec3(8.0), vec3(0.0), lessThan(dir, vec3(0.0))) - 8*v_uvw) / dir;
    float t_exit = min(min(t_exits.x, t_exits.y), t_exits.z);

    vec3 c = vec3(0.0);
    float T = 1.0;

    #define STEP_SIZE 1.0
    for (float t = STEP_SIZE*ceil(dist_entry/STEP_SIZE); t < dist_entry + t_exit; t += STEP_SIZE) {
        vec3 p = (u_cam_pos + t * dir) / u_size;
        float d = u_density_scale*texture(density_texture, p).x;
        vec3 l = texture(lighting_texture, p).xyz;
        c += d*l*T*STEP_SIZE;
        T *= exp(-d*STEP_SIZE);
    }

    color = vec4(c, 1.0-T);
}