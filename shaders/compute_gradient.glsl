#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_velocity_x_texture;
layout(binding = 2) uniform sampler3D u_velocity_y_texture;
layout(binding = 3) uniform sampler3D u_velocity_z_texture;

layout(binding = 0) writeonly uniform image3D u_velocity_x_image;
layout(binding = 1) writeonly uniform image3D u_velocity_y_image;
layout(binding = 2) writeonly uniform image3D u_velocity_z_image;

layout(location = 0) uniform ivec3 u_size;

float fetch_pressure(ivec3 gid) {
    if (any(greaterThanEqual(uvec3(gid), uvec3(u_size)))) return 0.0;
    return texelFetch(u_pressure_texture, gid, 0).x;
}


void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float p0 = fetch_pressure(gid + ivec3(0, 0, 0));
    float px = fetch_pressure(gid + ivec3(1, 0, 0));
    float py = fetch_pressure(gid + ivec3(0, 1, 0));
    float pz = fetch_pressure(gid + ivec3(0, 0, 1));

    float vx = texelFetch(u_velocity_x_texture, gid, 0).x - (px - p0);
    float vy = texelFetch(u_velocity_y_texture, gid, 0).x - (py - p0);
    float vz = texelFetch(u_velocity_z_texture, gid, 0).x - (pz - p0);

    if (gid.y == 0 || gid.z == 0) {
        vx = 0.0;
    }
    if (gid.x == 0 || gid.z == 0) {
        vy = 0.0;
    }
    if (gid.x == 0 || gid.y == 0) {
        vz = 0.0;
    }
    imageStore(u_velocity_x_image, gid, vec4(vx));
    imageStore(u_velocity_y_image, gid, vec4(vy));
    imageStore(u_velocity_z_image, gid, vec4(vz));
}