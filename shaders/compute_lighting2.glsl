#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform ivec3 u_size;
layout(location = 1) uniform vec3 u_cam_pos;
layout(location = 2) uniform float u_density_scale;

layout(binding = 0) uniform sampler3D u_accumulation_texture;
layout(binding = 1) uniform sampler3D u_density_texture;

layout(binding = 0) writeonly uniform image3D u_lighting_image;

layout (std430, binding = 0) buffer EnvmapBuffer {
    float envmap_buffer[];
};

float process_direction(ivec3 gid, ivec3 offset, int steps_tile, int steps_grid, ivec3 dir, float density) {
    float sum_density = 0.0;
    if (all(lessThan(gid, u_size))) {
        sum_density = texelFetch(u_accumulation_texture, gid + offset, 0).x;
    }

    ivec3 cid = gid + steps_tile*dir;
    for (int i = 0; i < steps_grid; i++) {
        if (all(lessThan(cid, u_size))) {
            sum_density += texelFetch(u_accumulation_texture, cid + offset, 0).x;
        }
        cid += 16*dir;
    }

    return sum_density - 1.0*density;
}

#define INCLUDE_AXES 1
#define INCLUDE_MINOR_DIAGONALS 1
#define INCLUDE_MAJOR_DIAGONALS 1

vec3 envmap_color(ivec3 dir) {
    int i = dir.x + 1;
    int j = dir.y + 1;
    int k = dir.z + 1;
    int ijk = k*9 + j*3 + i;
    float r = envmap_buffer[3*ijk+0];
    float g = envmap_buffer[3*ijk+1];
    float b = envmap_buffer[3*ijk+2];
    return vec3(r, g, b);
}

float HenyeyGreenstein(float g, float costh){
    return (1.0 / (4.0 * 3.1415))  * ((1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * costh, 1.5));
}

// https://research.nvidia.com/labs/rtr/approximate-mie/
float evalDraine(in float u, in float g, in float a)
{
    return ((1 - g*g)*(1 + a*u*u))/(4.* 3.14159265*(1 + (a*(1 + 2*g*g))/3.) * pow(1 + g*g - 2*g*u,1.5));
}

float phase_function(ivec3 gid, ivec3 dir) {
    vec3 ray_dir = normalize(vec3(gid - u_cam_pos));
    vec3 light_dir = normalize(dir);

    float mu = dot(ray_dir, light_dir);

    float d = 100.0;
    float g_HG = exp(-0.0990567/(d-1.67154));
    float g_D = exp(-2.20679/(d+3.91029)-0.428934);
    float a = exp(3.62489 - 8.29288/(d + 5.52825));
    float w_D = exp(-0.599085/(d - 0.641583)-0.665888);

    //return mix(evalDraine(mu, g_HG, 0.0), evalDraine(mu, g_D, a), w_D);

    //return 1.0 / (4.0*3.1415);
    return mix(HenyeyGreenstein(-0.1, mu), HenyeyGreenstein(0.7, mu), 0.8);
}

