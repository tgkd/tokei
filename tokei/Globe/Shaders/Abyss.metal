#include "GlobeShared.h"

struct AbyssLook {
    float4 backdrop;
    float4 backdropGlow;
    float4 abyss;
    float4 openSea;
    float4 shelf;
    float4 shallows;
    float4 nightAbyss;
    float4 nightShelf;
    float4 land;
    float4 landHigh;
    float4 nightLand;
    float4 rim;
    float4 cityLight;
    float4 plankton;
    float4 spark;
    float4 sparkHalo;
    float4 moon;
    float4 twilight;
    float4 limb;
    float shelfWidth;
    float shelfReach;
    float abyssReach;
    float isobaths;
    float isobathSpacing;
    float rimWidth;
    float rimStrength;
    float planktonSpacing;
    float planktonDensity;
    float planktonSize;
    float planktonGlow;
    float sparkSpacing;
    float sparkDensity;
    float sparkSize;
    float sparkGlow;
    float recovery;
    float twilightWidth;
    float sheen;
    float glitter;
    float limbStrength;
    float cityGlow;
    float relief;
    float ringWidth;
    float reserved;
};

struct AbyssFootprint {
    float3 dx;
    float3 dy;
    float angle;
};

struct SparkLight {
    float disturbance;
    float ring;
    float wake;
};

static float abyssNoise(float3 p) {
    float3 cell = floor(p);
    float3 t = p - cell;
    t = t * t * (3.0 - 2.0 * t);
    float a = hash33(cell).x;
    float b = hash33(cell + float3(1.0, 0.0, 0.0)).x;
    float c = hash33(cell + float3(0.0, 1.0, 0.0)).x;
    float d = hash33(cell + float3(1.0, 1.0, 0.0)).x;
    float e = hash33(cell + float3(0.0, 0.0, 1.0)).x;
    float f = hash33(cell + float3(1.0, 0.0, 1.0)).x;
    float g = hash33(cell + float3(0.0, 1.0, 1.0)).x;
    float h = hash33(cell + float3(1.0, 1.0, 1.0)).x;
    return mix(mix(mix(a, b, t.x), mix(c, d, t.x), t.y), mix(mix(e, f, t.x), mix(g, h, t.x), t.y), t.z);
}

static float2 abyssScreenOffset(float3 offset, AbyssFootprint footprint) {
    float aa = dot(footprint.dx, footprint.dx);
    float ab = dot(footprint.dx, footprint.dy);
    float bb = dot(footprint.dy, footprint.dy);
    float av = dot(footprint.dx, offset);
    float bv = dot(footprint.dy, offset);
    float determinant = max(aa * bb - ab * ab, 1e-24);
    return float2(bb * av - ab * bv, aa * bv - ab * av) / determinant;
}

static float speckLayer(float3 point, float cellAngle, AbyssFootprint footprint, float density, float size, float seed, thread float &tint) {
    float3 cell = floor(point / cellAngle);
    float3 random = hash33(cell + seed);
    if (random.x > density) {
        return 0.0;
    }
    float3 jitter = hash33(cell + seed + 17.0);
    float3 center = normalize((cell + 0.3 + 0.4 * jitter) * cellAngle);
    float3 inside = center / cellAngle - cell;
    if (any(inside < 0.12) || any(inside > 0.88)) {
        return 0.0;
    }
    float2 offset = abyssScreenOffset(center - point, footprint);
    tint = random.z;
    return exp(-dot(offset, offset) / (2.0 * size * size)) * (0.25 + 0.75 * random.y * random.y);
}

static float specks(float3 point, AbyssFootprint footprint, float cellPixels, float density, float size, float seed, thread float &tint) {
    float level = log2(max(cellPixels * footprint.angle, 1e-6) / 1e-4);
    float lower = floor(level);
    float coarseAngle = 1e-4 * exp2(lower + 1.0);
    float layer = hash33(floor(point / coarseAngle) + seed + 97.0).x < level - lower ? lower + 1.0 : lower;
    return speckLayer(point, 1e-4 * exp2(layer), footprint, density, size, seed + layer * 7.0, tint);
}

