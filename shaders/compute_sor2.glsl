#version 460 core

layout(local_size_x = 5, local_size_y = 10, local_size_z = 10) in;

layout(location = 0) uniform ivec3 u_size;
layout(location = 1) uniform float u_omega;

layout(binding = 0) uniform sampler3D u_pressure_texture;
layout(binding = 1) uniform sampler3D u_divergence_texture;

layout(binding = 0) writeonly uniform image3D u_pressure_image;

float fetch(sampler3D s, ivec3 gid) {
    if (any(greaterThanEqual(uvec3(gid), uvec3(u_size)))) return 0.0;
    return texelFetch(s, gid, 0).x;
}

shared float s_p[10][10][9];

void main() {
    ivec3 wid = ivec3(gl_WorkGroupID);
    ivec3 lid = ivec3(gl_LocalInvocationID);
    lid.x = 2*lid.x + 1;
    lid -= 1;
    ivec3 gid = 8*wid + lid;

    float divergence = fetch(u_divergence_texture, gid);

    float p_mmm = fetch(u_pressure_texture, gid + ivec3(-1, -1, -1));
    float p_pmm = fetch(u_pressure_texture, gid + ivec3(+1, -1, -1));
    float p_mpm = fetch(u_pressure_texture, gid + ivec3(-1, +1, -1));
    float p_ppm = fetch(u_pressure_texture, gid + ivec3(+1, +1, -1));
    float p_000 = fetch(u_pressure_texture, gid + ivec3( 0,  0,  0));
    float p_mmp = fetch(u_pressure_texture, gid + ivec3(-1, -1, +1));
    float p_pmp = fetch(u_pressure_texture, gid + ivec3(+1, -1, +1));
    float p_mpp = fetch(u_pressure_texture, gid + ivec3(-1, +1, +1));
    float p_ppp = fetch(u_pressure_texture, gid + ivec3(+1, +1, +1));

    float p = 4.0 * divergence;
    p += p_ppp;
    p += p_ppm;
    p += p_pmp;
    p += p_pmm;
    p += p_mpp;
    p += p_mpm;
    p += p_mmp;
    p += p_mmm;
    p /= 8.0;

    p = mix(p_000, p, u_omega);

    if (any(greaterThanEqual(uvec3(gid-1), uvec3(u_size-1)))) p = 0.0;

    s_p[1+lid.z][1+lid.y][lid.x] = p;

    memoryBarrierShared();
    barrier();

    uint lindex = gl_LocalInvocationIndex;
    if (lindex < 256) {
        ivec3 lid = ivec3(uvec3(bitfieldExtract(lindex, 0, 2), bitfieldExtract(lindex, 2, 3), bitfieldExtract(lindex, 5, 3)));
        lid.x = 2*lid.x + 1;
        ivec3 gid = 8*wid + lid;

        float divergence = texelFetch(u_divergence_texture, gid, 0).x;
        float p_000 = fetch(u_pressure_texture, gid + ivec3(0, 0, 0));

        float p_mmm = s_p[1+lid.z-1][1+lid.y-1][lid.x-1];
        float p_pmm = s_p[1+lid.z-1][1+lid.y-1][lid.x+1];
        float p_mpm = s_p[1+lid.z-1][1+lid.y+1][lid.x-1];
        float p_ppm = s_p[1+lid.z-1][1+lid.y+1][lid.x+1];
        float p_mmp = s_p[1+lid.z+1][1+lid.y-1][lid.x-1];
        float p_pmp = s_p[1+lid.z+1][1+lid.y-1][lid.x+1];
        float p_mpp = s_p[1+lid.z+1][1+lid.y+1][lid.x-1];
        float p_ppp = s_p[1+lid.z+1][1+lid.y+1][lid.x+1];

        float p = 4.0 * divergence;
        p += p_ppp;
        p += p_ppm;
        p += p_pmp;
        p += p_pmm;
        p += p_mpp;
        p += p_mpm;
        p += p_mmp;
        p += p_mmm;
        p /= 8.0;

        p = mix(p_000, p, u_omega);
        float p2 = s_p[1+lid.z][1+lid.y][lid.x-1];

        if (any(equal(gid, ivec3(0)))) p = 0.0;
        imageStore(u_pressure_image, gid, vec4(p));
        imageStore(u_pressure_image, gid+ivec3(-1, 0, 0), vec4(p2));
    }
}



