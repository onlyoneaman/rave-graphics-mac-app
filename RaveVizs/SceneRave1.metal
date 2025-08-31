#include "Common.metal"

struct FragIn {
    float4 position [[position]];
};

inline float2 kaleido(float2 p, float sides) {
    float a = atan2(p.y, p.x);
    float r = length(p);
    float pi = 3.14159265f;
    float k = pi / sides;
    a = fmod(fabs(a), 2.0f * k);
    a = (a > k) ? (2.0f * k - a) : a;
    return float2(cos(a), sin(a)) * r;
}

fragment float4 scene_RaveTunnel(FragIn in [[stage_in]],
                                 constant Uniforms& u [[buffer(0)]],
                                 texture2d<float> prevTex [[texture(0)]],
                                 sampler samp [[sampler(0)]])
{
    float2 uv01 = in.position.xy / u.res;
    float2 p = (in.position.xy - 0.5f * u.res) / u.res.y;

    float kick = clamp(u.bass, 0.0f, 1.5f);
    float snare = clamp(u.mid * 0.8f, 0.0f, 1.2f);
    float hat = clamp(u.high * 0.6f, 0.0f, 1.0f);

    float t = u.time;
    float spin = 0.3f * t + 0.6f * kick;
    float cs = cos(spin), ss = sin(spin);
    p = float2(p.x * cs - p.y * ss, p.x * ss + p.y * cs);
    p *= 0.88f + 0.12f * (0.6f + 0.4f * kick);

    float sides = mix(5.0f, 8.0f, saturate(0.5f + 0.5f * sin(t * 0.37f + snare)));
    p = kaleido(p, sides);

    float r = length(p) + 1e-3f;
    float a = atan2(p.y, p.x);

    float bands = 10.0f + 6.0f * (0.4f + 0.6f * kick);
    float swirl = 3.0f + 2.0f * snare;
    float wave = sin(bands / r - swirl * a - 1.8f * t);

    float flowMag = 0.0035f + 0.006f * hat;
    float2 flow = float2(sin(4.0f * a + t), cos(3.0f * a - 1.3f * t)) * flowMag;
    float2 prevUV = clamp(uv01 + flow, 0.0f, 1.0f);
    float3 feedback = prevTex.sample(samp, prevUV).rgb;

    float hue = wave * 0.5f + 0.5f;
    float3 col = cos_palette(hue,
                             float3(0.5, 0.5, 0.5),
                             float3(0.5, 0.5, 0.5),
                             float3(1.0, 1.0, 1.0),
                             float3(0.00, 0.33, 0.67));

    float vign = smoothstep(1.2f, 0.2f, r);
    float rim = pow(saturate(1.0f - r), 3.0f);
    col *= vign;
    col += rim * (0.3f + 0.5f * hat);

    float bpm = 128.0f;
    float beatT = fmod(t * bpm / 60.0f, 1.0f);
    float strobe = smoothstep(0.02f, 0.0f, beatT) * (0.4f + 0.6f * kick);
    col += strobe;

    float persistence = 0.78f + 0.12f * kick;
    float3 outCol = mix(col, feedback, persistence);

    outCol *= saturate(u.fade);
    outCol = outCol / (1.0f + outCol);

    return float4(outCol, 1.0f);
}

fragment float4 scene_NeonRibbons(FragIn in [[stage_in]],
                                  constant Uniforms& u [[buffer(0)]],
                                  texture2d<float> prevTex [[texture(0)]],
                                  sampler samp [[sampler(0)]]) {
    float2 uv = in.position.xy / u.res;
    float2 p = (in.position.xy - 0.5f * u.res) / u.res.y;

    float t = u.time;
    float kick = clamp(u.bass, 0.0f, 1.5f);

    float v = 0.0f;
    for (int i = 0; i < 5; ++i) {
        float fi = (float)i;
        float2 q = p;
        float ang = t * (0.3f + 0.07f * fi) + fi * 1.3f;
        float cs = cos(ang), ss = sin(ang);
        q = float2(q.x * cs - q.y * ss, q.x * ss + q.y * cs);
        q += 0.15f * float2(sin(t * (0.7f + 0.15f * fi)), cos(t * (0.5f + 0.12f * fi)));
        v += sin(10.0f * q.y + 4.0f * q.x + fi * 1.7f + 1.2f * t);
    }
    v /= 5.0f;

    float3 col = 0.5f + 0.5f * cos(6.28318f * (float3(0.0, 0.33, 0.67) + v * (1.2f + 0.6f * kick)));

    float2 flow = 0.004f * float2(sin(3.0f * p.y + t), cos(3.0f * p.x - t));
    float3 fb = prevTex.sample(samp, clamp(uv + flow, 0.0f, 1.0f)).rgb;

    float persistence = 0.75f + 0.15f * kick;
    float3 outCol = mix(col, fb, persistence);
    outCol *= saturate(u.fade);
    outCol = outCol / (1.0f + outCol);

    return float4(outCol, 1.0f);
}

