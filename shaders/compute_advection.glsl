#version 460 core

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

layout(location = 0) uniform ivec3 u_size;
layout(location = 1) uniform vec3 u_inverse_size;
layout(location = 2) uniform float u_dt;
layout(location = 3) uniform float u_voxel_size;
layout(location = 4) uniform float u_smoke_weight;

layout(binding = 0) uniform sampler3D u_velocity_x_texture;
layout(binding = 1) uniform sampler3D u_velocity_y_texture;
layout(binding = 2) uniform sampler3D u_velocity_z_texture;
layout(binding = 3) uniform sampler3D u_smoke_texture;
layout(binding = 4) uniform sampler3D u_mask_texture8;
layout(binding = 5) uniform sampler3D u_mask_texture4;

layout(binding = 0) writeonly uniform image3D u_velocity_x_image;
layout(binding = 1) writeonly uniform image3D u_velocity_y_image;
layout(binding = 2) writeonly uniform image3D u_velocity_z_image;
layout(binding = 3) writeonly uniform image3D u_smoke_image;
layout(binding = 4) writeonly uniform image3D u_temperature_image;

vec3 fetch_velocity(ivec3 gid) {
    float vx = texelFetch(u_velocity_x_texture, gid, 0).x;
    float vy = texelFetch(u_velocity_y_texture, gid, 0).x;
    float vz = texelFetch(u_velocity_z_texture, gid, 0).x;
    return vec3(vx, vy, vz);
}

vec3 sample_velocity(vec3 uvw) {
    float vx = texture(u_velocity_x_texture, uvw).x;
    float vy = texture(u_velocity_y_texture, uvw).x;
    float vz = texture(u_velocity_z_texture, uvw).x;
    return vec3(vx, vy, vz);
}

float fetch_texture(sampler3D s, ivec3 gid) {
    if (any(greaterThanEqual(uvec3(gid), uvec3(u_size)))) return 0.0;
    return texelFetch(s, gid, 0).x;
}

float sample_texture(sampler3D s, vec3 uvw) {
    return texture(s, uvw).x;
}





