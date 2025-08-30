#include "Common.metal"

struct ShaderInputs {
    float time;
    float2 resolution;
};

fragment float4 scene_fragment_main(
    float2 uv [[user(uv)]],
    const device ShaderInputs& inputs [[buffer(0)]]
) {
    float time = inputs.time;
    float2 resolution = inputs.resolution;

    float2 p = uv * 2.0 - 1.0;
    p.x *= resolution.x / resolution.y;

    // Create morphing maze pattern
    float scale = 15.0 + sin(time * 0.5) * 5.0;
    float2 maze = fract(p * scale + time * 0.1);

    // Create geometric patterns
    float lines1 = step(0.1, maze.x) * step(0.1, 1.0 - maze.x);
    float lines2 = step(0.1, maze.y) * step(0.1, 1.0 - maze.y);
    float pattern = max(lines1, lines2);

    // Add circular distortions
    float circles = sin(length(p) * 20.0 - time * 5.0) * 0.5 + 0.5;
    pattern = mix(pattern, circles, 0.3);

    // Create rainbow color palette
    float hue = time * 0.2 + length(p) * 2.0;
    float3 color = 0.5 + 0.5 * cos(hue + float3(0.0, 2.0, 4.0));

    // Add neon glow
    float glow = smoothstep(0.0, 0.1, pattern);
    color *= glow * 3.0;

    // Add breathing effect
    float breath = sin(time * 2.0) * 0.2 + 0.8;
    color *= breath;

    // Add some noise for texture
    float noise = fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    color += noise * 0.1;

    return float4(color, 1.0);
}
