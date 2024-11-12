#version 460 core

<local_size>

layout(location = 0) uniform float u_dx;
layout(location = 1) uniform vec3 u_scale;
layout(location = 2) uniform bool u_randomize;

layout(binding = 0) writeonly uniform image3D u_lhs_image;
layout(binding = 1) writeonly uniform image3D u_rhs_image;

float laplacian(ivec3 gid) {
    float x = float(gid.x + 1) * u_scale.x;
    float y = float(gid.y + 1) * u_scale.y;
    float z = float(gid.z + 1) * u_scale.z;

    float df2dx2 = -128.0*y*(1-y)*z*(1-z);
    float df2dy2 = -128.0*x*(1-x)*z*(1-z);
    float df2dz2 = -128.0*x*(1-x)*y*(1-y);

    return (df2dx2 + df2dy2 + df2dz2)*u_dx*u_dx;
} 

vec4 pcg4d(uvec4 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y*v.w;
    v.y += v.z*v.x;
    v.z += v.x*v.y;
    v.w += v.y*v.z;
    v = v ^ (v >> 16u);
    v.x += v.y*v.w;
    v.y += v.z*v.x;
    v.z += v.x*v.y;
    v.w += v.y*v.z;
    return v * (1.0 / float(0xffffffffU));
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float df2 = laplacian(gid);
    if (u_randomize) {
        df2 = -6*pcg4d(uvec4(gid, gid.x+gid.y-gid.z)).x;
    }

    imageStore(u_lhs_image, gid, vec4(-df2/6.0));
    imageStore(u_rhs_image, gid, vec4(-df2));
}

