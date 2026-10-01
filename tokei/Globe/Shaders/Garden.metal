#include "GlobeShared.h"

struct GardenLook {
    float4 backdrop;
    float4 stain;
    float4 gravel;
    float4 gravelShade;
    float4 mica;
    float4 moss;
    float4 mossLight;
    float4 mossSheen;
    float4 nightMoss;
    float4 granite;
    float4 lichen;
    float4 pebble;
    float4 moon;
    float4 twilight;
    float4 cityLight;
    float rakeSpacing;
    float ringBand;
    float grooveTilt;
    float grooveShade;
    float grainFine;
    float grainCoarse;
    float grainContrast;
    float micaCell;
    float micaChance;
    float micaSharpness;
    float pebbleBand;
    float pebbleCell;
    float rockLevel;
    float mossSheenPower;
    float mossSheenStrength;
    float moonStrength;
    float terminatorWidth;
    float pressBend;
    float pressDepth;
    float rippleGlint;
    float stainCells;
    float stainStrength;
    float grainBackdrop;
    float markRecovery;
};

struct GardenCell {
    float2 offset;
    float3 random;
    float3 shape;
    float present;
};

static GardenCell gardenCell(float2 uv, float cosLatitude, float cell, float seed, float spread) {
    float latitude = (0.5 - uv.y) * 180.0;
    float band = (latitude + 90.0) / cell;
    float row = floor(band);
    float rowLatitude = (row + 0.5) * cell - 90.0;
    float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / cell), 1.0);
    float along = fract(uv.x) * columns;
    float column = floor(along);
    GardenCell result;
    result.random = hash33(float3(column, row, seed));
    result.shape = hash33(float3(row + 0.5, column + 0.5, seed + 3.0));
    float2 spot = 0.5 - spread * 0.5 + spread * result.random.yz;
    float cellWidth = 360.0 * cosLatitude / columns;
    result.offset = float2((fract(along) - spot.x) * cellWidth, (band - row - spot.y) * cell);
    result.present = 1.0;
    return result;
}

static float gardenNoise(float3 p) {
    float3 cell = floor(p);
    float3 t = p - cell;
    t = t * t * (3.0 - 2.0 * t);
    float lowerNear = mix(hash33(cell).x, hash33(cell + float3(1.0, 0.0, 0.0)).x, t.x);
    float lowerFar = mix(hash33(cell + float3(0.0, 1.0, 0.0)).x, hash33(cell + float3(1.0, 1.0, 0.0)).x, t.x);
    float upperNear = mix(hash33(cell + float3(0.0, 0.0, 1.0)).x, hash33(cell + float3(1.0, 0.0, 1.0)).x, t.x);
    float upperFar = mix(hash33(cell + float3(0.0, 1.0, 1.0)).x, hash33(cell + float3(1.0, 1.0, 1.0)).x, t.x);
    return mix(mix(lowerNear, lowerFar, t.y), mix(upperNear, upperFar, t.y), t.z);
}

static float3 gardenBump(float3 nG, float3 spherePosition, float h) {
    float3 dpdx = dfdx(spherePosition);
    float3 dpdy = dfdy(spherePosition);
    float3 r1 = cross(dpdy, nG);
    float3 r2 = cross(nG, dpdx);
    float det = dot(dpdx, r1);
    return normalize(abs(det) * nG - sign(det) * (r1 * dfdx(h) + r2 * dfdy(h)));
}

