#version 460 core

layout(local_size_x=16, local_size_y=16, local_size_z=1) in;

layout(binding = 0) writeonly uniform image2D u_image;

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
    uvec2 gid = gl_GlobalInvocationID.xy;

    vec4 v = pcg4d(uvec4(gid, 1237121+gid.x+gid.y, 123567+gid.x-gid.y));

    imageStore(u_image, ivec2(gid), v);
}

