#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(location = 0) uniform ivec3 u_size;

layout(binding = 0) uniform sampler3D u_density_texture;

layout(binding = 0) writeonly uniform image3D u_accumulation_image;

shared float s_density[16][16][16];

void process_direction(ivec3 lid, ivec3 gid, int steps, ivec3 dir) {
    float sum_density = 0.0;
    for (int i = 0; i < steps; i++) {
        sum_density += s_density[lid.z+dir.z*i][lid.y+dir.y*i][lid.x+dir.x*i];
    }
    imageStore(u_accumulation_image, gid, vec4(sum_density));
}

void process_direction2(ivec3 lid, ivec3 gid, ivec3 gid2, int steps, int steps2, ivec3 dir) {
    float sum_density = 0.0;
    for (int i = 0; i < steps; i++) {
        sum_density += s_density[lid.z+dir.z*i][lid.y+dir.y*i][lid.x+dir.x*i];
    }
    for (int i = steps; i < steps2; i++) {
        sum_density += texelFetch(u_density_texture, gid2 + i*dir, 0).x;
    }
    imageStore(u_accumulation_image, gid, vec4(sum_density));
}

#define INCLUDE_AXES 1
#define INCLUDE_MINOR_DIAGONALS 1
#define INCLUDE_MAJOR_DIAGONALS 1

void main() {
    ivec3 wid = ivec3(gl_WorkGroupID.xyz);
    
    ivec3 lid = ivec3(gl_LocalInvocationID.xyz);

    ivec3 s = u_size;

    ivec3 gid = 16*wid + lid;
    
    for (int k = 0; k < 2; k++) for (int j = 0; j < 2; j++) for (int i = 0; i < 2; i++) {
        if (any(greaterThanEqual(gid+8*ivec3(i, j, k), s))) {
            s_density[lid.z+k*8][lid.y+j*8][lid.x+i*8] = 0.0;    
        } else {
            float x = texelFetch(u_density_texture, gid+8*ivec3(i, j, k), 0).x;;
            s_density[lid.z+k*8][lid.y+j*8][lid.x+i*8] = x;
        }
    }
    
    memoryBarrierShared();
    barrier();

    for (int k = 0; k < 2; k++) for (int j = 0; j < 2; j++) for (int i = 0; i < 2; i++) {
        ivec3 lid = lid + ivec3(i, j, k)*8;
        ivec3 gid = 16*wid + lid;
        if (any(greaterThanEqual(gid, s))) continue;

        ivec3 bst = 1 + lid;
        ivec3 fst = 16 - lid;

    #if INCLUDE_AXES == 1
        process_direction(lid, gid + ivec3(0, 0, 0)*s, fst.x, ivec3(+1,  0,  0));
        process_direction(lid, gid + ivec3(1, 0, 0)*s, fst.y, ivec3( 0, +1,  0));
        process_direction(lid, gid + ivec3(2, 0, 0)*s, fst.z, ivec3( 0,  0, +1));

        process_direction(lid, gid + ivec3(0, 1, 0)*s, bst.x, ivec3(-1,  0,  0));
        process_direction(lid, gid + ivec3(1, 1, 0)*s, bst.y, ivec3( 0, -1,  0));
        process_direction(lid, gid + ivec3(2, 1, 0)*s, bst.z, ivec3( 0,  0, -1));
    #endif

    #if INCLUDE_MINOR_DIAGONALS == 1
        process_direction2(lid, gid + ivec3(0, 2, 0)*s, gid, min(fst.x, fst.y), max(fst.x, fst.y), ivec3(+1, +1,  0));
        process_direction2(lid, gid + ivec3(1, 2, 0)*s, gid, min(bst.x, fst.y), max(bst.x, fst.y), ivec3(-1, +1,  0));
        process_direction2(lid, gid + ivec3(2, 2, 0)*s, gid, min(fst.x, bst.y), max(fst.x, bst.y), ivec3(+1, -1,  0));
        process_direction2(lid, gid + ivec3(0, 0, 1)*s, gid, min(bst.x, bst.y), max(bst.x, bst.y), ivec3(-1, -1,  0));

        process_direction2(lid, gid + ivec3(1, 0, 1)*s, gid, min(fst.x, fst.z), max(fst.x, fst.z), ivec3(+1,  0, +1));
        process_direction2(lid, gid + ivec3(2, 0, 1)*s, gid, min(bst.x, fst.z), max(bst.x, fst.z), ivec3(-1,  0, +1));
        process_direction2(lid, gid + ivec3(0, 1, 1)*s, gid, min(fst.x, bst.z), max(fst.x, bst.z), ivec3(+1,  0, -1));
        process_direction2(lid, gid + ivec3(1, 1, 1)*s, gid, min(bst.x, bst.z), max(bst.x, bst.z), ivec3(-1,  0, -1));

        process_direction2(lid, gid + ivec3(2, 1, 1)*s, gid, min(fst.y, fst.z), max(fst.y, fst.z), ivec3( 0, +1, +1));
        process_direction2(lid, gid + ivec3(0, 2, 1)*s, gid, min(bst.y, fst.z), max(bst.y, fst.z), ivec3( 0, -1, +1));
        process_direction2(lid, gid + ivec3(1, 2, 1)*s, gid, min(fst.y, bst.z), max(fst.y, bst.z), ivec3( 0, +1, -1));
        process_direction2(lid, gid + ivec3(2, 2, 1)*s, gid, min(bst.y, bst.z), max(bst.y, bst.z), ivec3( 0, -1, -1));
    #endif

    #if INCLUDE_MAJOR_DIAGONALS == 1
        process_direction2(lid, gid + ivec3(0, 0, 2)*s, gid, min(min(fst.x, fst.y), fst.z), max(max(fst.x, fst.y), fst.z), ivec3(+1, +1, +1));
        process_direction2(lid, gid + ivec3(1, 0, 2)*s, gid, min(min(bst.x, fst.y), fst.z), max(max(bst.x, fst.y), fst.z), ivec3(-1, +1, +1));
        process_direction2(lid, gid + ivec3(2, 0, 2)*s, gid, min(min(fst.x, bst.y), fst.z), max(max(fst.x, bst.y), fst.z), ivec3(+1, -1, +1));
        process_direction2(lid, gid + ivec3(0, 1, 2)*s, gid, min(min(bst.x, bst.y), fst.z), max(max(bst.x, bst.y), fst.z), ivec3(-1, -1, +1));
        process_direction2(lid, gid + ivec3(1, 1, 2)*s, gid, min(min(fst.x, fst.y), bst.z), max(max(fst.x, fst.y), bst.z), ivec3(+1, +1, -1));
        process_direction2(lid, gid + ivec3(2, 1, 2)*s, gid, min(min(bst.x, fst.y), bst.z), max(max(bst.x, fst.y), bst.z), ivec3(-1, +1, -1));
        process_direction2(lid, gid + ivec3(0, 2, 2)*s, gid, min(min(fst.x, bst.y), bst.z), max(max(fst.x, bst.y), bst.z), ivec3(+1, -1, -1));
        process_direction2(lid, gid + ivec3(1, 2, 2)*s, gid, min(min(bst.x, bst.y), bst.z), max(max(bst.x, bst.y), bst.z), ivec3(-1, -1, -1));
    #endif
    }
}

