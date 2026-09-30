#include "GlobeShared.h"

struct MagmaLook {
    float4 backdrop;
    float4 crust;
    float4 crustShade;
    float4 crustSheen;
    float4 oxide;
    float4 obsidian;
    float4 obsidianSky;
    float4 ember;
    float4 flame;
    float4 molten;
    float4 whiteHot;
    float4 nightCrust;
    float4 cityLight;
    float4 twilight;
    float4 haze;
    float plateScale;
    float plateDetail;
    float crackWidth;
    float detailWidth;
    float glowWidth;
    float emberDay;
    float emberNight;
    float pillow;
    float widening;
    float bleed;
    float coastGlow;
    float coastWidth;
    float seaGloss;
    float seaSheen;
    float glassScale;
    float summitGlow;
    float recovery;
    float twilightWidth;
    float rimLight;
    float eruption;
    float pulse;
    float fracture;
    float wrap;
    float reserved;
};

struct MagmaCell {
    float edge;
    float3 away;
    float2 id;
    float pair;
};

struct MagmaPoint {
    float latitude;
    float longitude;
    float3 east;
    float3 north;
    float cosP;
};

static MagmaPoint magmaPoint(float3 normal) {
    float cosP = max(length(normal.xz), 1e-4);
    float3 east = float3(normal.z, 0.0, -normal.x) / cosP;
    return {asin(clamp(normal.y, -1.0, 1.0)), atan2(normal.x, normal.z), east, cross(normal, east), cosP};
}

static float magmaWrap(float angle) {
    return angle - 2.0 * M_PI_F * floor(angle / (2.0 * M_PI_F) + 0.5);
}

static float magmaCos(float angle) {
    if (abs(angle) < 0.6) {
        float square = angle * angle;
        return 1.0 - square * (0.5 - square * (1.0 / 24.0 - square / 720.0));
    }
    return cos(angle);
}

static float3 magmaSite(float row, float column, float rows, float seed, float band) {
    float latitude = M_PI_F * 0.5 - (row + 0.5) * band;
    float columns = max(floor(2.0 * rows * cos(latitude) + 0.5), 1.0);
    float3 jitter = hash33(float3(row, column, seed));
    float delta = (0.35 - 0.7 * jitter.y) * band;
    return float3(latitude + delta, 2.0 * M_PI_F * (column + 0.15 + 0.7 * jitter.x) / columns - M_PI_F, 0.0);
}

