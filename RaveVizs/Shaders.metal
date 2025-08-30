//
//  Shaders.swift
//  RaveVizs
//
//  Created by Aman Kumar on 31/08/25.
//


#include <metal_stdlib>
using namespace metal;

// Fullscreen triangle without a vertex buffer.
struct VSOut {
    float4 pos [[position]];
    float2 uv;
};

vertex VSOut fullscreenVS(uint vid [[vertex_id]]) {
    float2 pos[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    float2 p = pos[vid];
    VSOut o;
    o.pos = float4(p, 0.0, 1.0);
    o.uv  = p * 0.5 + 0.5; // map [-1,1] → [0,1]
    return o;
}

struct Uniforms {
    float time;
    float2 res;
    float bass, mid, high;
    float fade;
};

// ---------- Rave-style feedback fragment ----------
// prevTex: last frame's low-res buffer; we mix a new color with a slight wobble.
fragment float4 feedbackFrag(
    VSOut in                        [[stage_in]],
    constant Uniforms& u            [[buffer(0)]],
    texture2d<float> prevTex        [[texture(0)]],
    sampler s                       [[sampler(0)]]
) {
    float2 uv = in.uv;

    // Normalize to square coordinates for symmetric patterns
    float2 p = (uv * u.res) / min(u.res.x, u.res.y);
    p = abs(fract(p + 0.5) - 0.5); // kaleidoscope-like fold

    // Wobble amount (time-based); tweak for taste
    float wob = 0.03 * sin(6.2831 * (p.x + p.y) + u.time * 2.0);

    // Audio-reactive color (currently bass/mid/high are 0, wire later)
    float3 col = 0.5 + 0.5 * float3(
        sin(10.0 * p.x + u.time * 2.0 + u.bass * 3.0),
        sin(10.0 * p.y + u.time * 1.7 + u.mid  * 3.0),
        sin(10.0 * (p.x + p.y) + u.time * 1.3 + u.high * 3.0)
    );

    // Feedback trail from previous frame
    float3 trail = prevTex.sample(s, uv + wob).rgb * 0.96;

    // Mix fresh color into the trail
    float3 outColor = mix(trail, col, 0.24 * u.fade);

    return float4(outColor, 1.0);
}

// ---------- Simple blit fragment to present low-res to screen ----------
fragment float4 blitFrag(
    VSOut in                 [[stage_in]],
    texture2d<float> src     [[texture(0)]],
    sampler s                [[sampler(0)]]
) {
    return float4(src.sample(s, in.uv).rgb, 1.0);
}