static float3 sparkField(float3 point, AbyssFootprint footprint, float cellPixels, float density, float size,
                         SparkLight light, float3 core, float3 halo) {
    float cellAngle = 1e-4 * exp2(round(log2(max(cellPixels * footprint.angle, 1e-6) / 1e-4)));
    float3 base = floor(point / cellAngle - 0.5);
    float awake = smoothstep(0.0, 0.06, light.disturbance);
    float ember = smoothstep(0.08, 0.5, light.disturbance) * 0.07;
    float reach = 30.0 * size * size;
    float3 total = float3(0.0);
    for (int k = 0; k < 2; k++) {
        for (int j = 0; j < 2; j++) {
            for (int i = 0; i < 2; i++) {
                float3 cell = base + float3(float(i), float(j), float(k));
                float3 random = hash33(cell + 41.0);
                if (random.x > density) {
                    continue;
                }
                float3 jitter = hash33(cell + 58.0);
                float3 center = normalize((cell + 0.25 + 0.5 * jitter) * cellAngle);
                float2 offset = abyssScreenOffset(center - point, footprint);
                float distance = dot(offset, offset);
                if (distance > reach) {
                    continue;
                }
                float peak = mix(0.12, 1.0, random.y);
                float timing = (light.disturbance - peak) / 0.12;
                float flash = exp(-timing * timing);
                float lit = (flash + ember) * awake
                          + light.ring * (0.35 + 0.65 * random.z)
                          + light.wake * step(random.z, 0.3);
                float strength = lit * (0.3 + 0.7 * random.z * random.z);
                float glow = exp(-distance / (2.0 * size * size));
                float bloom = exp(-distance / (18.0 * size * size)) * 0.09;
                total += (core * glow + halo * bloom) * strength;
            }
        }
    }
    return total;
}

static float glintLayer(float3 point, float cellAngle, AbyssFootprint footprint, float3 view, float3 sun, float scatter, float sharpness, float density, float seed) {
    float3 cell = floor(point / cellAngle);
    float3 random = hash33(cell + seed);
    if (random.x > density) {
        return 0.0;
    }
    float3 jitter = hash33(cell + seed + 17.0);
    float3 facet = normalize(normalize(point) + (jitter.zxy - 0.5) * scatter);
    float strength = pow(saturate(dot(reflect(-view, facet), sun)), sharpness) * (0.3 + 0.7 * random.y);
    if (strength < 0.003) {
        return 0.0;
    }
    float3 center = normalize((cell + 0.35 + 0.3 * jitter) * cellAngle);
    float2 offset = abyssScreenOffset(center - point, footprint);
    return strength * exp(-dot(offset, offset) * 0.8);
}