static MagmaCell magmaCell(MagmaPoint point, float rows, float seed) {
    float band = M_PI_F / rows;
    float waves = max(floor(rows * 0.2), 2.0);
    float calm = smoothstep(0.08, 0.3, point.cosP) * 0.3 * band;
    float latitude = point.latitude + calm * sin(waves * point.longitude + 1.7 * waves * point.latitude + seed);
    float longitude = point.longitude + calm / max(point.cosP, 0.2) * sin(1.3 * waves * point.latitude - waves * point.longitude + seed * 1.3);
    float sinP = sin(latitude);
    float cosP = cos(latitude);
    float row = clamp(floor((0.5 - latitude / M_PI_F) * rows), 0.0, rows - 1.0);
    float middle = M_PI_F * 0.5 - (row + 0.5) * band;
    float sinMiddle = sin(middle);
    float cosMiddle = cos(middle);
    float sinBand = sin(band);
    float cosBand = cos(band);
    bool polar = cosP < 0.3;
    float first = 1e9;
    float second = 1e9;
    float2 nearestId = float2(0.0);
    float2 runnerId = float2(0.0);
    for (int dr = -1; dr <= 1; dr++) {
        float r = row + float(dr);
        if (r < 0.0 || r >= rows) {
            continue;
        }
        float side = -float(dr);
        float along = dr == 0 ? 1.0 : cosBand;
        float sinR = sinMiddle * along + cosMiddle * sinBand * side;
        float cosR = cosMiddle * along - sinMiddle * sinBand * side;
        float columns = max(floor(2.0 * rows * cosR + 0.5), 1.0);
        float spacing = 2.0 * M_PI_F / columns;
        float column = floor((longitude + M_PI_F) / spacing);
        for (int dc = -1; dc <= 1; dc++) {
            if (float(dc + 1) >= columns) {
                continue;
            }
            float c = column + float(dc);
            float wrapped = c - columns * floor(c / columns);
            float2 jitter = hash33(float3(r, wrapped, seed)).xy;
            float delta = (0.35 - 0.7 * jitter.y) * band;
            float offset = magmaWrap((c + 0.15 + 0.7 * jitter.x) * spacing - M_PI_F - longitude);
            float chord;
            if (polar) {
                float half2 = 0.5 * delta * delta;
                float sinF = sinR * (1.0 - half2) + cosR * delta;
                float cosF = cosR * (1.0 - half2) - sinR * delta;
                chord = 2.0 - 2.0 * (sinP * sinF + cosP * cosF * magmaCos(offset));
            } else {
                float across = offset * cosP;
                float up = middle + band * side + delta - latitude;
                chord = across * across + up * up;
            }
            if (chord < first) {
                second = first;
                runnerId = nearestId;
                first = chord;
                nearestId = float2(r, wrapped);
            } else if (chord < second) {
                second = chord;
                runnerId = float2(r, wrapped);
            }
        }
    }
    float3 nearest = magmaSite(nearestId.x, nearestId.y, rows, seed, band);
    float3 runner = magmaSite(runnerId.x, runnerId.y, rows, seed, band);
    float between;
    if (polar) {
        between = 2.0 - 2.0 * (sin(nearest.x) * sin(runner.x) + cos(nearest.x) * cos(runner.x) * magmaCos(magmaWrap(runner.y - nearest.y)));
    } else {
        float across = magmaWrap(runner.y - nearest.y) * cosP;
        float up = runner.x - nearest.x;
        between = across * across + up * up;
    }
    float edge = (second - first) / (2.0 * sqrt(max(between, 1e-10)));
    float3 away = point.east * (magmaWrap(longitude - nearest.y) * cosP) + point.north * (latitude - nearest.x);
    return {edge, away, nearestId, dot(nearestId + runnerId, float2(1.0, 7.31))};
}

static float magmaSwell(float3 point) {
    float a = sin(point.x * 1.7 + sin(point.y * 2.3 + 1.1) * 1.3);
    float b = sin(point.y * 1.9 + sin(point.z * 2.1 + 2.3) * 1.2);
    float c = sin(point.z * 1.5 + sin(point.x * 2.7 + 0.7) * 1.4);
    return 0.5 + (a + b + c) * 0.19;
}

static float3 magmaHeat(float temperature, constant MagmaLook &look) {
    float t = saturate(temperature);
    float3 color = look.ember.xyz * smoothstep(0.0, 0.3, t);
    color = mix(color, look.flame.xyz, smoothstep(0.28, 0.62, t));
    color = mix(color, look.molten.xyz, smoothstep(0.58, 0.86, t));
    color = mix(color, look.whiteHot.xyz, smoothstep(0.84, 1.0, t));
    return color * (0.3 + 3.2 * t * t * t);
}

static float magmaLine(float edge, float halfWidth, float pixelAngle) {
    float width = max(halfWidth, pixelAngle * 0.75);
    return (1.0 - smoothstep(width - pixelAngle * 0.5, width + pixelAngle * 0.5, edge)) * (halfWidth / width);
}

