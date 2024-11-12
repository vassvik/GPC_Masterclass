#version 430 core

layout(binding = 0) uniform sampler3D mask_texture;

layout(location = 0)  uniform mat4x4 u_PVM;
layout(location = 1)  uniform ivec3  u_size;
layout(location = 2)  uniform uint   u_slice_axis;
layout(location = 3)  uniform bool   u_back_to_front;
layout(location = 4)  uniform uint   u_num_slices;
layout(location = 5)  uniform uint   u_num_tiles_in_slice;
layout(location = 6)  uniform uint   u_num_columns;
layout(location = 7)  uniform uint   u_num_rows;
layout(location = 8)  uniform uint   u_cam_pos_column;
layout(location = 9)  uniform uint   u_cam_pos_row;
layout(location = 10) uniform uint   u_cam_pos_slice;

vec3 index_to_unit_cube(uint i) {
    return vec3(notEqual(uvec3(0x287a, 0x02af, 0x31e3) & (1 << i), uvec3(0U)));
}

uint uint_divide(uint a, uint b) {
    return a / b;
}

uvec3 tile_index_to_tile_position(uint tile_index) {
    uint tile_slice = uint_divide(tile_index, u_num_tiles_in_slice);
    uint tiles_in_slice = tile_index - tile_slice * u_num_tiles_in_slice;
    uint tile_row = uint_divide(tiles_in_slice, u_num_columns);
    uint tile_column = tiles_in_slice - tile_row * u_num_columns; 

    if (u_back_to_front) {
        tile_column = u_num_columns - tile_column - 1;
        tile_row    = u_num_rows    - tile_row    - 1;
        tile_slice  = u_num_slices  - tile_slice  - 1;
    }

    tile_column = u_cam_pos_column + tile_column; 
    if (tile_column >= u_num_columns) {
        uint column_mul = uint_divide(tile_column, u_num_columns);
        tile_column = tile_column - column_mul * u_num_columns;
        tile_column = u_cam_pos_column - tile_column - 1;
    }

    tile_row = u_cam_pos_row + tile_row;
    if (tile_row >= u_num_rows) {
        uint row_mul = uint_divide(tile_row, u_num_rows);
        tile_row = tile_row - row_mul * u_num_rows;
        tile_row = u_cam_pos_row - tile_row - 1;
    }

    tile_slice = u_cam_pos_slice + tile_slice;
    if (tile_slice >= u_num_slices) {
        uint slice_mul = uint_divide(tile_slice, u_num_slices);
        tile_slice = tile_slice - slice_mul * u_num_slices;
        tile_slice = u_cam_pos_slice - tile_slice - 1;
    } 

    switch (u_slice_axis) {
        case 0: return uvec3(tile_slice,  tile_column, tile_row);   break;
        case 1: return uvec3(tile_column, tile_slice,  tile_row);   break;
        case 2: return uvec3(tile_column, tile_row,    tile_slice); break;
    }

    return uvec3(10000000);
}

out vec3 tile_color;
out vec3 tex_uvw;
out vec3 v_uvw;
out vec3 v_entry_position;

void main() {
    uint vdx = gl_VertexID;

    uint idx = gl_InstanceID;
    uvec3 tile_position = tile_index_to_tile_position(idx);

    float m = texelFetch(mask_texture, ivec3(tile_position), 0).x;
    if (m == 0.0) {
        tile_position = uvec3(1e9);
    }

    //if (8*tile_position.x > u_size.x/2) tile_position = uvec3(1e9);

    vec3 uvw = index_to_unit_cube(vdx);

    vec3 size = vec3(8.0);
    vec3 position = (tile_position + uvw) * size;

    v_entry_position = position;
    tex_uvw = position / u_size;
    v_uvw = uvw;

    gl_Position = u_PVM * vec4(position, 1.0);
}

/*
    Nx = 504,
    Ny = 344,
    Nz = 616,
*/