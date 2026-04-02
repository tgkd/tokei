#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void dayNightSurface(realitykit::surface_parameters params)
{
    // Shift texture to align with marker coordinate system
    float2 uv = float2(params.geometry().uv0().x - 0.255, 1.0 - params.geometry().uv0().y);
    float3 normal = normalize(params.geometry().model_position());

    constexpr sampler texSampler(address::repeat, filter::linear, mip_filter::linear);
    half4 dayColor = params.textures().base_color().sample(texSampler, uv);
    half4 nightColor = params.textures().emissive_color().sample(texSampler, uv);

    float3 rawSun = params.uniforms().custom_parameter().xyz;
    float sunLen = length(rawSun);
    half3 sunDir = sunLen > 0.001 ? half3(rawSun / sunLen) : half3(0, 0, 1);

    half ndotl = dot(half3(normal), sunDir);

    half dayFactor = smoothstep(half(-0.15), half(0.15), ndotl);
    half nightFactor = 1.0h - smoothstep(half(-0.2), half(0.1), ndotl);

    half3 dayLit = dayColor.rgb * max(ndotl * 0.6h + 0.3h, 0.02h) * dayFactor;
    half3 nightLit = nightColor.rgb * nightFactor * 0.7h;

    // Ambient fill on dark side so it's not pitch black
    half3 ambient = dayColor.rgb * 0.07h * (1.0h - dayFactor);

    // Very subtle warm twilight tint spread across the terminator zone
    half twilightFactor = smoothstep(half(-0.35), half(0.0), ndotl) * smoothstep(half(0.3), half(0.0), ndotl);
    half3 twilight = half3(0.6h, 0.35h, 0.2h) * twilightFactor * 0.03h;

    // For .unlit, only emissive_color produces visible output
    params.surface().set_emissive_color(dayLit + nightLit + ambient + twilight);
}
