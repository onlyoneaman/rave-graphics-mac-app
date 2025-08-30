#include "Common.metal"
#include <metal_stdlib>
using namespace metal;

// GLSL-style hash for star field
inline float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

// Fragment entry (auto-picked by prefix "scene_")
fragment float4 scene_spiral_cosmic(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    // centered, aspect-correct coords
    float2 p = in.uv * 2.0 - float2(1.0, 1.0);
    p.x *= u.res.x / u.res.y;

    // polar
    float angle  = atan2(p.y, p.x);
    float radius = length(p);

    // spiral pattern
    float spiral = sin(radius * 20.0 - angle * 8.0 + u.time * 2.0);

    // cosmic distortion
    float distortion = sin(radius * 10.0 + u.time * 1.5) * cos(angle * 6.0 + u.time * 0.8);
    spiral += distortion * 0.3;

    // star field (wrap to [0,1] before hashing)
    float2 starCoord = p * 50.0;
    float stars = 0.0;
    for (int i = 0; i < 3; ++i) {
        float2 offset = float2(float(i) * 0.5, float(i) * 0.3);
        // keep coords in [0,1] so hash is nicely distributed
        float2 sc = fract(starCoord + offset + u.time * 0.1);
        stars += hash(sc) * 0.5;
    }
    stars = smoothstep(0.95, 1.0, stars);

    // palette
    const float3 spaceColor1 = float3(0.1, 0.0, 0.3); // deep purple
    const float3 spaceColor2 = float3(0.0, 0.2, 0.5); // deep blue
    const float3 spaceColor3 = float3(0.5, 0.0, 0.8); // bright purple

    // animated mixes
    float colorShift = sin(u.time * 0.3) * 0.5 + 0.5;
    float3 finalColor = mix(spaceColor1, spaceColor2, colorShift);
    finalColor = mix(finalColor, spaceColor3, sin(u.time * 0.5) * 0.5 + 0.5);

    // apply spiral intensity
    float spiralIntensity = smoothstep(-0.5, 0.5, spiral);
    finalColor *= spiralIntensity * 2.0;

    // add stars
    finalColor += stars * float3(1.0, 0.8, 0.6) * 3.0;

    // nebula
    float nebula = sin(radius * 8.0 + u.time * 1.0) * cos(angle * 4.0 + u.time * 0.5);
    nebula = smoothstep(-0.3, 0.3, nebula);
    finalColor += nebula * float3(0.3, 0.1, 0.5) * 0.5;

    // pulse
    float pulse = sin(u.time * 2.0) * 0.2 + 0.8;
    finalColor *= pulse;

    return float4(finalColor, 1.0);
}
