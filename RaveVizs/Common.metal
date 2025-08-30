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