float sample_texture_cubic(sampler3D s, vec3 uvw, bool always_clamp_lower) {
    vec3 p = uvw * u_size;
    ivec3 start = ivec3(floor(p - 0.5));
    vec3 t = fract(p - 0.5);

    // interpolate
#if 1
    // 0th and 2nd order continuous
    vec3 wm = -1.0/6.0 * (t - 2) * (t - 1) * t          ;
    vec3 w0 = +1.0/2.0 * (t - 2) * (t - 1) *     (t + 1);
    vec3 w1 = -1.0/2.0 * (t - 2) *           t * (t + 1);
    vec3 w2 = +1.0/6.0 *           (t - 1) * t * (t + 1);
#else
    vec3 wm = -1.0/2.0*t*(t-1)*(t-1);
    vec3 w0 = +1.0/2.0*(t-1)*(3*t*t - 2*t - 2);
    vec3 w1 = -1.0/2.0*t*(3*t*t - 4*t - 1);
    vec3 w2 = +1.0/2.0*t*t*(t-1);
#endif
    float qmmm = fetch_texture(s, start + ivec3(-1, -1, -1));
    float q0mm = fetch_texture(s, start + ivec3(+0, -1, -1));
    float q1mm = fetch_texture(s, start + ivec3(+1, -1, -1));
    float q2mm = fetch_texture(s, start + ivec3(+2, -1, -1));

    float qm0m = fetch_texture(s, start + ivec3(-1, +0, -1));
    float q00m = fetch_texture(s, start + ivec3(+0, +0, -1));
    float q10m = fetch_texture(s, start + ivec3(+1, +0, -1));
    float q20m = fetch_texture(s, start + ivec3(+2, +0, -1));

    float qm1m = fetch_texture(s, start + ivec3(-1, +1, -1));
    float q01m = fetch_texture(s, start + ivec3(+0, +1, -1));
    float q11m = fetch_texture(s, start + ivec3(+1, +1, -1));
    float q21m = fetch_texture(s, start + ivec3(+2, +1, -1));

    float qm2m = fetch_texture(s, start + ivec3(-1, +2, -1));
    float q02m = fetch_texture(s, start + ivec3(+0, +2, -1));
    float q12m = fetch_texture(s, start + ivec3(+1, +2, -1));
    float q22m = fetch_texture(s, start + ivec3(+2, +2, -1));

    float qmm = wm.x * qmmm + w0.x * q0mm + w1.x * q1mm + w2.x * q2mm;
    float q0m = wm.x * qm0m + w0.x * q00m + w1.x * q10m + w2.x * q20m;
    float q1m = wm.x * qm1m + w0.x * q01m + w1.x * q11m + w2.x * q21m;
    float q2m = wm.x * qm2m + w0.x * q02m + w1.x * q12m + w2.x * q22m;

    float qmm0 = fetch_texture(s, start + ivec3(-1, -1, +0));
    float q0m0 = fetch_texture(s, start + ivec3(+0, -1, +0));
    float q1m0 = fetch_texture(s, start + ivec3(+1, -1, +0));
    float q2m0 = fetch_texture(s, start + ivec3(+2, -1, +0));

    float qm00 = fetch_texture(s, start + ivec3(-1, +0, +0));
    float q000 = fetch_texture(s, start + ivec3(+0, +0, +0));
    float q100 = fetch_texture(s, start + ivec3(+1, +0, +0));
    float q200 = fetch_texture(s, start + ivec3(+2, +0, +0));

    float qm10 = fetch_texture(s, start + ivec3(-1, +1, +0));
    float q010 = fetch_texture(s, start + ivec3(+0, +1, +0));
    float q110 = fetch_texture(s, start + ivec3(+1, +1, +0));
    float q210 = fetch_texture(s, start + ivec3(+2, +1, +0));

    float qm20 = fetch_texture(s, start + ivec3(-1, +2, +0));
    float q020 = fetch_texture(s, start + ivec3(+0, +2, +0));
    float q120 = fetch_texture(s, start + ivec3(+1, +2, +0));
    float q220 = fetch_texture(s, start + ivec3(+2, +2, +0));

    float qm0 = wm.x * qmm0 + w0.x * q0m0 + w1.x * q1m0 + w2.x * q2m0;
    float q00 = wm.x * qm00 + w0.x * q000 + w1.x * q100 + w2.x * q200;
    float q10 = wm.x * qm10 + w0.x * q010 + w1.x * q110 + w2.x * q210;
    float q20 = wm.x * qm20 + w0.x * q020 + w1.x * q120 + w2.x * q220;

    float qmm1 = fetch_texture(s, start + ivec3(-1, -1, +1));
    float q0m1 = fetch_texture(s, start + ivec3(+0, -1, +1));
    float q1m1 = fetch_texture(s, start + ivec3(+1, -1, +1));
    float q2m1 = fetch_texture(s, start + ivec3(+2, -1, +1));

    float qm01 = fetch_texture(s, start + ivec3(-1, +0, +1));
    float q001 = fetch_texture(s, start + ivec3(+0, +0, +1));
    float q101 = fetch_texture(s, start + ivec3(+1, +0, +1));
    float q201 = fetch_texture(s, start + ivec3(+2, +0, +1));

    float qm11 = fetch_texture(s, start + ivec3(-1, +1, +1));
    float q011 = fetch_texture(s, start + ivec3(+0, +1, +1));
    float q111 = fetch_texture(s, start + ivec3(+1, +1, +1));
    float q211 = fetch_texture(s, start + ivec3(+2, +1, +1));

    float qm21 = fetch_texture(s, start + ivec3(-1, +2, +1));
    float q021 = fetch_texture(s, start + ivec3(+0, +2, +1));
    float q121 = fetch_texture(s, start + ivec3(+1, +2, +1));
    float q221 = fetch_texture(s, start + ivec3(+2, +2, +1));

    float qm1 = wm.x * qmm1 + w0.x * q0m1 + w1.x * q1m1 + w2.x * q2m1;
    float q01 = wm.x * qm01 + w0.x * q001 + w1.x * q101 + w2.x * q201;
    float q11 = wm.x * qm11 + w0.x * q011 + w1.x * q111 + w2.x * q211;
    float q21 = wm.x * qm21 + w0.x * q021 + w1.x * q121 + w2.x * q221;

    float qmm2 = fetch_texture(s, start + ivec3(-1, -1, +2));
    float q0m2 = fetch_texture(s, start + ivec3(+0, -1, +2));
    float q1m2 = fetch_texture(s, start + ivec3(+1, -1, +2));
    float q2m2 = fetch_texture(s, start + ivec3(+2, -1, +2));

    float qm02 = fetch_texture(s, start + ivec3(-1, +0, +2));
    float q002 = fetch_texture(s, start + ivec3(+0, +0, +2));
    float q102 = fetch_texture(s, start + ivec3(+1, +0, +2));
    float q202 = fetch_texture(s, start + ivec3(+2, +0, +2));

    float qm12 = fetch_texture(s, start + ivec3(-1, +1, +2));
    float q012 = fetch_texture(s, start + ivec3(+0, +1, +2));
    float q112 = fetch_texture(s, start + ivec3(+1, +1, +2));
    float q212 = fetch_texture(s, start + ivec3(+2, +1, +2));

    float qm22 = fetch_texture(s, start + ivec3(-1, +2, +2));
    float q022 = fetch_texture(s, start + ivec3(+0, +2, +2));
    float q122 = fetch_texture(s, start + ivec3(+1, +2, +2));
    float q222 = fetch_texture(s, start + ivec3(+2, +2, +2));

    float qm2 = wm.x * qmm2 + w0.x * q0m2 + w1.x * q1m2 + w2.x * q2m2;
    float q02 = wm.x * qm02 + w0.x * q002 + w1.x * q102 + w2.x * q202;
    float q12 = wm.x * qm12 + w0.x * q012 + w1.x * q112 + w2.x * q212;
    float q22 = wm.x * qm22 + w0.x * q022 + w1.x * q122 + w2.x * q222;

    float qm = wm.y * qmm + w0.y * q0m + w1.y * q1m + w2.y * q2m;
    float q0 = wm.y * qm0 + w0.y * q00 + w1.y * q10 + w2.y * q20;
    float q1 = wm.y * qm1 + w0.y * q01 + w1.y * q11 + w2.y * q21;
    float q2 = wm.y * qm2 + w0.y * q02 + w1.y * q12 + w2.y * q22;

    float q  = wm.z * qm + w0.z * q0 + w1.z * q1 + w2.z * q2;

    if (true) {
        float max_q =                            max(max(max(q000, q100), max(q010, q110)), max(max(q001, q101), max(q011, q111)));
        float min_q = always_clamp_lower ? 0.0 : min(min(min(q000, q100), min(q010, q110)), min(min(q001, q101), min(q011, q111)));
        return clamp(q, min_q, max_q);
    } else {
        return always_clamp_lower ? max(q, float(0.0)) : q;
    }
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);

    vec3 v0 = fetch_velocity(gid);
    vec3 v1 = sample_velocity((gid + 0.5 - 0.5*v0 * u_dt) * u_inverse_size);
    vec3 v2 = sample_velocity((gid + 0.5 - 0.5*v1 * u_dt) * u_inverse_size);
    vec3 v3 = sample_velocity((gid + 0.5 - 1.0*v2 * u_dt) * u_inverse_size);
    vec3 v = (v0 + 2*v1 + 2*v2 + v3) / 6.0;
    
    vec3 uvw = (gid + 0.5 - v * u_dt) * u_inverse_size;

    float mask = texture(u_mask_texture4, uvw).x; 

    vec3 velocity;
    if (true) {
        velocity = sample_velocity(uvw);
    } else {
        velocity.x = sample_texture_cubic(u_velocity_x_texture, uvw, false);
        velocity.y = sample_texture_cubic(u_velocity_y_texture, uvw, false);
        velocity.z = sample_texture_cubic(u_velocity_z_texture, uvw, false);
    }
    float smoke;
    if (mask > 0.0) {
        smoke = sample_texture_cubic(u_smoke_texture, uvw, true);
        //smoke = sample_texture(u_smoke_texture, uvw);
    } else {
        smoke = 0.0;
    }

    ivec3 s = textureSize(u_smoke_texture, 0);
    int mins = min(s.x, min(s.y, s.z));

    if (all(greaterThanEqual(gid.xy, s.xy/2+ivec2(0, 2*s.y/4)-int(2.5/u_voxel_size)))) {
        if (all(lessThan(gid.xy,     s.xy/2+ivec2(0, 2*s.y/4)+int(2.5/u_voxel_size)))) {
            velocity.yz += vec2(-2.0, 0.0) / u_voxel_size;
        } 
    } 
    velocity -= vec3(0.0, 0.0, smoke * u_smoke_weight); 

    imageStore(u_velocity_x_image,  gid, vec4(velocity.x));
    imageStore(u_velocity_y_image,  gid, vec4(velocity.y));
    imageStore(u_velocity_z_image,  gid, vec4(velocity.z));
    imageStore(u_smoke_image,       gid, vec4(smoke));
}