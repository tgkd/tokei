#include "GlobeShared.h"

struct ChromeLook {
    float4 backdrop;
    float4 sea;
    float4 land;
    float4 sun;
    float4 key;
    float4 fill;
    float4 strip;
    float4 warm;
    float4 cool;
    float4 sky;
    float4 ground;
    float4 wall;
    float4 night;
    float4 twilight;
    float4 ember;
    float4 molten;
    float seaBlur;
    float landBlur;
    float sheen;
    float sheenSpread;
    float bevel;
    float lift;
    float groove;
    float grooveDepth;
    float meniscus;
    float halo;
    float swell;
    float swellLength;
    float swellReach;
    float brush;
    float brushDepth;
    float dusk;
};

static float3 toView(float3 v, constant GlobeUniforms &uniforms) {
    return float3(dot(v, uniforms.cameraRight.xyz), dot(v, uniforms.cameraUp.xyz), -dot(v, uniforms.cameraForward.xyz));
}

static float panel(float3 r, float3 center, float3 across, float3 along, float2 size, float soft) {
    float facing = dot(r, center);
    float2 q = float2(dot(r, across), dot(r, along)) / max(facing, 0.05);
    float2 edge = abs(q) - size;
    float outside = max(edge.x, edge.y);
    float body = 1.0 - 0.6 * saturate(abs(q.y) / size.y);
    float spread = min(size.x, size.y);
    return body * (1.0 - smoothstep(-soft, soft, outside)) * spread / (spread + soft) * step(0.0, facing);
}

static float lobe(float3 r, float3 center, float width, float blur) {
    float variance = width * width + blur * blur;
    return exp(-2.0 * (1.0 - dot(r, center)) / variance) * width * width / variance;
}

static float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

static float3 studio(float3 r, float3 s, float blur, float day, float warmth, constant ChromeLook &look) {
    float y = r.y - look.ground.w;
    float soft = 0.25 + blur;
    float above = smoothstep(-soft, soft, y);
    float3 ambient = mix(look.ground.rgb * (0.4 + 0.6 * smoothstep(-1.0, 0.0, y)), look.sky.rgb * (0.5 + 0.5 * smoothstep(0.0, 1.0, y)), above);
    float key = lobe(r, float3(-0.5495, 0.5495, 0.6294), look.key.w, blur);
    float fill = lobe(r, float3(0.9233, 0.0543, 0.3802), look.fill.w, blur);
    float strip = panel(r, float3(0.0, 0.8838, 0.4679), float3(1.0, 0.0, 0.0), float3(0.0, 0.4679, -0.8838), float2(1.5, 0.045), 0.012 + blur);
    float rims = panel(float3(abs(r.x), r.yz), float3(0.7676, 0.1695, -0.6181), float3(-0.6272, 0.0, -0.7789), float3(-0.1320, 0.9855, 0.1063), float2(0.1, 1.4), 0.03 + blur);
    float left = rims * step(r.x, 0.0);
    float right = rims - left;
    float wall = exp(-(1.0 + dot(r, float3(0.0, 0.1961, -0.9806))) * 2.2);

    float3 lit = ambient + look.key.rgb * key + look.fill.rgb * fill + look.strip.rgb * strip + look.warm.rgb * left + look.cool.rgb * right;
    float3 dim = look.night.rgb * (luminance(look.strip.rgb) * strip + luminance(look.cool.rgb) * right + luminance(look.warm.rgb) * left * 0.5 + luminance(ambient) * look.night.w);
    float3 tint = mix(float3(1.0), look.twilight.rgb, warmth);
    float3 color = mix(dim, lit * tint, day) + look.wall.rgb * wall * mix(look.wall.w, 1.0, day);

    float angle2 = 2.0 * (1.0 - dot(r, s));
    float radius = look.sun.w;
    float sunSoft = radius * 0.5 + blur;
    float inner = max(radius - sunSoft, 0.0);
    float outer = radius + sunSoft;
    float disk = (1.0 - smoothstep(inner * inner, outer * outer, angle2)) * radius * radius / (radius * radius + blur * blur);
    float haloWidth = 0.1 + blur;
    float aura = exp(-angle2 / (haloWidth * haloWidth)) * 0.01 / (haloWidth * haloWidth);
    color += look.sun.rgb * tint * (disk * 8.0 + aura * 0.5) * day;
    return color;
}

