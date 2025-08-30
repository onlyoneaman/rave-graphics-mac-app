//
//  Organic.metal
//  RaveVizs
//
//  Created by Aman Kumar on 31/08/25.
//

#include "Common.metal"
#include <metal_stdlib>
using namespace metal;

// Noise basis (IQ)
inline float hash(float n) {
    return fract(sin(n)*43758.5453);
}

constant float3x3 m = float3x3(
    float3(0.00, 0.80, 0.60),
    float3(-0.80, 0.36, -0.48),
    float3(-0.60, -0.48, 0.64)
);

inline float noise(float3 x) {
    float3 p = floor(x);
    float3 f = fract(x);
    f = f*f*(3.0-2.0*f);
    float n = p.x + p.y*57.0 + 113.0*p.z;

    float res =
        mix(mix(mix(hash(n+0.0),   hash(n+1.0), f.x),
                mix(hash(n+57.0),  hash(n+58.0), f.x), f.y),
            mix(mix(hash(n+113.0), hash(n+114.0), f.x),
                mix(hash(n+170.0), hash(n+171.0), f.x), f.y), f.z);
    return res;
}

inline float fbm(float3 p) {
    float f = 0.0;
    f  = 0.5000*noise(p); p = m*p*2.02;
    f += 0.2500*noise(p); p = m*p*2.03;
    f += 0.1250*noise(p); p = m*p*2.01;
    f += 0.0625*noise(p);
    return f;
}

inline float snoise(float3 x) { return 2.0*noise(x)-1.0; }

inline float sfbm(float3 p) {
    float f=0.0;
    f  = 0.5000*snoise(p); p = m*p*2.02;
    f += 0.2500*snoise(p); p = m*p*2.03;
    f += 0.1250*snoise(p); p = m*p*2.01;
    f += 0.0625*snoise(p);
    return f;
}

inline float3 sfbm3(float3 p) {
    return float3(sfbm(p), sfbm(p-float3(327.67,0,0)), sfbm(p+float3(327.67,0,0)));
}


// --- Fragment entry ---
fragment float4 scene_organic(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> tex0 [[texture(0)]],
    sampler s [[sampler(0)]]
) {
    float2 res = u.res;
    float2 w = in.uv * res;

    // ray setup (similar to your GLSL)
    float4 p = float4(w,0,1)/float4(res.y,res.y,res.x,res.y) - 0.5;
    p.x -= 0.4;
    float4 d = p;
    p.z += 10.0;

    float4 o = float4(0.0,0.2,0.0,0.0); // bg green
    float x = 1e9;

    for (float i=1.0; i>0.0; i-=0.01) {
        if (o.x >= 0.99) break;

        float4 t = p;

        // apply some noise displacement
        t.xyz += sfbm3(t.xyz/2.0 + float3(0.5*u.time,0,0)) *
                 (0.6+8.0*(0.5-0.5*cos(u.time/16.0)));

        // ✅ sample with normalized coords (use fract to stay in [0,1])
        float2 texCoord = fract(t.xy);
        float4 ccol = 5.0 * tex0.sample(s, texCoord).rrrr;

        float x1 = length(t.xyz)-7.0;
        x = max(abs(fmod(length(t.xyz),1.0)-0.5), x1);

        if (x < 0.01) {
            o += (1.0-o)*0.2*mix(float4(0,0.2,0,0), ccol, i*i);
            x = 0.1;
        }

        p += d*x;
        if (p.z < 0.0) break;
    }

    return float4(o.rgb,1.0);
}

