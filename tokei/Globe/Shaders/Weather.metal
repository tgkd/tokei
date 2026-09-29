#include "GlobeShared.h"

struct WeatherLook {
    float4 backdrop;
    float4 oceanDeep;
    float4 oceanShallow;
    float4 oceanNight;
    float4 landLow;
    float4 landHigh;
    float4 landNight;
    float4 coast;
    float4 cityLight;
    float4 twilight;
    float4 cloudLit;
    float4 cloudShade;
    float4 cloudNight;
    float4 storm;
    float4 rain;
    float4 snow;
    float4 sleet;
    float4 halo;
    float wrap;
    float shallowWidth;
    float coastWidth;
    float shadowStrength;
    float shadowReach;
    float cloudHeight;
    float cloudBulge;
    float cloudRim;
    float rainThreshold;
    float rainDensity;
    float recovery;
    float twilightWidth;
    float nightLights;
    float burstSpeed;
    float burstRadius;
    float toon;
};

static float2 weatherUV(float3 direction) {
    float longitude = atan2(direction.x, direction.z);
    float latitude = asin(clamp(direction.y, -1.0, 1.0));
    return float2(longitude / (2.0 * M_PI_F) + 0.5, 0.5 - latitude / M_PI_F);
}

static float weatherRefill(texture2d<float> snowTexture, sampler surfaceSampler, float2 uv, float clock, float recovery) {
    return clock > 0.0 ? snowLevelBilinear(snowTexture, surfaceSampler, uv, clock, recovery) : 1.0;
}

static float cloudShadow(float3 nG, float3 sun, float muG,
                         constant WeatherLook &look,
                         constant EffectUniforms &effects,
                         texture2d<float> weatherTexture,
                         texture2d<float> snowTexture,
                         sampler surfaceSampler) {
    if (muG <= 0.0) {
        return 0.0;
    }
    float3 toward = sun - nG * muG;
    float towardLength = length(toward);
    float height = look.cloudHeight * (effectsActive(effects) ? effects.radii.w : 1.0);
    float reach = min(height * towardLength / max(muG, 0.05), look.shadowReach);
    float3 caster = towardLength > 1e-4 ? normalize(nG + toward / towardLength * reach) : nG;
    float2 uv = weatherUV(caster);
    float refill = weatherRefill(snowTexture, surfaceSampler, uv, effects.state.w, look.recovery);
    float mask = weatherTexture.sample(surfaceSampler, uv, level(0.0)).r - (1.0 - refill);
    return smoothstep(0.38, 0.62, mask) * saturate(muG * 6.0);
}

