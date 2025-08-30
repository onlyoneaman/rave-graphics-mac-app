#include "Common.metal"

// Scene A
fragment float4 feedbackFragA(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> prevTex [[texture(0)]],
    sampler s [[sampler(0)]]
){
    float2 uv = in.uv;
    float2 p  = centeredSquare(uv, u.res);
    float2 f  = abs(fract(p + 0.5) - 0.5);
    float wob = 0.02 * sin(6.2831*(f.x+f.y) + u.time*2.0);
    float3 col = 0.5 + 0.5 * float3(
        sin(12.0*f.x + u.time*2.0 + u.bass*2.5),
        sin(11.0*f.y + u.time*1.7 + u.mid *2.5),
        sin(10.0*(f.x+f.y) + u.time*1.3 + u.high*2.5)
    );
    float3 trail = prevTex.sample(s, uv + wob).rgb * 0.965;
    return float4(mix(trail, col, 0.25 * u.fade), 1.0);
}

// Scene B
fragment float4 feedbackFragB(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> prevTex [[texture(0)]],
    sampler s [[sampler(0)]]
){
    float2 uv = in.uv;
    float2 p  = centeredSquare(uv, u.res);
    float r = length(p), a = atan2(p.y, p.x);
    float wob = 0.02 * sin(8.0*a + u.time*1.8);
    float3 col = 0.5 + 0.5 * float3(
        sin(20.0*r + u.time*2.0),
        sin(18.0*r + u.time*1.4),
        sin(16.0*r + u.time*1.1)
    );
    float3 trail = prevTex.sample(s, uv + wob).rgb * 0.96;
    return float4(mix(trail, col, 0.22 * u.fade), 1.0);
}

// Scene C
fragment float4 feedbackFragC(
    VSOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> prevTex [[texture(0)]],
    sampler s [[sampler(0)]]
){
    float2 uv = in.uv;
    float2 p  = centeredSquare(uv, u.res);
    float2 q  = p + 0.03 * sin(float2(0.0,1.0)*u.time + float2(p.y, p.x)*8.0);
    float3 col = 0.5 + 0.5 * float3(
        sin(9.0*q.x + u.time*2.4),
        sin(9.0*q.y + u.time*1.6),
        sin(9.0*(q.x+q.y) + u.time*1.2)
    );
    float wob = 0.018 * sin(6.2831*(q.x+q.y) + u.time*2.1);
    float3 trail = prevTex.sample(s, uv + wob).rgb * 0.965;
    return float4(mix(trail, col, 0.24 * u.fade), 1.0);
}