void main() {    
    ivec3 s = u_size;
    
    ivec3 gid = ivec3(gl_GlobalInvocationID.xyz);

    float density = texelFetch(u_density_texture, gid, 0).x;

    ivec3 lid = gid % 16;

    vec3 l = vec3(0.0);
    float e = u_density_scale;

    ivec3 bst = 1 + lid;  // backward_steps_tile
    ivec3 fst = 16 - lid; // forward_steps_tile

    ivec3 bsg = gid / 16;     // backward_steps_grid
    ivec3 fsg = (s-gid-1)/16; // forward_steps_grid

#if INCLUDE_AXES == 1
    l += envmap_color(ivec3(+1,  0,  0))*phase_function(gid, ivec3(+1,  0,  0))*exp(-e*(process_direction(gid, ivec3(0, 0, 0)*s, fst.x, fsg.x, ivec3(+1,  0,  0), density)));
    l += envmap_color(ivec3( 0, +1,  0))*phase_function(gid, ivec3( 0, +1,  0))*exp(-e*(process_direction(gid, ivec3(1, 0, 0)*s, fst.y, fsg.y, ivec3( 0, +1,  0), density)));
    l += envmap_color(ivec3( 0,  0, +1))*phase_function(gid, ivec3( 0,  0, +1))*exp(-e*(process_direction(gid, ivec3(2, 0, 0)*s, fst.z, fsg.z, ivec3( 0,  0, +1), density)));

    l += envmap_color(ivec3(-1,  0,  0))*phase_function(gid, ivec3(-1,  0,  0))*exp(-e*(process_direction(gid, ivec3(0, 1, 0)*s, bst.x, bsg.x, ivec3(-1,  0,  0), density)));
    l += envmap_color(ivec3( 0, -1,  0))*phase_function(gid, ivec3( 0, -1,  0))*exp(-e*(process_direction(gid, ivec3(1, 1, 0)*s, bst.y, bsg.y, ivec3( 0, -1,  0), density)));
    l += envmap_color(ivec3( 0,  0, -1))*phase_function(gid, ivec3( 0,  0, -1))*exp(-e*(process_direction(gid, ivec3(2, 1, 0)*s, bst.z, bsg.z, ivec3( 0,  0, -1), density)));
#endif

#if INCLUDE_MINOR_DIAGONALS == 1
    l += envmap_color(ivec3( 1,  1,  0))*phase_function(gid, ivec3( 1,  1,  0))*exp(-e*(process_direction(gid, ivec3(0, 2, 0)*s, max(fst.x, fst.y), min(fsg.x, fsg.y), ivec3( 1,  1,  0), density)));
    l += envmap_color(ivec3(-1,  1,  0))*phase_function(gid, ivec3(-1,  1,  0))*exp(-e*(process_direction(gid, ivec3(1, 2, 0)*s, max(bst.x, fst.y), min(bsg.x, fsg.y), ivec3(-1,  1,  0), density)));
    l += envmap_color(ivec3( 1, -1,  0))*phase_function(gid, ivec3( 1, -1,  0))*exp(-e*(process_direction(gid, ivec3(2, 2, 0)*s, max(fst.x, bst.y), min(fsg.x, bsg.y), ivec3( 1, -1,  0), density)));
    l += envmap_color(ivec3(-1, -1,  0))*phase_function(gid, ivec3(-1, -1,  0))*exp(-e*(process_direction(gid, ivec3(0, 0, 1)*s, max(bst.x, bst.y), min(bsg.x, bsg.y), ivec3(-1, -1,  0), density)));

    l += envmap_color(ivec3( 1,  0,  1))*phase_function(gid, ivec3( 1,  0,  1))*exp(-e*(process_direction(gid, ivec3(1, 0, 1)*s, max(fst.x, fst.z), min(fsg.x, fsg.z), ivec3( 1,  0,  1), density)));
    l += envmap_color(ivec3(-1,  0,  1))*phase_function(gid, ivec3(-1,  0,  1))*exp(-e*(process_direction(gid, ivec3(2, 0, 1)*s, max(bst.x, fst.z), min(bsg.x, fsg.z), ivec3(-1,  0,  1), density)));
    l += envmap_color(ivec3( 1,  0, -1))*phase_function(gid, ivec3( 1,  0, -1))*exp(-e*(process_direction(gid, ivec3(0, 1, 1)*s, max(fst.x, bst.z), min(fsg.x, bsg.z), ivec3( 1,  0, -1), density)));
    l += envmap_color(ivec3(-1,  0, -1))*phase_function(gid, ivec3(-1,  0, -1))*exp(-e*(process_direction(gid, ivec3(1, 1, 1)*s, max(bst.x, bst.z), min(bsg.x, bsg.z), ivec3(-1,  0, -1), density)));

    l += envmap_color(ivec3( 0,  1,  1))*phase_function(gid, ivec3( 0,  1,  1))*exp(-e*(process_direction(gid, ivec3(2, 1, 1)*s, max(fst.y, fst.z), min(fsg.y, fsg.z), ivec3( 0,  1,  1), density)));
    l += envmap_color(ivec3( 0, -1,  1))*phase_function(gid, ivec3( 0, -1,  1))*exp(-e*(process_direction(gid, ivec3(0, 2, 1)*s, max(bst.y, fst.z), min(bsg.y, fsg.z), ivec3( 0, -1,  1), density)));
    l += envmap_color(ivec3( 0,  1, -1))*phase_function(gid, ivec3( 0,  1, -1))*exp(-e*(process_direction(gid, ivec3(1, 2, 1)*s, max(fst.y, bst.z), min(fsg.y, bsg.z), ivec3( 0,  1, -1), density)));
    l += envmap_color(ivec3( 0, -1, -1))*phase_function(gid, ivec3( 0, -1, -1))*exp(-e*(process_direction(gid, ivec3(2, 2, 1)*s, max(bst.y, bst.z), min(bsg.y, bsg.z), ivec3( 0, -1, -1), density)));
#endif

#if INCLUDE_MAJOR_DIAGONALS == 1
    l += envmap_color(ivec3( 1,  1,  1))*phase_function(gid, ivec3( 1,  1,  1))*exp(-e*(process_direction(gid, ivec3(0, 0, 2)*s, max(max(fst.x, fst.y), fst.z), min(min(fsg.x, fsg.y), fsg.z), ivec3( 1,  1,  1), density)));
    l += envmap_color(ivec3(-1,  1,  1))*phase_function(gid, ivec3(-1,  1,  1))*exp(-e*(process_direction(gid, ivec3(1, 0, 2)*s, max(max(bst.x, fst.y), fst.z), min(min(bsg.x, fsg.y), fsg.z), ivec3(-1,  1,  1), density)));
    l += envmap_color(ivec3( 1, -1,  1))*phase_function(gid, ivec3( 1, -1,  1))*exp(-e*(process_direction(gid, ivec3(2, 0, 2)*s, max(max(fst.x, bst.y), fst.z), min(min(fsg.x, bsg.y), fsg.z), ivec3( 1, -1,  1), density)));
    l += envmap_color(ivec3(-1, -1,  1))*phase_function(gid, ivec3(-1, -1,  1))*exp(-e*(process_direction(gid, ivec3(0, 1, 2)*s, max(max(bst.x, bst.y), fst.z), min(min(bsg.x, bsg.y), fsg.z), ivec3(-1, -1,  1), density)));
    l += envmap_color(ivec3( 1,  1, -1))*phase_function(gid, ivec3( 1,  1, -1))*exp(-e*(process_direction(gid, ivec3(1, 1, 2)*s, max(max(fst.x, fst.y), bst.z), min(min(fsg.x, fsg.y), bsg.z), ivec3( 1,  1, -1), density)));
    l += envmap_color(ivec3(-1,  1, -1))*phase_function(gid, ivec3(-1,  1, -1))*exp(-e*(process_direction(gid, ivec3(2, 1, 2)*s, max(max(bst.x, fst.y), bst.z), min(min(bsg.x, fsg.y), bsg.z), ivec3(-1,  1, -1), density)));
    l += envmap_color(ivec3( 1, -1, -1))*phase_function(gid, ivec3( 1, -1, -1))*exp(-e*(process_direction(gid, ivec3(0, 2, 2)*s, max(max(fst.x, bst.y), bst.z), min(min(fsg.x, bsg.y), bsg.z), ivec3( 1, -1, -1), density)));
    l += envmap_color(ivec3(-1, -1, -1))*phase_function(gid, ivec3(-1, -1, -1))*exp(-e*(process_direction(gid, ivec3(1, 2, 2)*s, max(max(bst.x, bst.y), bst.z), min(min(bsg.x, bsg.y), bsg.z), ivec3(-1, -1, -1), density)));
#endif

    imageStore(u_lighting_image, ivec3(gid), vec4(l, 0.0));
}

