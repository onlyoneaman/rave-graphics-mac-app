#include "Common.metal"

// --- tunnel shade helper ---
inline float4 scene_tunnel_shade(float2 uv, float t, float2 res) {
    // center coords and correct aspect
    float2 p = uv * 2.0 - float2(1.0, 1.0);
    p.x *= res.x / res.y;

    float z = t * 1.5;
    float r = length(p);
    float a = atan2(p.y, p.x);

    float stripes = sin(12.0 * a + z * 3.0) * 0.5 + 0.5;
    float depth   = 1.0 / (0.2 + r * 1.2);

    float3 base = float3(0.5) + 0.5 * sin(float3(0.0, 2.0, 4.0) + z);

    return float4(base * stripes * depth, 1.0);
}

// --- fragment entry point (discovered by prefix "scene_") ---
fragment float4 scene_tunnel(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    return scene_tunnel_shade(in.uv, u.time, u.res);
}