fragment half4 gardenFragment(MeshFragmentIn in [[stage_in]],
                              constant GlobeUniforms &uniforms [[buffer(0)]],
                              constant GardenLook &look [[buffer(1)]],
                              constant EffectUniforms &effects [[buffer(2)]],
                              texture2d<float> lightsTexture [[texture(1)]],
                              texture2d<float> coastTexture [[texture(2)]],
                              texture2d<float> reliefTexture [[texture(3)]],
                              texture2d<float> markTexture [[texture(6)]],
                              texture2d<float> fadeTexture [[texture(7)]],
                              sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    float pixelAngle = max(max(length(dfdx(nG)), length(dfdy(nG))), 1e-5);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nM = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float coastWidth = max(fwidth(coast), 1e-4);
    float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float water = 1.0 - coastCoverage(coast, coastWidth);
    float land = 1.0 - water;
    float relief = normalHeight.w;
    float cosLatitude = max(length(nG.xz), 1e-3);
    float latitudeDegrees = (0.5 - coordinates.uv.y) * 180.0;
    float dSea = -coast;
    MarkTap mark = markTap(markTexture, surfaceSampler, coordinates.uv, gradient);
    float markFade = 1.0;
    if (look.markRecovery > 0.0) {
        float peak = fadeTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
        float clock = effects.state.w;
        markFade = clock > 0.0 ? 1.0 - smoothstep(0.0, look.markRecovery, clock - peak) : 0.0;
    }
    float markCoverage = mark.coverage * markFade;

    float inflate = 1.0;
    float ripplePulse = 0.0;
    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        dSea -= look.pressBend * pressWeight * saturate(effects.dent.w / look.pressDepth);
        inflate = effects.radii.w;
        relief *= effects.radii.w;
        if (effects.detail.w > 0.0 && effects.ripple.w >= 0.0) {
            float angle = acos(clamp(dot(nG, effects.ripple.xyz), -1.0, 1.0));
            float front = angle - effects.wave.w * effects.ripple.w;
            float width = max(effects.wave.z, pixelAngle * 2.0);
            ripplePulse = exp(-(front * front) / (width * width)) * exp(-effects.state.x * effects.ripple.w) * effects.detail.w;
        }
    }

    float ringLimit = look.ringBand * saturate(inflate * 1.15);
    float phaseBlend = smoothstep(ringLimit - look.rakeSpacing, ringLimit, dSea);
    float phase = mix(dSea / look.rakeSpacing, latitudeDegrees / look.rakeSpacing, phaseBlend);
    float straightReveal = smoothstep(0.85, 1.0, inflate);
    float reveal = mix(1.0, straightReveal, phaseBlend);
    float gStatic = (0.5 - 0.5 * cos(2.0 * M_PI_F * phase)) * water * reveal;
    gStatic = mix(gStatic, 0.5, smoothstep(0.3, 0.5, fwidth(phase)));
    float markDensity = fwidth(mark.phase);
    float gMark = 0.5 - 0.5 * cos(2.0 * M_PI_F * mark.phase);
    gMark = mix(gMark, 0.5, smoothstep(0.3, 0.5, markDensity));
    float g = mix(gStatic, gMark, markCoverage);
    float markPeriod = min(pixelAngle / max(markDensity, 1e-4), 0.2);
    float hStatic = look.grooveTilt * (look.rakeSpacing * M_PI_F / 180.0) / M_PI_F * gStatic;
    float hMark = look.grooveTilt * markPeriod / M_PI_F * gMark;
    float h = mix(hStatic, hMark, markCoverage);
    float3 nB = gardenBump(nG, in.spherePosition, h);

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);

    float fineFade = smoothstep(1.5, 4.0, look.grainFine * (M_PI_F / 180.0) / pixelAngle);
    float coarseFade = smoothstep(1.5, 4.0, look.grainCoarse * (M_PI_F / 180.0) / pixelAngle);
    float grainFine = mix(0.5, gardenNoise(nG * (57.2958 / look.grainFine)), fineFade);
    float grainCoarse = mix(0.5, gardenNoise(nG * (57.2958 / look.grainCoarse) + 7.0), coarseFade);
    float grainTint = gardenNoise(nG * 23.0 + 3.0);
    float3 gravelAlbedo = look.gravel.xyz * (1.0 + look.grainContrast * (2.0 * grainFine - 1.0 + grainCoarse - 0.5));
    gravelAlbedo *= mix(float3(1.03, 1.0, 0.96), float3(0.97, 0.99, 1.03), grainTint);
    gravelAlbedo *= 1.0 - look.grooveShade * g;
    float3 gravelDay = gravelAlbedo * (0.45 + 0.55 * saturate(dot(nB, sun)));
    float3 gravelNight = gravelAlbedo * look.moon.xyz * (0.22 + look.moonStrength * saturate(dot(nB, -sun)));
    float3 gravel = mix(gravelNight, gravelDay, daylight);

    float gravelMask = max(water, markCoverage);
    if (gravelMask > 0.0) {
        GardenCell micaCell = gardenCell(coordinates.uv, cosLatitude, look.micaCell, 5.0, 0.3);
        if (micaCell.random.x < look.micaChance) {
            float3 helper = abs(nB.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
            float3 east = normalize(cross(helper, nB));
            float3 north = cross(nB, east);
            float3 cellNormal = normalize(nB + (micaCell.random.y - 0.5) * 0.6 * east + (micaCell.random.z - 0.5) * 0.6 * north);
            gravel += look.mica.xyz * pow(saturate(dot(reflect(-view, cellNormal), sun)), look.micaSharpness) * daylight;
        }
    }

    float mossMask = land * (1.0 - markCoverage);
    float3 mossDay = float3(0.0);
    float3 mossNight = float3(0.0);
    if (mossMask > 0.0) {
        float variety = gardenNoise(nG * 6.0 + 11.0);
        float3 mossAlbedo = mix(look.moss.xyz, look.mossLight.xyz, variety);
        float wrap = saturate((dot(nM, sun) + 0.2) / 1.2);
        float viewCosine = saturate(dot(nG, view));
        float sheen = pow(1.0 - viewCosine, look.mossSheenPower) * look.mossSheenStrength;
        float rock = smoothstep(look.rockLevel, look.rockLevel + 0.15, relief);
        float lichenSpot = smoothstep(0.62, 0.78, gardenNoise(nG * 140.0 + 5.0));
        float3 rockAlbedo = mix(look.granite.xyz, look.lichen.xyz, lichenSpot * 0.6);
        float3 landAlbedo = mix(mossAlbedo, rockAlbedo, rock);
        float3 landDay = landAlbedo * wrap + look.mossSheen.xyz * sheen * (1.0 - rock);
        float pebbleMask = coastCoverage(look.pebbleBand - coast, coastWidth) * land;
        GardenCell pebbleCell = gardenCell(coordinates.uv, cosLatitude, look.pebbleCell, 17.0, 0.3);
        float3 helper = abs(nG.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
        float3 east = normalize(cross(helper, nG));
        float3 north = cross(nG, east);
        float2 pebbleTilt = pebbleCell.offset / look.pebbleCell;
        float3 pebbleNormal = normalize(nG + pebbleTilt.x * 0.8 * east + pebbleTilt.y * 0.8 * north);
        float pebbleWrap = saturate((dot(pebbleNormal, sun) + 0.2) / 1.2);
        float3 pebbleDay = look.pebble.xyz * pebbleWrap;
        landDay = mix(landDay, pebbleDay, pebbleMask);
        float3 landNight = landAlbedo * look.nightMoss.xyz * (0.15 + look.moonStrength * saturate(dot(nM, -sun)));
        float3 pebbleNight = look.pebble.xyz * look.moon.xyz * (0.15 + look.moonStrength * saturate(dot(pebbleNormal, -sun)));
        landNight = mix(landNight, pebbleNight, pebbleMask);
        mossDay = landDay;
        mossNight = landNight;
    }
    float3 moss = mix(mossNight, mossDay, daylight);

    float3 color = gravel * gravelMask + moss * mossMask;

    float warmth = (1.0 - smoothstep(0.0, look.terminatorWidth * 6.0, muG)) * daylight;
    color = mix(color, color * look.twilight.xyz * 1.5, warmth * 0.4);
    color += look.cityLight.xyz * smoothstep(0.2, 0.7, lights) * nightGate * 0.8 * land;

    if (effectsActive(effects) && ripplePulse > 0.0) {
        color += look.mica.xyz * (look.rippleGlint * ripplePulse * g * gravelMask * max(daylight, 0.4));
    }

    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 gardenBackground(FullscreenVertex in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant GardenLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    float3 color = look.backdrop.xyz;
    BackdropPoint stain = backdropPoint(direction, look.stainCells, 3.0, focal);
    float radius = 0.6 / look.stainCells * focal;
    float fade = saturate(1.0 - length(stain.offset) / radius);
    color = mix(color, look.stain.xyz, look.stainStrength * fade * fade);
    float trowel = sin(pixel.y * 0.02 + gardenNoise(float3(pixel.x * 0.02, 0.0, 7.0)) * 6.0);
    color *= 1.0 + trowel * 0.015;
    float grain = gardenNoise(float3(pixel.x * 0.35, pixel.y * 0.35, 3.0));
    color *= 1.0 + (grain - 0.5) * look.grainBackdrop;
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
