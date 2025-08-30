#include "Common.metal"
#include <metal_stdlib>
using namespace metal;

constant float ox = 1.3;
constant float oz = 1.5;

// rotation Z
inline float3x3 rotz(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(float3(c,-s,0), float3(s,c,0), float3(0,0,1));
}

// Hex prism SDF
inline float sdHexPrism(float3 p, float2 h) {
    p = abs(p);
    const float3 k = float3(-0.8660254, 0.5, 0.57735);
    p.xy -= 2.0 * min(dot(k.xy, p.xy), 0.0) * k.xy;
    float2 d = float2(
        length(p.xy - float2(clamp(p.x, -k.z*h.x, k.z*h.x), h.x)) * sign(p.y - h.x),
        p.z - h.y
    );
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

inline void common_map(float3 p, float time, float var_z,
                       thread float &df0, thread float &df1) {
    p = rotz(p.z * 0.05) * p;
    p.y = 5.0 + 5.0 * var_z - abs(p.y);

    float wave = sin(length(p.xz) * 0.25 - time * 1.5);
    df0 = abs(p.y + wave) - 1.0;

    float2 hex_size = float2(0.25 + p.y * 0.25, 10.0);

    float3 q0 = p;
    q0.x = fmod(q0.x - ox, ox + ox) - ox;
    q0.z = fmod(q0.z - oz*0.5, oz) - oz*0.5;
    float hex0 = sdHexPrism(q0.xzy, hex_size) - 0.2;

    float3 q1 = p;
    q1.x = fmod(q1.x, ox + ox) - ox;
    q1.z = fmod(q1.z, oz) - oz*0.5;
    float hex1 = sdHexPrism(q1.xzy, hex_size) - 0.2;

    df1 = min(hex0, hex1);
}

inline float smax(float a, float b, float k) {
    float h = clamp(0.5 + 0.5*(b-a)/k, 0.0, 1.0);
    return mix(b, a, h) - k*h*(1.0-h);
}

inline float map(float3 p, float time, float var_z) {
    float df0, df1;
    common_map(p, time, var_z, df0, df1);
    return smax(df0, df1, 0.1);
}

inline float matid(float3 p, float time, float var_z) {
    float df0, df1;
    common_map(p, time, var_z, df0, df1);
    return (df0 > df1) ? 1.0 : 0.0;
}

inline float3 getNormal(float3 p, float time, float var_z) {
    const float3 e = float3(0.1,0,0);
    return normalize(float3(
        map(p+e, time, var_z) - map(p-e, time, var_z),
        map(p+e.yxz, time, var_z) - map(p-e.yxz, time, var_z),
        map(p+e.zyx, time, var_z) - map(p-e.zyx, time, var_z)
    ));
}

// Perspective camera
inline float3 cam(float2 uv, float3 ro, float3 cv, float fov) {
    float3 cu = normalize(float3(0,1,0));
    float3 z = normalize(cv-ro);
    float3 x = normalize(cross(cu,z));
    float3 y = cross(z,x);
    return normalize(z + fov*uv.x*x + fov*uv.y*y);
}

// ---- Fragment entry ----
fragment float4 scene_hextunnel(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> tex0 [[texture(0)]],
    sampler s [[sampler(0)]]
) {
    float2 si = u.res;
    float2 uvc = (2.0*in.uv*si - si)/si.y;

    // camera
    float3 ro = float3(0.0, 0.0, u.time * 20.0 + 5.0);
    float3 cv = ro + float3(0.0, 0.0, 4.0);
    float3 rd = cam(uvc, ro, cv, 0.4);

    float3 col = float3(0);
    float3 p = ro;
    float sdist = 1.0;
    float d = 0.0;
    const float md = 70.0;
    float var_z = 0.0;

    for (int i=0; i<200; i++) {
        if (d*d/sdist > 1e6 || d > md) break;
        var_z = sin(p.z*0.1)*0.5+0.5;
        sdist = map(p, u.time, var_z);
        d += sdist * 0.5;
        p = ro + rd * d;
    }

    if (d < md) {
        float3 n = getNormal(p, u.time, var_z);
        float3 lp = float3(0,5,0);
        float3 ld = normalize(lp - p);

        float diff = pow(dot(n, ld) * .5 + .5, 2.0);

        if (matid(p, u.time, var_z) > 0.5) {
            col = mix(float3(1.5,1.0,0.0), float3(2.0,2.0,2.0), var_z);
        } else {
            col = float3(1.0,0.85,0.0)*0.75;
        }

        // reflection sample (fake planar mapping)
        float3 rdir = reflect(rd,n);
        float2 refuv = rdir.xy*0.5+0.5;
        col *= tex0.sample(s, refuv).rgb;

        col += diff*0.5;
    }

    col = clamp(col, 0.0, 1.0);
    col *= exp(1.0-d*d*0.001);
    return float4(col,1);
}

