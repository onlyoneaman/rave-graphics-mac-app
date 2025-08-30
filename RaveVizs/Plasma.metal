#include "Common.metal"

// --- core shade() in Metal ---
inline float4 plasma_shade(float2 uv, float t, float2 res) {
    // center & aspect-correct
    float2 p = uv * 2.0 - float2(1.0, 1.0);
    p.x *= res.x / res.y;

    float v = 0.0;
    v += sin((p.x + t * 0.9) * 6.0);
    v += sin((p.y + t * 1.1) * 7.0);
    v += sin((p.x + p.y + t * 1.3) * 5.0);
    v += sin(length(p) * 8.0 - t * 2.0);
    v *= 0.25;

    // rgb via cosine palette (2π/3 offsets ≈ 2.094, 4.188)
    float3 col = 0.5 + 0.5 * cos(float3(0.0, 2.094, 4.188) + v * 3.0 + t * 0.7);
    return float4(col, 1.0);
}

fragment float4 scene_plasma(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    return plasma_shade(in.uv, u.time, u.res);
}
