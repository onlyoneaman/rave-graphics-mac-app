//
//  Commons.metal
//  RaveVizs
//
//  Created by Aman Kumar on 31/08/25.
//

#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 pos [[position]];
    float2 uv;
};

struct Uniforms {
    float time;
    float2 res;
    float bass, mid, high;
    float fade;
};

// Helpers
static inline float2 centeredSquare(float2 uv, float2 res) {
    float2 p = uv - 0.5;
    p.x *= res.x / res.y;
    return p * 2.0;
}

static inline float2 normSquare(float2 uv, float2 res) {
    return (uv * res) / min(res.x, res.y);
}

static inline float2 aspect_fix(float2 p, float2 res) {
    p.x *= res.x / res.y;        // keep shapes round
    return p;
}

static inline float3 cos_palette(float t, float3 a, float3 b, float3 c, float3 d) {
    // iq-style cosine palette
    return a + b * cos(6.28318f * (c * t + d));
}

inline float2 rot(float2 v, float a) {
    float c = cos(a), s = sin(a);
    return float2(c*v.x - s*v.y, s*v.x + c*v.y);
}