static float magmaSpokes(float3 point, float3 center, float radius, float amount, float pixelAngle) {
    float3 helper = abs(center.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 east = normalize(cross(helper, center));
    float3 north = cross(center, east);
    float3 offset = point - center * dot(point, center);
    float distance = length(offset);
    float reach = distance / radius;
    if (reach > amount * 1.1 + 0.05 || dot(point, center) < 0.0) {
        return 0.0;
    }
    float angle = atan2(dot(offset, north), dot(offset, east));
    const float spokes = 7.0;
    float sector = angle / (2.0 * M_PI_F) * spokes;
    float line = 0.0;
    for (int k = -1; k <= 1; k++) {
        float index = floor(sector) + float(k);
        float track = fmod(index + spokes * 8.0, spokes);
        float3 random = hash33(float3(track, 3.0, 11.0));
        float wander = sin(reach * (9.0 + 5.0 * random.z) + random.x * 6.2831853) * 0.18 / max(reach, 0.15);
        float spokeAngle = (index + 0.5 + 0.6 * (random.x - 0.5)) * 2.0 * M_PI_F / spokes + wander;
        float extent = amount * (0.6 + 0.5 * random.y);
        float across = abs(sin(angle - spokeAngle)) * distance;
        float taper = 1.0 - smoothstep(extent * 0.55, extent, reach);
        float width = pixelAngle * (0.4 + 1.2 * taper);
        float spoke = (1.0 - smoothstep(width * 0.5, width * 1.5, across)) * taper * step(0.0, cos(angle - spokeAngle));
        line = max(line, spoke);
    }
    return line * smoothstep(0.02, 0.12, reach);
}

fragment half4 magmaFragment(MeshFragmentIn in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant MagmaLook &look [[buffer(1)]],
                             constant EffectUniforms &effects [[buffer(2)]],
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
    float terminatorWidth = max(fwidth(muG), look.twilightWidth);
    float pixelAngle = max(max(length(dfdx(nG)), length(dfdy(nG))), 1e-5);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    gradient2d haloGradient = gradient2d(coordinates.dx * 7.0, coordinates.dy * 7.0);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nM = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float coastWidth = max(fwidth(coast), 1e-4);
    float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float halo = lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r;
    float water = 1.0 - coastCoverage(coast, coastWidth);
    float onLand = 1.0 - water;
    float relief = normalHeight.w;
    float regional = reliefTexture.sample(surfaceSampler, coordinates.uv, level(4.5)).w;
    float footprintDegrees = pixelAngle * 57.29578;

    float heat = 0.0;
    float clock = effects.state.w;
    if (clock > 0.0) {
        heat = 1.0 - snowLevelBilinear(snowTexture, surfaceSampler, coordinates.uv, clock, max(look.recovery, 0.01));
    }

    float3 landNormal = nM;
    float3 seaNormal = nG;
    float pulse = 0.0;
    float forming = 0.0;
    float popHeat = 0.0;
    float eruption = 0.0;
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        landNormal = normalize(mix(nG, nM, effects.radii.w) - slope);
        seaNormal = normalize(nG - slope - effects.wave.x * rippleSlope(nG, effects));
        relief *= effects.radii.w;
        forming = pow(saturate(1.0 - effects.radii.w), 0.75);
        if (effects.detail.w > 0.0 && effects.ripple.w >= 0.0) {
            float angle = acos(clamp(dot(nG, effects.ripple.xyz), -1.0, 1.0));
            float front = angle - effects.wave.w * effects.ripple.w;
            float width = max(effects.wave.z, pixelAngle * 2.0);
            pulse = exp(-(front * front) / (width * width)) * exp(-effects.state.x * effects.ripple.w) * effects.detail.w;
        }
        float popWeight = effectWeight(nG, effects.bump.xyz, effects.radii.y);
        popHeat = saturate(effects.radii.z * popWeight);
        eruption = effects.radii.z * popWeight * popWeight * popWeight;
    }

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);
    float warmth = (1.0 - smoothstep(0.0, look.twilightWidth * 5.0, muG)) * daylight;
    float viewCosine = saturate(dot(nG, view));
    float3 halfVector = sun + view;
    float3 halfway = halfVector * rsqrt(max(dot(halfVector, halfVector), 1e-8));

    float3 emission = float3(0.0);
    float3 color = float3(0.0);

    float activity = 0.0;
    if (abs(coast) < 1.6) {
        activity = smoothstep(0.5, 0.78, magmaSwell(nG * 11.0 + 3.1));
    }
    float lavaHalf = look.coastWidth * (0.5 + activity);
    float lavaSpan = max(lavaHalf, footprintDegrees * 0.8);
    float lavaLine = (1.0 - smoothstep(lavaSpan - footprintDegrees * 0.5, lavaSpan + footprintDegrees * 0.5, abs(coast))) * (lavaHalf / lavaSpan) * activity;

    if (onLand > 0.0) {
        float shore = activity * exp(-max(coast, 0.0) / 0.35) * 0.45;
        float flare = saturate(heat + pulse * look.pulse + forming + popHeat + shore);
        float shaped = pow(flare, 0.8);
        float rows = look.plateScale;
        MagmaPoint site = magmaPoint(nG);
        MagmaCell plate = magmaCell(site, rows, 7.0);
        float plateEdge = plate.edge;
        float3 plateRandom = hash33(float3(plate.id, 41.0));
        float3 seamRandom = hash33(float3(plate.pair, 5.0, 3.0));
        float platePixels = M_PI_F / (rows * pixelAngle);
        float resolved = smoothstep(3.0, 9.0, platePixels);

        float detailRows = rows * look.plateDetail;
        float detailPixels = M_PI_F / (detailRows * pixelAngle);
        float detailEdge = 1.0;
        float3 detailAway = float3(0.0);
        float detailSeam = 0.0;
        float detailResolved = smoothstep(9.0, 20.0, detailPixels) * smoothstep(0.0, 0.08, shaped);
        if (detailResolved > 0.0) {
            MagmaCell shard = magmaCell(site, detailRows, 19.0);
            detailEdge = shard.edge;
            detailAway = shard.away;
            detailSeam = hash33(float3(shard.pair, 9.0, 1.0)).x;
        }

        float dome = look.pillow * resolved;
        float3 crustNormal = normalize(landNormal + plate.away * dome * rows / M_PI_F + detailAway * look.pillow * 0.5 * detailRows / M_PI_F * detailResolved);

        float mountain = smoothstep(0.3, 0.65, relief);
        float summit = max(smoothstep(0.4, 0.55, relief) * smoothstep(0.03, 0.1, relief - regional), smoothstep(0.88, 1.0, relief));
        float slopeTilt = 1.0 - saturate(dot(nM, nG));
        float field = magmaSwell(nG * 3.5 + 7.0);
        float region = 0.35 + 0.65 * smoothstep(0.25, 0.75, field);
        float seam = mix(0.25, 1.0, seamRandom.x * seamRandom.x) * region;
        float widthScale = 1.0 + look.widening * shaped;
        float present = smoothstep(0.22, 0.3, seamRandom.z + shaped);
        float glowSpan = look.glowWidth * (1.0 + shaped);
        float majorLine = 0.0;
        float minorLine = 0.0;
        float majorGlow = 0.0;
        float minorGlow = 0.0;
        float temperature = 0.0;
        float minorTemperature = 0.0;
        float hotSpot = 0.0;
        bool nearMajor = plateEdge < glowSpan * 6.0;
        bool nearMinor = detailResolved > 0.0 && detailEdge < glowSpan * 2.5;
        if (nearMajor || nearMinor) {
            hotSpot = smoothstep(0.3, 0.85, magmaSwell(nG * 60.0 + seamRandom * 5.0));
            float baseTemperature = mix(look.emberDay, look.emberNight, nightGate) * seam * (1.0 + 0.5 * mountain + 1.1 * summit) * mix(0.5, 1.2, hotSpot);
            temperature = baseTemperature + (1.0 - baseTemperature) * shaped;
            minorTemperature = baseTemperature * 0.55 * detailSeam + (1.0 - baseTemperature * 0.55) * shaped * mix(0.6, 1.0, detailSeam);
            majorLine = magmaLine(plateEdge, look.crackWidth * widthScale * mix(0.7, 1.25, seamRandom.y), pixelAngle) * (0.35 + 0.65 * resolved) * present;
            minorLine = magmaLine(detailEdge, look.detailWidth * widthScale, pixelAngle) * detailResolved * smoothstep(0.3, 0.5, detailSeam + shaped);
            majorGlow = exp(-plateEdge / glowSpan) * present;
            minorGlow = exp(-detailEdge / (glowSpan * 0.4)) * detailResolved;
        }

        float lit = saturate((dot(crustNormal, sun) + look.wrap) / (1.0 + look.wrap));
        float plateTone = 0.78 + 0.34 * plateRandom.x;
        float tint = smoothstep(0.25, 0.7, 1.0 - field);
        float3 crustAlbedo = mix(look.crust.xyz * float3(0.9, 0.93, 1.0), look.crust.xyz * float3(1.18, 1.05, 0.95), tint);
        crustAlbedo = mix(crustAlbedo, look.oxide.xyz, smoothstep(0.8, 0.98, plateRandom.y) * 0.75);
        crustAlbedo *= plateTone;
        float crevice = max(magmaLine(plateEdge, look.crackWidth * 2.4, pixelAngle) * present, minorLine * 0.45);
        float3 crustDay = mix(look.crustShade.xyz, crustAlbedo, lit) * (1.0 - 0.6 * crevice);
        crustDay = mix(crustDay, crustDay * look.twilight.xyz * 1.9, warmth * 0.55);
        float nh = saturate(dot(crustNormal, halfway));
        float glassy = 1.0 - crevice;
        crustDay += look.crustSheen.xyz * (pow(nh, 46.0) * 0.26 + pow(nh, 6.0) * 0.025) * saturate(muG * 5.0) * glassy;
        float3 crustNight = look.nightCrust.xyz * (0.55 + 0.45 * plateTone) * (0.7 + 0.3 * saturate(dot(crustNormal, view)));
        crustDay = mix(crustDay, crustDay * look.twilight.xyz * 1.3 + magmaHeat(0.3, look) * 0.25, summit * 0.35);
        color += mix(crustNight, crustDay, daylight) * onLand;

        if (nearMajor || nearMinor) {
            float core = 1.0 - smoothstep(0.0, look.crackWidth * widthScale, plateEdge);
            emission += magmaHeat(temperature * (0.82 + 0.18 * core), look) * majorLine * onLand;
            emission += magmaHeat(minorTemperature, look) * minorLine * onLand;
            emission += magmaHeat(temperature * 0.7, look) * majorGlow * ((0.05 + 0.22 * nightGate) * seam * hotSpot + look.bleed * shaped) * onLand;
            emission += magmaHeat(minorTemperature * 0.7, look) * minorGlow * look.bleed * shaped * 0.6 * onLand;
        }
        emission += magmaHeat(0.45, look) * shaped * shaped * shaped * 0.1 * onLand;
        emission += magmaHeat(0.42 + 0.18 * hotSpot, look) * summit * look.summitGlow * (0.45 + 0.55 * nightGate) * exp(-slopeTilt * 3.0) * onLand;

        if (nightGate > 0.0) {
            float core = lights * lights;
            float3 glowLights = look.cityLight.xyz * (core * 1.4 + pow(halo, 1.4) * 0.35) + look.whiteHot.xyz * core * core * 0.8;
            emission += glowLights * nightGate * onLand;
        }
    }

    if (water > 0.0) {
        float3 reflected = reflect(direction, seaNormal);
        float3 r = float3(dot(reflected, uniforms.cameraRight.xyz), dot(reflected, uniforms.cameraUp.xyz), -dot(reflected, uniforms.cameraForward.xyz));
        float sky = smoothstep(-0.35, 0.95, r.y);
        float3 environment = look.obsidianSky.xyz * (0.06 + 0.94 * sky * sky) + look.haze.xyz * exp(-abs(r.y - 0.05) * 5.0) * 0.3;
        float cosine = saturate(dot(seaNormal, view));
        float grazing = 1.0 - cosine;
        float fresnel = 0.04 + 0.96 * grazing * grazing * grazing * grazing * grazing;
        float seaLit = saturate(dot(seaNormal, sun) * 0.8 + 0.2) * daylight;
        float3 sea = look.obsidian.xyz * (0.55 + 1.6 * seaLit);
        sea += environment * fresnel * look.seaSheen * mix(0.45, 1.0, daylight);
        float nh = saturate(dot(seaNormal, halfway));
        sea += look.whiteHot.xyz * (pow(nh, look.seaGloss) * 3.0 + pow(nh, look.seaGloss * 0.02) * 0.008) * saturate(muG * 6.0);
        float seaward = max(-coast, 0.0);
        float steam = exp(-seaward / 0.22) * activity;
        sea += look.flame.xyz * steam * fresnel * 2.0 * look.coastGlow;
        emission += magmaHeat(0.55, look) * steam * 0.06 * look.coastGlow * mix(0.5, 1.0, nightGate) * water;
        float quench = saturate(heat + popHeat);
        if (quench > 0.01) {
            float glassRows = look.plateScale * look.glassScale;
            MagmaCell shard = magmaCell(magmaPoint(nG), glassRows, 31.0);
            float glass = pow(quench, 0.8);
            float fracture = magmaLine(shard.edge, look.crackWidth * (0.6 + look.widening * glass * 0.6), pixelAngle);
            float seep = exp(-shard.edge / (look.glowWidth * (0.6 + glass)));
            float3 lava = magmaHeat(0.25 + 0.75 * glass, look);
            emission += (lava * fracture * smoothstep(0.0, 0.25, glass) + magmaHeat(glass * 0.6, look) * seep * glass * look.bleed * 0.6) * water;
            sea *= 1.0 - 0.5 * fracture * smoothstep(0.0, 0.3, glass);
        }
        color += sea * water;
    }

    if (lavaLine > 0.0) {
        float lavaPulse = smoothstep(0.25, 0.8, magmaSwell(nG * 45.0 + 1.7));
        emission += magmaHeat(0.52 + 0.3 * activity * lavaPulse, look) * lavaLine * mix(0.35, 1.0, lavaPulse) * look.coastGlow * mix(0.6, 1.0, nightGate);
    }

    float3 rim = look.haze.xyz * pow(1.0 - viewCosine, 3.0) * look.rimLight;
    color += rim * mix(0.6, 1.0, daylight);

    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
        if (effects.detail.y > 0.0) {
            float spokes = magmaSpokes(nG, effects.dent.xyz, effects.radii.x, saturate(effects.detail.y), pixelAngle);
            emission += magmaHeat(0.8, look) * spokes * look.fracture * onLand;
        }
        emission += magmaHeat(0.7 + 0.3 * saturate(eruption), look) * eruption * look.eruption;
    }

    color += emission;
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 magmaBackground(FullscreenVertex in [[stage_in]],
                               constant GlobeUniforms &uniforms [[buffer(0)]],
                               constant MagmaLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float scale = uniforms.viewport.x / 1206.0;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = look.backdrop.xyz * mix(1.3, 0.55, smoothstep(0.1, 0.9, length(screen)));
    float outside = max(reach - 1.0, 0.0);
    color += look.haze.xyz * (0.12 * exp(-outside * 5.0) + 0.022 * exp(-outside * 1.1));
    float below = saturate((pixel.y - disk.y) / disk.z);
    color += look.flame.xyz * 0.012 * below * exp(-outside * 1.5);
    BackdropPoint spark = backdropPoint(direction, 70.0, 7.0, focal);
    if (spark.random.x < 0.2) {
        float size = (0.7 + 1.1 * spark.random.y) * scale;
        float3 tint = mix(look.ember.xyz, look.molten.xyz, spark.random.z * spark.random.z);
        color += tint * (0.2 + 1.2 * pow(spark.random.y, 3.0)) * exp(-dot(spark.offset, spark.offset) / (size * size));
    }
    BackdropPoint drift = backdropPoint(direction, 26.0, 19.0, focal);
    if (drift.random.x < 0.22) {
        float radius = (2.5 + 4.5 * drift.random.y) * scale;
        float fade = saturate(1.0 - length(drift.offset) / radius);
        color += mix(look.ember.xyz, look.flame.xyz, drift.random.z) * 0.05 * (0.4 + drift.random.z) * fade * fade;
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
