#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) uniform sampler3D u_velocity_x_texture;
layout(binding = 1) uniform sampler3D u_velocity_y_texture;
layout(binding = 2) uniform sampler3D u_velocity_z_texture;

layout(binding = 0) writeonly uniform image3D u_velocity_x_image;
layout(binding = 1) writeonly uniform image3D u_velocity_y_image;
layout(binding = 2) writeonly uniform image3D u_velocity_z_image;

layout(location = 0) uniform ivec3 u_size;

vec3 fetch_velocity(ivec3 gid) {
    //if (any(greaterThanEqual(uvec3(gid), uvec3(u_size)))) return 0.0;
    float vx = texelFetch(u_velocity_x_texture, gid, 0).x;
    float vy = texelFetch(u_velocity_y_texture, gid, 0).x;
    float vz = texelFetch(u_velocity_z_texture, gid, 0).x;
    return vec3(vx, vy, vz);
}


void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    vec3 v000 = fetch_velocity(gid + ivec3(-1, -1, -1));
    vec3 v100 = fetch_velocity(gid + ivec3( 0, -1, -1));
    vec3 v200 = fetch_velocity(gid + ivec3(+1, -1, -1));

    vec3 v010 = fetch_velocity(gid + ivec3(-1,  0, -1));
    vec3 v110 = fetch_velocity(gid + ivec3( 0,  0, -1));
    vec3 v210 = fetch_velocity(gid + ivec3(+1,  0, -1));

    vec3 v020 = fetch_velocity(gid + ivec3(-1, +1, -1));
    vec3 v120 = fetch_velocity(gid + ivec3( 0, +1, -1));
    vec3 v220 = fetch_velocity(gid + ivec3(+1, +1, -1));


    vec3 v001 = fetch_velocity(gid + ivec3(-1, -1,  0));
    vec3 v101 = fetch_velocity(gid + ivec3( 0, -1,  0));
    vec3 v201 = fetch_velocity(gid + ivec3(+1, -1,  0));

    vec3 v011 = fetch_velocity(gid + ivec3(-1,  0,  0));
    vec3 v111 = fetch_velocity(gid + ivec3( 0,  0,  0));
    vec3 v211 = fetch_velocity(gid + ivec3(+1,  0,  0));

    vec3 v021 = fetch_velocity(gid + ivec3(-1, +1,  0));
    vec3 v121 = fetch_velocity(gid + ivec3( 0, +1,  0));
    vec3 v221 = fetch_velocity(gid + ivec3(+1, +1,  0));


    vec3 v002 = fetch_velocity(gid + ivec3(-1, -1, +1));
    vec3 v102 = fetch_velocity(gid + ivec3( 0, -1, +1));
    vec3 v202 = fetch_velocity(gid + ivec3(+1, -1, +1));

    vec3 v012 = fetch_velocity(gid + ivec3(-1,  0, +1));
    vec3 v112 = fetch_velocity(gid + ivec3( 0,  0, +1));
    vec3 v212 = fetch_velocity(gid + ivec3(+1,  0, +1));

    vec3 v022 = fetch_velocity(gid + ivec3(-1, +1, +1));
    vec3 v122 = fetch_velocity(gid + ivec3( 0, +1, +1));
    vec3 v222 = fetch_velocity(gid + ivec3(+1, +1, +1));

    vec3 faces = v110 + v112 + v101 + v011 + v211 + v121;
    vec3 corners = v000 + v200 + v210 + v220 + v002 + v202 + v022 + v222;

    vec3 w = (v111 * 16 - 4.0 * faces + corners) / 32;
    vec3 v = v111 - 1*w;

    if (gid.y == 0 || gid.z == 0) {
        v.x = 0.0;
    }
    if (gid.x == 0 || gid.z == 0) {
        v.y = 0.0;
    }
    if (gid.x == 0 || gid.y == 0) {
        v.z = 0.0;
    }
    imageStore(u_velocity_x_image, gid, vec4(v.x));
    imageStore(u_velocity_y_image, gid, vec4(v.y));
    imageStore(u_velocity_z_image, gid, vec4(v.z));
}