fragment half4 abyssFragment(MeshFragmentIn in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant AbyssLook &look [[buffer(1)]],
                             constant EffectUniforms &effects [[buffer(2)]],
                             texture2d<float> dayTexture [[texture(0)]],
                             texture2d<float> lightsTexture [[texture(1)]],
                             texture2d<float> coastTexture [[texture(2)]],
                             texture2d<float> reliefTexture [[texture(3)]],
                             texture2d<float> snowTexture [[texture(4)]],
                             sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    AbyssFootprint footprint;
    footprint.dx = dfdx(nG);
    footprint.dy = dfdy(nG);
    footprint.angle = max(max(length(footprint.dx), length(footprint.dy)), 1e-5);
    float pointScale = uniforms.viewport.x / 402.0;
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    gradient2d haloGradient = gradient2d(coordinates.dx * 6.0, coordinates.dy * 6.0);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float halo = lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r;
    float coastWidth = max(fwidth(coast), 1e-4);
    float seaward = max(-coast, 0.0);
    float seawardWidth = max(fwidth(seaward), 1e-4);
    float terminatorWidth = max(fwidth(muG), look.twilightWidth);

    float water = 1.0 - coastCoverage(coast, coastWidth);
    float onLand = 1.0 - water;
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nMap = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float3 nM = normalize(mix(nMap, nG, water));
    float relief = normalHeight.w;
    float3 nW = nG;
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        float3 ripple = rippleSlope(nG, effects);
        nM = normalize(mix(nG, nM, effects.radii.w) - slope);
        nW = normalize(nG - slope - effects.wave.x * ripple);
        relief *= effects.radii.w;
    }

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.16, 0.02, muG);
    float dusk = (1.0 - smoothstep(0.0, look.twilightWidth * 5.0, muG)) * daylight;
    float viewCosine = saturate(dot(nG, view));

    float shelfGlow = exp(-seaward / look.shelfWidth);
    float open = smoothstep(0.0, look.shelfReach, seaward);
    float deep = smoothstep(look.shelfReach, look.abyssReach, seaward);

    float isobath = 0.0;
    if (look.isobaths > 0.0 && water > 0.0 && seaward > look.isobathSpacing * 0.6) {
        float octave = round(log2(seaward / look.isobathSpacing));
        float contour = look.isobathSpacing * exp2(octave);
        float across = abs(seaward - contour) / seawardWidth;
        float spacingPixels = contour * 0.5 / seawardWidth;
        isobath = (1.0 - smoothstep(0.3, 1.2, across)) * smoothstep(4.0, 10.0, spacingPixels) * exp(-octave * 0.3);
    }

    float3 seaDay = mix(mix(look.shelf.xyz, look.openSea.xyz, open), look.abyss.xyz, deep);
    seaDay = mix(seaDay, look.shallows.xyz, shelfGlow * shelfGlow * 0.58);
    float seaLit = 0.55 + 0.45 * saturate(muG * 2.5);
    seaDay *= seaLit;
    seaDay += look.shallows.xyz * isobath * look.isobaths * 0.5;

    float lit = saturate(dot(nM, sun) * 0.85 + 0.15);
    float height = smoothstep(1.05, 1.8, relief);
    float3 moonDirection = normalize(uniforms.cameraUp.xyz * 0.6 - uniforms.cameraRight.xyz * 0.3 - uniforms.cameraForward.xyz);
    float moonLit = saturate(dot(nM, moonDirection));
    float shore = exp(-max(coast, 0.0) / 0.45);
    float grain = 1.0 - smoothstep(0.2, 1.0, footprint.angle * 60.0);
    float slate = 0.5;
    if (grain > 0.0 && onLand > 0.0) {
        slate = abyssNoise(nG * 55.0) * 0.6 + abyssNoise(nG * 160.0) * 0.4 * (1.0 - smoothstep(0.3, 1.0, footprint.angle * 160.0)) + 0.2 * smoothstep(0.3, 1.0, footprint.angle * 160.0);
    }
    float plateau = smoothstep(0.55, 1.0, relief);
    float3 landDay = mix(look.land.xyz, look.landHigh.xyz, height * 0.6) * (0.4 + 0.8 * lit);
    landDay *= mix(0.82, 1.08, plateau) * mix(1.0, 0.8 + 0.4 * slate, grain);
    landDay += look.shallows.xyz * shore * 0.07 * (0.4 + 0.6 * saturate(muG * 3.0));
    landDay += look.rim.xyz * pow(moonLit, 8.0) * height * 0.03;
    float rimLine = exp(-max(coast, 0.0) / max(look.rimWidth, coastWidth * 1.3)) * onLand;

    float3 day = mix(landDay, seaDay, water);
    day = mix(day, day * look.twilight.xyz * 1.9, dusk * 0.55);
    day *= mix(0.7, 1.0, sqrt(viewCosine));

    float3 halfVector = sun + view;
    float3 halfway = halfVector * rsqrt(max(dot(halfVector, halfVector), 1e-8));
    float nh = saturate(dot(nW, halfway));
    float sunUp = saturate(muG * 5.0);
    day += look.moon.xyz * (pow(nh, 60.0) * 0.02 + pow(nh, 20000.0) * 0.35) * look.sheen * sunUp * water;
    if (look.glitter > 0.0 && water > 0.0 && nh > 0.985 && sunUp > 0.0) {
        float cellAngle = 1e-4 * exp2(round(log2(max(6.0 * footprint.angle, 1e-6) / 1e-4)));
        day += look.moon.xyz * glintLayer(nG, cellAngle, footprint, view, sun, 0.06, 1400.0, 0.5, 61.0) * look.glitter * sunUp * water;
    }

    float3 nightSea = mix(look.nightAbyss.xyz, look.nightShelf.xyz, shelfGlow * mix(1.0, 0.6, open));
    nightSea += look.nightShelf.xyz * isobath * look.isobaths * 0.6;
    float3 nightLand = look.nightLand.xyz * (0.6 + 0.8 * moonLit);
    nightLand += look.nightShelf.xyz * shore * 0.25;
    float3 night = mix(nightLand, nightSea, water);
    if (nightGate > 0.0 && onLand > 0.0) {
        night += look.cityLight.xyz * (pow(lights, 2.2) * 1.3 + pow(halo, 1.4) * 0.22) * look.cityGlow * nightGate * onLand;
    }

    float3 color = mix(night, day, daylight);
    color += look.rim.xyz * rimLine * look.rimStrength * mix(0.35, 1.0, daylight);
    color += look.limb.xyz * pow(1.0 - viewCosine, 3.0) * look.limbStrength * mix(0.3, 1.0, daylight);

    if (water > 0.0) {
        float tint = 0.0;
        float density = look.planktonDensity * mix(0.45, 1.0, exp(-seaward / (look.shelfWidth * 5.0)));
        float speck = specks(nG, footprint, look.planktonSpacing * pointScale, density, look.planktonSize * pointScale, 5.0, tint);
        float3 speckColor = mix(look.plankton.xyz, look.sparkHalo.xyz * 0.6, tint);
        color += speckColor * speck * look.planktonGlow * mix(0.3, 1.0, 1.0 - daylight) * water;
    }

    SparkLight light = {0.0, 0.0, 0.0};
    float clock = effects.state.w;
    if (clock > 0.0 && water > 0.0) {
        light.disturbance = 1.0 - snowLevelBilinear(snowTexture, surfaceSampler, coordinates.uv, clock, max(look.recovery, 0.01));
    }
    if (effectsActive(effects) && effects.detail.w > 0.0 && effects.ripple.w >= 0.0) {
        float angle = acos(clamp(dot(nG, effects.ripple.xyz), -1.0, 1.0));
        float front = angle - effects.wave.w * effects.ripple.w;
        float width = max(effects.wave.z * look.ringWidth, footprint.angle * 4.0);
        float fade = exp(-effects.state.x * effects.ripple.w) * effects.detail.w;
        light.ring = exp(-(front * front) / (width * width)) * fade;
        light.wake = (front < 0.0 ? exp(front / (effects.wave.z * 2.0)) : 0.0) * fade * 0.4;
    }
    if (water > 0.0 && (light.disturbance > 0.001 || light.ring + light.wake > 0.002)) {
        float3 sparks = sparkField(nG, footprint, look.sparkSpacing * pointScale, look.sparkDensity, look.sparkSize * pointScale,
                                   light, look.spark.xyz, look.sparkHalo.xyz);
        color += sparks * look.sparkGlow * mix(0.6, 1.0, 1.0 - daylight) * water;
    }
    if (effectsActive(effects)) {
        float bloom = effectWeight(nG, effects.bump.xyz, effects.radii.y * 0.6);
        color += mix(look.sparkHalo.xyz, look.spark.xyz, 0.3) * effects.radii.z * bloom * bloom * 0.12;
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 abyssBackground(FullscreenVertex in [[stage_in]],
                               constant GlobeUniforms &uniforms [[buffer(0)]],
                               constant AbyssLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float scale = uniforms.viewport.x / 1206.0;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = look.backdrop.xyz * mix(1.6, 0.55, smoothstep(-0.5, 0.55, screen.y));
    float outside = max(reach - 1.0, 0.0);
    color += look.backdropGlow.xyz * (exp(-outside * 3.5) * 0.3 + exp(-outside * 12.0) * 0.25);
    BackdropPoint snow = backdropPoint(direction, 46.0, 7.0, focal);
    if (snow.random.x < 0.3) {
        float size = (0.9 + 1.4 * snow.random.y) * scale;
        float glow = exp(-dot(snow.offset, snow.offset) / (2.0 * size * size));
        color += mix(look.plankton.xyz, look.moon.xyz, snow.random.z) * glow * (0.05 + 0.12 * snow.random.z * snow.random.z);
    }
    BackdropPoint dust = backdropPoint(direction, 120.0, 19.0, focal);
    if (dust.random.x < 0.22) {
        float size = 0.7 * scale;
        color += look.plankton.xyz * 0.05 * exp(-dot(dust.offset, dust.offset) / (2.0 * size * size));
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