/*

Red:

    Capital R are cells updated (written to global memory).

    Lower case b cells are read from R cells (read from global memory, or cached from shared memory).

      b       b       b       b       b       
        ┌───────────────────────────────┐
      b │ R   b   R   b   R   b   R   b │ 
        │                               │ 
      b │ R   b   R   b   R   b   R   b │     
        │                               │ 
      b │ R   b   R   b   R   b   R   b │ 
        │                               │ 
      b │ R   b   R   b   R   b   R   b │     
        │                               │ 
      b │ R   b   R   b   R   b   R   b │ 
        │                               │ 
      b │ R   b   R   b   R   b   R   b │     
        │                               │ 
      b │ R   b   R   b   R   b   R   b │ 
        │                               │ 
      b │ R   b   R   b   R   b   R   b │     
        └───────────────────────────────┘ 
      b       b       b       b       b

Black:

    Capital B cells are updated (written to global memory).

    Lower case r cells are read from B cells (read from global memory, or cached from shared memory).

          r       r       r       r       r      
        ┌───────────────────────────────┐   
        │ r   B   r   B   r   B   r   B │ r  
        │                               │    
        │ r   B   r   B   r   B   r   B │ r      
        │                               │    
        │ r   B   r   B   r   B   r   B │ r  
        │                               │    
        │ r   B   r   B   r   B   r   B │ r      
        │                               │    
        │ r   B   r   B   r   B   r   B │ r  
        │                               │    
        │ r   B   r   B   r   B   r   B │ r      
        │                               │    
        │ r   B   r   B   r   B   r   B │ r  
        │                               │    
        │ r   B   r   B   r   B   r   B │ r      
        └───────────────────────────────┘    
          r       r       r       r       r 



Red + Black:

    Sub-pass 1:
    
        Capital R cells are updated (written to shared memory).

        Lower case b cells are read from R cells (read from global memory, or cached from shared memory)

      b       b       b       b       b       b

      b   R   b   R   b   R   b   R   b   R   b      
        ┌───────────────────────────────┐       
      b │ R   b   R   b   R   b   R   b │ R   b  
        │                               │        
      b │ R   b   R   b   R   b   R   b │ R   b      
        │                               │        
      b │ R   b   R   b   R   b   R   b │ R   b  
        │                               │        
      b │ R   b   R   b   R   b   R   b │ R   b      
        │                               │        
      b │ R   b   R   b   R   b   R   b │ R   b  
        │                               │        
      b │ R   b   R   b   R   b   R   b │ R   b      
        │                               │        
      b │ R   b   R   b   R   b   R   b │ R   b  
        │                               │        
      b │ R   b   R   b   R   b   R   b │ R   b      
        └───────────────────────────────┘        
      b   R   b   R   b   R   b   R   b   R   b      

      b       b       b       b       b       b


      Sub-pass 2:

        Capital B cells are updated (written to global memory).

        Upper case R cells are read from B cells (read from shared memory)

        Lower case b values outside the bbox are no longer used
        and are marked by *

      *       *       *       *       *       *

      *   R   *   R   *   R   *   R   *   R   *      
        ┌───────────────────────────────┐       
      * │ R   B   R   B   R   B   R   B │ R   *  
        │                               │        
      * │ R   B   R   B   R   B   R   B │ R   *      
        │                               │        
      * │ R   B   R   B   R   B   R   B │ R   *  
        │                               │        
      * │ R   B   R   B   R   B   R   B │ R   *      
        │                               │        
      * │ R   B   R   B   R   B   R   B │ R   *  
        │                               │        
      * │ R   B   R   B   R   B   R   B │ R   *      
        │                               │        
      * │ R   B   R   B   R   B   R   B │ R   *  
        │                               │        
      * │ R   B   R   B   R   B   R   B │ R   *      
        └───────────────────────────────┘        
      *   R   *   R   *   R   *   R   *   R   *      

      *       *       *       *       *       *
*/

