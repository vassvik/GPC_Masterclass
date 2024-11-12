#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform ivec3 u_fine_size;

layout(binding = 0) uniform sampler3D u_fine_residual_texture;

layout(binding = 0) writeonly uniform image3D u_coarse_residual_image;

float fetch_fine_residual(ivec3 gid) {
    if (any(greaterThanEqual(uvec3(gid), uvec3(u_fine_size)))) return 0.0;
    return texelFetch(u_fine_residual_texture, gid, 0).x;
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    float rWSD = fetch_fine_residual(2*gid+ivec3(-1, -1, -1));
    float rWSC = fetch_fine_residual(2*gid+ivec3(-1, -1, +0));
    float rWSU = fetch_fine_residual(2*gid+ivec3(-1, -1, +1));

    float rWCD = fetch_fine_residual(2*gid+ivec3(-1, +0, -1));
    float rWCC = fetch_fine_residual(2*gid+ivec3(-1, +0, +0));
    float rWCU = fetch_fine_residual(2*gid+ivec3(-1, +0, +1));

    float rWND = fetch_fine_residual(2*gid+ivec3(-1, +1, -1));
    float rWNC = fetch_fine_residual(2*gid+ivec3(-1, +1, +0));
    float rWNU = fetch_fine_residual(2*gid+ivec3(-1, +1, +1));

    float rCSD = fetch_fine_residual(2*gid+ivec3(+0, -1, -1));
    float rCSC = fetch_fine_residual(2*gid+ivec3(+0, -1, +0));
    float rCSU = fetch_fine_residual(2*gid+ivec3(+0, -1, +1));

    float rCCD = fetch_fine_residual(2*gid+ivec3(+0, +0, -1));
    float rCCC = fetch_fine_residual(2*gid+ivec3(+0, +0, +0));
    float rCCU = fetch_fine_residual(2*gid+ivec3(+0, +0, +1));

    float rCND = fetch_fine_residual(2*gid+ivec3(+0, +1, -1));
    float rCNC = fetch_fine_residual(2*gid+ivec3(+0, +1, +0));
    float rCNU = fetch_fine_residual(2*gid+ivec3(+0, +1, +1));

    float rESD = fetch_fine_residual(2*gid+ivec3(+1, -1, -1));
    float rESC = fetch_fine_residual(2*gid+ivec3(+1, -1, +0));
    float rESU = fetch_fine_residual(2*gid+ivec3(+1, -1, +1));

    float rECD = fetch_fine_residual(2*gid+ivec3(+1, +0, -1));
    float rECC = fetch_fine_residual(2*gid+ivec3(+1, +0, +0));
    float rECU = fetch_fine_residual(2*gid+ivec3(+1, +0, +1));

    float rEND = fetch_fine_residual(2*gid+ivec3(+1, +1, -1));
    float rENC = fetch_fine_residual(2*gid+ivec3(+1, +1, +0));
    float rENU = fetch_fine_residual(2*gid+ivec3(+1, +1, +1));

    float rWS = (rWSD + 2.0*rWSC + rWSU) * 0.25;
    float rCS = (rCSD + 2.0*rCSC + rCSU) * 0.25;
    float rES = (rESD + 2.0*rESC + rESU) * 0.25;
    float rWC = (rWCD + 2.0*rWCC + rWCU) * 0.25;
    float rCC = (rCCD + 2.0*rCCC + rCCU) * 0.25;
    float rEC = (rECD + 2.0*rECC + rECU) * 0.25;
    float rWN = (rWND + 2.0*rWNC + rWNU) * 0.25;
    float rCN = (rCND + 2.0*rCNC + rCNU) * 0.25;
    float rEN = (rEND + 2.0*rENC + rENU) * 0.25;

    float rW = (rWS + 2.0*rWC + rWN) * 0.25;
    float rC = (rCS + 2.0*rCC + rCN) * 0.25;
    float rE = (rES + 2.0*rEC + rEN) * 0.25;

    float r = (rW + 2.0*rC + rE) * 0.25;
    r *= 4.0;

    if (any(equal(gid, ivec3(0)))) r = 0.0;
    imageStore(u_coarse_residual_image, gid, vec4(r));
}