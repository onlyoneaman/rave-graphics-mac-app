#include "Common.metal"

// Fullscreen triangle VS
vertex VSOut fullscreenVS(uint vid [[vertex_id]]) {
    float2 pos[3] = { float2(-1.0,-1.0), float2(3.0,-1.0), float2(-1.0,3.0) };
    float2 p = pos[vid];
    VSOut o;
    o.pos = float4(p, 0.0, 1.0);
    o.uv  = p * 0.5 + 0.5;
    return o;
}

fragment float4 blitFrag(
    VSOut in [[stage_in]],
    texture2d<float> src [[texture(0)]],
    sampler s [[sampler(0)]]
){
    return float4(src.sample(s, in.uv).rgb, 1.0);
}

