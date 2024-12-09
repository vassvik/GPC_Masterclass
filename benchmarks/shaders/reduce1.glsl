#version 460 core

layout(local_size_x=16, local_size_y=16, local_size_z=1) in;

layout(location = 0) uniform int u_level;

layout(binding = 0) uniform sampler2D u_tex_in;

layout(binding = 0, rgba32f) readonly  uniform image2D u_img_in;

layout(binding = 1) writeonly uniform image2D u_img_out;

void main() {
    ivec2 gid = ivec2(gl_GlobalInvocationID.xy);

    //vec4 v00 = imageLoad(u_img_in, 2*gid+ivec2(0, 0));
    //vec4 v10 = imageLoad(u_img_in, 2*gid+ivec2(1, 0));
    //vec4 v01 = imageLoad(u_img_in, 2*gid+ivec2(0, 1));
    //vec4 v11 = imageLoad(u_img_in, 2*gid+ivec2(1, 1));

    vec4 v00 = texelFetch(u_tex_in, 2*gid+ivec2(0, 0), u_level);
    vec4 v10 = texelFetch(u_tex_in, 2*gid+ivec2(1, 0), u_level);
    vec4 v01 = texelFetch(u_tex_in, 2*gid+ivec2(0, 1), u_level);
    vec4 v11 = texelFetch(u_tex_in, 2*gid+ivec2(1, 1), u_level);

    vec4 v = (v00 + v10 + v01 + v11) / 4.0;

    imageStore(u_img_out, ivec2(gid), v);
}

