#version 460 core

<local_size>

// glDispatchCompute(u_size.x / 8, u_size.y / 8, u_size.z / 8)
//layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(location = 0) uniform ivec3 u_size;

layout(binding = 0) uniform sampler3D u_tex;

layout(binding = 0) writeonly uniform image3D u_img;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float sum = 0.0;
    for (int k = -1; k <= +1; k++) {
        for (int j = -1; j <= +1; j++) {
            for (int i = -1; i <= +1; i++) {
                ivec3 idx = gid + ivec3(i, j, k);
                float x = texelFetch(u_tex, idx, 0).x;
                if (any(greaterThanEqual(uvec3(idx), uvec3(u_size)))) {
                    x = 0.0;
                }
                sum += x;
            }
        }
    }

    imageStore(u_img, gid, vec4(sum / 27.0));
}

// https://shader-playground.timjones.io/833a7309a6cfa74c27c0fa9422a57413
//
//   sgpr_count(22)
//   vgpr_count(40)
//
// Maximum # VGPR used  36, VGPRs allocated by HW:  48 (36 requested)
//
// Instructions: 167