fragment float4 scene_HypnoSpiral(FragIn in [[stage_in]],
                                  constant Uniforms& u [[buffer(0)]],
                                  texture2d<float> prevTex [[texture(0)]],
                                  sampler samp [[sampler(0)]])
{
    float2 uv01 = in.position.xy / u.res;
    float2 p = (in.position.xy - 0.5f * u.res) / u.res.y;

    float kick = clamp(u.bass, 0.0f, 1.5f);
    float mid  = clamp(u.mid , 0.0f, 1.2f);
    float hat  = clamp(u.high, 0.0f, 1.0f);

    float t = u.time;
    float spin = 0.25f * t + 0.45f * kick;
    p = rot(p, spin);
    float zoom = 0.92f + 0.10f * (0.5f + 0.5f * sin(t * 0.7f + kick));
    p *= zoom;

    float r = max(length(p), 1e-4f);
    float a = atan2(p.y, p.x);

    float phi = mix(1.6f, 2.3f, 0.5f + 0.5f * sin(0.27f * t + 0.7f * mid));
    float logr = log(r + 1e-4f);
    float swirl = a + phi * logr;

    float rings = sin(20.0f * r - 3.0f * swirl - 0.9f * t);
    float bars  = sin(12.0f * swirl + 0.7f * t);
    float mask  = 0.6f * rings + 0.4f * bars;

    float3 col = cos_palette(mask,
                             float3(0.45, 0.45, 0.50),
                             float3(0.55, 0.55, 0.55),
                             float3(1.00, 1.00, 1.00),
                             float3(0.00, 0.33, 0.67));

    float ca = (0.0035f + 0.0045f * hat) * (0.8f + 0.2f * sin(1.7f * t));
    float2 shiftR = float2(cos(swirl), sin(swirl)) * ca;
    float2 shiftB = -shiftR;

    float3 base;
    {
        float2 uvR = clamp(uv01 + shiftR, 0.0f, 1.0f);
        float2 uvG = uv01;
        float2 uvB = clamp(uv01 + shiftB, 0.0f, 1.0f);
        float rS = prevTex.sample(samp, uvR).r;
        float gS = prevTex.sample(samp, uvG).g;
        float bS = prevTex.sample(samp, uvB).b;
        base = mix(col, float3(rS, gS, bS), 0.55f + 0.20f * kick);
    }

    float vign = smoothstep(1.2f, 0.25f, r);
    base *= vign;

    float glow = pow(saturate(1.0f - r), 2.2f) * (0.35f + 0.45f * (0.5f + 0.5f * sin(t * 1.1f + mid)));
    base += glow;

    float2 swirlFlow = 0.0028f * float2(-sin(a), cos(a)) * (1.0f / (1.0f + 3.0f * r));
    swirlFlow *= (1.0f + 0.8f * kick);
    float3 fb = prevTex.sample(samp, clamp(uv01 + swirlFlow, 0.0f, 1.0f)).rgb;

    float persistence = 0.78f + 0.14f * kick;
    float3 outCol = mix(base, fb, persistence);

    float n = fract(sin(dot(in.position.xy, float2(12.9898,78.233)) + t * 43758.5453f));
    outCol += (n - 0.5f) * 0.01f;

    outCol *= clamp(u.fade, 0.0f, 1.0f);
    outCol = outCol / (1.0f + outCol);

    return float4(outCol, 1.0f);
}
