#version 460 core

layout(local_size_x = 4, local_size_y = 8, local_size_z = 8) in;

layout (std430, binding = 0) buffer Coordinates {
    int coordinates[];
};

layout (std430, binding = 1) buffer LeafData1 {
    uint leaf_data[];
};

layout(binding = 0) writeonly uniform image3D   output_image0;

shared float s_reduced1[8][8][4];

void main() {
    uvec3 wid = gl_WorkGroupID;
    uint lindex = gl_LocalInvocationIndex;
    uvec3 lid = gl_LocalInvocationID;
    lid.yz = lid.zy;
    lindex = lid.y*32 + lid.z*4 + lid.x;

    uint leaf_node_idx = wid.x;

    ivec3 leaf_coordinate = ivec3(
        coordinates[3*leaf_node_idx+0],
        coordinates[3*leaf_node_idx+2],
        coordinates[3*leaf_node_idx+1]
    );

    leaf_coordinate.y = imageSize(output_image0).y/8 - 1 - leaf_coordinate.y;
    lid.y = 7 - lid.y;

    uvec3 gid = leaf_coordinate * uvec3(8, 8, 8) + uvec3(2*lid.x, lid.yz);

    uint buf_idx = leaf_node_idx * (8*8*4) + lindex;

    uint data = leaf_data[buf_idx];

    vec2 data2 = unpackHalf2x16(data);

    imageStore(output_image0, ivec3(gid + uvec3(0, 0, 0)), vec4(data2.x));
    imageStore(output_image0, ivec3(gid + uvec3(1, 0, 0)), vec4(data2.y));
}