fragment half4 weatherFragment(MeshFragmentIn in [[stage_in]],
                               constant GlobeUniforms &uniforms [[buffer(0)]],
                               constant WeatherLook &look [[buffer(1)]],
                               constant EffectUniforms &effects [[buffer(2)]],
                               texture2d<float> dayTexture [[texture(0)]],
                               texture2d<float> lightsTexture [[texture(1)]],
                               texture2d<float> coastTexture [[texture(2)]],
                               texture2d<float> reliefTexture [[texture(3)]],
                               texture2d<float> snowTexture [[texture(4)]],
                               texture2d<float> weatherTexture [[texture(5)]],
                               sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), 0.012);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    gradient2d haloGradient = gradient2d(coordinates.dx * 6.0, coordinates.dy * 6.0);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nMap = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float coastWidth = fwidth(coast);
    float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float halo = lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r;
    float water = 1.0 - coastCoverage(coast, coastWidth);
    float3 nM = normalize(mix(nMap, nG, water));
    float relief = saturate(normalHeight.w);
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        float3 rippleTilt;
        rippleWave(nG, effects, rippleTilt);
        nM = normalize(mix(nG, nM, effects.radii.w) - slope - water * effects.wave.x * rippleTilt);
        relief *= effects.radii.w;
    }

    float seaward = max(-coast, 0.0);
    float shallow = exp(-seaward / max(look.shallowWidth, 1e-3));
    float3 ocean = mix(look.oceanDeep.xyz, look.oceanShallow.xyz, shallow);
    float3 land = mix(look.landLow.xyz, look.landHigh.xyz, 0.6 * smoothstep(0.2, 1.0, relief));
    float shore = (1.0 - smoothstep(look.coastWidth * 0.5, look.coastWidth + coastWidth, abs(coast))) * saturate(look.coastWidth / max(coastWidth, 1e-4) - 0.5);
    float3 albedo = mix(mix(land, ocean, water), look.coast.xyz, shore * 0.55);

    float dayGate = smoothstep(-0.06 - terminatorWidth, 0.06 + terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.1736, 0.0175, muG);
    float diffuse = saturate((dot(nM, sun) + look.wrap) / (1.0 + look.wrap));
    float3 day = albedo * mix(0.55, 1.0, diffuse);
    float shade = cloudShadow(nG, sun, muG, look, effects, weatherTexture, snowTexture, surfaceSampler);
    day = mix(day, day * look.oceanNight.xyz * 3.0, look.shadowStrength * shade);
    float warmth = (1.0 - smoothstep(0.0, look.twilightWidth, muG)) * smoothstep(-0.06, 0.02, muG);
    day = mix(day, day * look.twilight.xyz * 1.6, warmth * 0.25);
    float3 night = mix(look.landNight.xyz, look.oceanNight.xyz, water) * (0.7 + 0.3 * saturate(dot(nM, view)));
    float3 color = mix(night, day, dayGate);
    color += look.cityLight.xyz * (pow(lights, 1.4) + 0.35 * halo) * nightGate * (1.0 - water) * look.nightLights;
    color *= mix(0.82, 1.0, sqrt(saturate(dot(nG, view))));
    if (effectsActive(effects)) {
        float popWeight = effectWeight(nG, effects.bump.xyz, effects.radii.y);
        color += look.cityLight.xyz * effects.radii.z * popWeight * popWeight * 0.5;
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 weatherBackground(FullscreenVertex in [[stage_in]],
                                 constant GlobeUniforms &uniforms [[buffer(0)]],
                                 constant WeatherLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = look.backdrop.xyz * mix(1.25, 0.75, smoothstep(0.1, 0.9, length(screen)));
    color += look.halo.xyz * 0.12 * exp(-max(reach - 1.0, 0.0) * 5.0);
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

static float precipitationMark(float2 local, float kind, float pick) {
    bool flake = kind > 0.5 && kind < 1.5;
    if (kind > 1.5 && kind < 2.5) {
        flake = pick > 0.5;
    }
    if (flake) {
        return length(local) - 0.14;
    }
    float2 slanted = float2(local.x * 0.906 + local.y * 0.423, -local.x * 0.423 + local.y * 0.906);
    return length(float2(slanted.x, max(abs(slanted.y) - 0.24, 0.0))) - 0.075;
}

fragment half4 weatherClouds(MeshFragmentIn in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant WeatherLook &look [[buffer(1)]],
                             constant EffectUniforms &effects [[buffer(2)]],
                             texture2d<float> snowTexture [[texture(4)]],
                             texture2d<float> weatherTexture [[texture(5)]],
                             sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 nG = normalize(in.spherePosition);
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float2 uv = coordinates.uv;
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), 0.012);
    float4 weather = weatherTexture.sample(surfaceSampler, uv, level(0.0));
    float refill = weatherRefill(snowTexture, surfaceSampler, uv, effects.state.w, look.recovery);
    float mask = weather.r - (1.0 - refill);
    float coverage = saturate((mask - 0.5) / max(fwidth(mask), 1e-4) + 0.5);
    if (coverage <= 0.0) {
        discard_fragment();
    }

    float cosLatitude = max(length(nG.xz), 1e-3);
    float3 east = float3(nG.z, 0.0, -nG.x) / cosLatitude;
    float3 north = cross(nG, east);
    float2 size = float2(weatherTexture.get_width(), weatherTexture.get_height());
    float2 texel = 1.0 / size;
    float fieldEast = weatherTexture.sample(surfaceSampler, uv + float2(texel.x, 0.0), level(0.0)).g
                    - weatherTexture.sample(surfaceSampler, uv - float2(texel.x, 0.0), level(0.0)).g;
    float fieldNorth = weatherTexture.sample(surfaceSampler, uv - float2(0.0, texel.y), level(0.0)).g
                     - weatherTexture.sample(surfaceSampler, uv + float2(0.0, texel.y), level(0.0)).g;
    float2 slope = float2(fieldEast / (4.0 * M_PI_F * texel.x * cosLatitude), fieldNorth / (2.0 * M_PI_F * texel.y));
    float3 rise = east * slope.x + north * slope.y;
    float riseLength = length(rise);
    float rim = 1.0 - smoothstep(0.5, 0.5 + look.cloudRim, mask);
    float3 outward = riseLength > 1e-4 ? -rise / riseLength : float3(0.0);
    float3 nC = normalize(nG - look.cloudBulge * rise + outward * rim * 0.9);

    float dayGate = smoothstep(-0.06 - terminatorWidth, 0.06 + terminatorWidth, muG);
    float lit = saturate((dot(nC, sun) + look.wrap) / (1.0 + look.wrap));
    lit = mix(lit, smoothstep(0.42, 0.58, lit), look.toon);
    float3 day = mix(look.cloudShade.xyz, look.cloudLit.xyz, lit);
    float warmth = (1.0 - smoothstep(0.0, look.twilightWidth, muG)) * smoothstep(-0.06, 0.02, muG);
    day = mix(day, day * look.twilight.xyz * 1.4, warmth * 0.4);
    float3 night = look.cloudNight.xyz * (0.75 + 0.25 * saturate(dot(nC, view)));
    float3 color = mix(night, day, dayGate);

    if (weather.b >= look.rainThreshold) {
        float amount = saturate((weather.b - look.rainThreshold) / (1.0 - look.rainThreshold));
        uint2 nearest = uint2(clamp(uv * size, float2(0.0), size - 1.0));
        float kind = round(weatherTexture.read(nearest).a * 255.0 / 64.0);
        float3 tint = look.storm.xyz * mix(0.45, 1.0, dayGate);
        color = mix(color, tint, 0.3 + 0.5 * amount);

        float burst = 0.0;
        float fall = 0.0;
        if (effectsActive(effects) && effects.ripple.w >= 0.0) {
            float age = effects.ripple.w;
            burst = effectWeight(nG, effects.ripple.xyz, look.burstRadius) * exp(-age * 1.2);
            fall = age * look.burstSpeed;
        }
        float rows = look.rainDensity * M_PI_F;
        float rowPosition = uv.y * rows;
        float row = floor(rowPosition);
        float rowLatitude = (0.5 - (row + 0.5) / rows) * M_PI_F;
        float columns = max(floor(2.0 * M_PI_F * cos(rowLatitude) * look.rainDensity), 1.0);
        float columnPosition = fract(uv.x) * columns;
        float2 cell = float2(floor(columnPosition), row);
        float3 random = hash33(float3(cell, 7.0));
        float2 local = float2(fract(columnPosition), fract(rowPosition + fall * burst)) - 0.5 - (random.yz - 0.5) * 0.4;
        float footprint = max(length(float2(coordinates.dx.x * columns, coordinates.dx.y * rows)),
                              length(float2(coordinates.dy.x * columns, coordinates.dy.y * rows)));
        float present = step(random.x, 0.2 + 0.55 * amount + 0.35 * burst);
        float mark = precipitationMark(local, kind, random.z);
        float ink = saturate(0.5 - mark / max(footprint, 1e-4)) * present * saturate(1.6 - footprint * 3.0);
        float3 markColor = kind > 0.5 && kind < 1.5 ? look.snow.xyz : (kind > 1.5 && kind < 2.5 ? look.sleet.xyz : look.rain.xyz);
        color = mix(color, markColor * mix(0.5, 1.0, dayGate) * (1.0 + burst), ink * (0.75 + 0.25 * burst));
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    half4 result = finishColor(color, pixel);
    result.a = half(coverage);
    return result;
}