static float3 fresnel(float3 f0, float cosine) {
    float grazing = 1.0 - saturate(cosine);
    float grazing2 = grazing * grazing;
    return f0 + (1.0 - f0) * grazing2 * grazing2 * grazing;
}

static float valueNoise(float2 point) {
    float2 cell = floor(point);
    float2 local = point - cell;
    float2 blend = local * local * (3.0 - 2.0 * local);
    float a = hash12(cell);
    float b = hash12(cell + float2(1.0, 0.0));
    float c = hash12(cell + float2(0.0, 1.0));
    float d = hash12(cell + float2(1.0, 1.0));
    return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

static float3 heatGlow(float heat) {
    float heat2 = heat * heat;
    return float3(1.0, 0.35, 0.05) * heat2 + float3(0.0, 0.25, 0.08) * heat2 * heat2;
}

fragment half4 chromeFragment(MeshFragmentIn in [[stage_in]],
                              constant GlobeUniforms &uniforms [[buffer(0)]],
                              constant ChromeLook &look [[buffer(1)]],
                              constant EffectUniforms &effects [[buffer(2)]],
                              texture2d<float> dayTexture [[texture(0)]],
                              texture2d<float> lightsTexture [[texture(1)]],
                              texture2d<float> coastTexture [[texture(2)]],
                              texture2d<float> reliefTexture [[texture(3)]],
                              sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), 0.012);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nM = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float bevelT = saturate(coast / look.bevel);
    float steepness = 4.0 * bevelT * (1.0 - bevelT);
    float2 bevelSpan = look.bevel / float2(360.0, 180.0);
    float2 lightsDx = mix(coordinates.dx, float2(bevelSpan.x, 0.0), steepness);
    float2 lightsDy = mix(coordinates.dy, float2(0.0, bevelSpan.y), steepness);
    float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient2d(lightsDx, lightsDy)).r;
    float2 smear = float2(0.3, 1.0) * look.halo;
    gradient2d haloGradient = gradient2d(lightsDx * smear, lightsDy * smear);
    float halo = lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r;
    float2 coastStep = max(1.0 / float2(coastTexture.get_width(), coastTexture.get_height()), max(abs(coordinates.dx), abs(coordinates.dy)));
    float coastEast = coastTexture.sample(surfaceSampler, coordinates.uv + float2(coastStep.x, 0.0), gradient).r;
    float coastNorth = coastTexture.sample(surfaceSampler, coordinates.uv - float2(0.0, coastStep.y), gradient).r;
    float coastWidth = fwidth(coast);
    float water = 1.0 - coastCoverage(coast, coastWidth);

    float cosLatitude = max(length(nG.xz), 0.05);
    float3 eastward = float3(nG.z, 0.0, -nG.x) / cosLatitude;
    float3 northward = cross(nG, eastward);
    float3 coastGradient = eastward * (coastEast - coast) / (2.0 * M_PI_F * coastStep.x * cosLatitude)
                         + northward * (coastNorth - coast) / (M_PI_F * coastStep.y);
    float3 inland = coastGradient * rsqrt(max(dot(coastGradient, coastGradient), 1e-8));

    float bevelZone = 1.0 - smoothstep(1.1, 2.2, coast / look.bevel);
    float bevelSlope = look.lift * 57.2958 * 6.0 * bevelT * (1.0 - bevelT) / look.bevel;
    float3 landNormal = normalize(mix(nM, nG, bevelZone) - bevelSlope * inland);
    float meniscusWidth = max(look.meniscus, 1.5 * coastWidth);
    float lip = saturate(1.0 + coast / meniscusWidth) * step(coast, 0.0);
    float lipTilt = 0.8 * lip * lip * lip;
    float swellFade = saturate(look.swellLength / (4.0 * coastWidth) - 0.5);
    float swellTilt = look.swell * swellFade * sin(2.0 * M_PI_F * coast / look.swellLength) * exp(coast / look.swellReach) * step(coast, 0.0);
    float3 seaNormal = normalize(nG + inland * (lipTilt + swellTilt));

    float heat = 0.0;
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        float3 waveSlope = effects.wave.x * rippleSlope(nG, effects);
        landNormal = normalize(mix(nG, landNormal, effects.radii.w) - slope - effects.detail.z * waveSlope);
        seaNormal = normalize(seaNormal - slope - waveSlope);
        heat = saturate(1.0 - effects.radii.w);
    }

    float day = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float warmth = (1.0 - smoothstep(0.0, look.dusk, muG)) * day;
    float3 view = -direction;
    float3 s = toView(sun, uniforms);

    float3 normal = normalize(mix(landNormal, seaNormal, water));
    float blur = max(mix(look.landBlur, look.seaBlur, water), 1.2 * length(fwidth(normal)));
    float3 f0 = mix(look.land.rgb, look.sea.rgb, water);
    float3 reflection = reflect(direction, normal);
    float3 color = fresnel(f0, dot(normal, view)) * studio(toView(reflection, uniforms), s, blur, day, warmth, look);

    float3 halfway = normalize(sun + view);
    float sheen = pow(saturate(dot(landNormal, halfway)), look.sheenSpread) * saturate(muG * 6.0);
    color += look.land.rgb * look.sun.rgb * mix(float3(1.0), look.twilight.rgb, warmth) * sheen * look.sheen * (1.0 - water);

    float brushSpacing = max(abs(coordinates.dx.y), abs(coordinates.dy.y)) * look.brush;
    float brushFade = saturate(1.0 - 1.5 * brushSpacing) * (1.0 - water);
    if (brushFade > 0.0) {
        float line = coordinates.uv.y * look.brush + valueNoise(coordinates.uv * float2(40.0, 900.0)) * 3.0;
        float index = floor(line);
        float grain = mix(hash12(float2(index, 3.0)), hash12(float2(index + 1.0, 3.0)), smoothstep(0.0, 1.0, line - index));
        color *= 1.0 + (grain - 0.5) * look.brushDepth * brushFade;
    }

    float grooveWidth = max(look.groove, 0.8 * coastWidth);
    float groove = saturate(1.0 - abs(coast) / grooveWidth) * saturate(look.groove / grooveWidth + 0.35);
    color *= 1.0 - look.grooveDepth * groove;

    float nightGate = 1.0 - smoothstep(-0.12, 0.03, muG);
    float core = lights * lights;
    float glow = core * 1.6 + halo * sqrt(halo) * 0.6;
    float3 ember = look.ember.rgb * glow + float3(1.0, 0.9, 0.75) * core * core * 1.5;
    color += ember * nightGate * mix(1.0 - 0.6 * steepness, 0.25, water);
    color += look.ember.rgb * look.ember.w * nightGate * (1.0 - water);

    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
        if (heat > 0.0) {
            float2 flowPoint = coordinates.uv * float2(60.0, 30.0);
            float flow = valueNoise(flowPoint) * 0.6 + valueNoise(flowPoint * 2.3 + 11.0) * 0.4;
            float vein = 1.0 - abs(2.0 * flow - 1.0);
            vein *= vein;
            vein *= vein;
            float warmest = pow(heat, 0.7);
            float temperature = saturate(warmest * (0.45 + 0.2 * saturate(normalHeight.w) + 0.55 * vein));
            color *= mix(1.0, 0.35, saturate(warmest * 2.0) * (1.0 - water));
            color += look.molten.rgb * heatGlow(temperature) * look.molten.w * (1.0 - water);
        }
        color += look.sun.rgb * effects.radii.z * effectWeight(nG, effects.bump.xyz, effects.radii.y * 0.6);
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 chromeBackground(FullscreenVertex in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant ChromeLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float3 disk = globeDisk(uniforms);
    float height = pixel.y / uniforms.viewport.y;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = mix(look.backdrop.xyz * 2.4, look.backdrop.xyz * 0.5, smoothstep(0.0, 0.95, height));
    float2 fromCenter = (pixel - disk.xy - float2(-0.25, -0.3) * disk.z) / disk.z;
    color += look.wall.xyz * 0.1 * exp(-max(length(fromCenter) - 0.6, 0.0) * 1.5);
    float2 pool = (pixel - disk.xy - float2(0.0, 1.22 * disk.z)) / (disk.z * float2(1.1, 0.2));
    color += look.wall.xyz * 0.06 * exp(-dot(pool, pool) * 1.5);
    color *= mix(1.05, 0.7, smoothstep(0.25, 0.85, length(screen)));
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
