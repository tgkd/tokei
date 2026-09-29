#include "GlobeShared.h"

struct IceLook {
    float4 backdrop;
    float4 deepWater;
    float4 shelfWater;
    float4 nightWater;
    float4 snow;
    float4 snowShade;
    float4 packedSnow;
    float4 glacier;
    float4 glacierGlow;
    float4 floe;
    float4 nightLand;
    float4 cityLight;
    float4 twilight;
    float4 rim;
    float4 aurora;
    float4 frost;
    float sparkle;
    float sparkleSharpness;
    float sparkleScatter;
    float glitter;
    float packIce;
    float floeSize;
    float wallGlow;
    float striations;
    float snowCover;
    float snowRecovery;
    float snowDepth;
    float snowRim;
    float auroraStrength;
    float twilightWidth;
    float frostBloom;
    float reserved;
};

struct FloeCell {
    float edge;
    float2 id;
    float2 away;
};

struct SnowField {
    float level;
    float2 slope;
};

struct SnowShape {
    float packed;
    float height;
    float rate;
};

struct PixelFootprint {
    float3 dx;
    float3 dy;
    float angle;
};

constant float3 magneticNorth = float3(-0.1543, 0.9869, 0.0481);

static FloeCell floeCell(float2 point, float seed) {
    float2 base = floor(point);
    float2 local = point - base;
    float first = 8.0;
    float second = 8.0;
    float2 id = base;
    float2 away = float2(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 offset = float2(float(x), float(y));
            float2 delta = local - offset - hash33(float3(base + offset, seed)).xy;
            float distance = dot(delta, delta);
            if (distance < first) {
                second = first;
                first = distance;
                id = base + offset;
                away = delta;
            } else if (distance < second) {
                second = distance;
            }
        }
    }
    return {sqrt(second) - sqrt(first), id, away};
}

static float2 screenOffset(float3 offset, PixelFootprint footprint) {
    float aa = dot(footprint.dx, footprint.dx);
    float ab = dot(footprint.dx, footprint.dy);
    float bb = dot(footprint.dy, footprint.dy);
    float av = dot(footprint.dx, offset);
    float bv = dot(footprint.dy, offset);
    float determinant = max(aa * bb - ab * ab, 1e-24);
    return float2(bb * av - ab * bv, aa * bv - ab * av) / determinant;
}

static float glintLayer(float3 point, float cellAngle, PixelFootprint footprint, float3 normal, float3 view, float3 sun,
                        float scatter, float sharpness, float density, float arms, float seed, thread float &tint) {
    float3 cell = floor(point / cellAngle);
    float3 random = hash33(cell + seed);
    if (random.x > density) {
        return 0.0;
    }
    float3 jitter = hash33(cell + seed + 17.0);
    float3 facet = normalize(normal + (jitter.zxy - 0.5) * scatter);
    float strength = pow(saturate(dot(reflect(view, facet), sun)), sharpness) * (0.25 + 0.75 * random.y * random.y);
    if (strength < 0.003) {
        return 0.0;
    }
    tint = random.z;
    float3 center = normalize((cell + 0.35 + 0.3 * jitter) * cellAngle);
    float2 offset = screenOffset(center - point, footprint);
    float core = exp(-dot(offset, offset) * 0.9);
    if (arms <= 0.0) {
        return strength * core;
    }
    float reach = 0.5 + 1.1 * saturate(strength);
    float2 across = offset * offset * 5.0;
    float star = exp(-abs(offset.x) / reach - across.y) + exp(-abs(offset.y) / reach - across.x);
    return strength * (core + arms * star * 0.5);
}

static float3 glints(float3 point, PixelFootprint footprint, float cellPixels, float3 normal, float3 view, float3 sun,
                     float scatter, float sharpness, float density, float arms, float seed, float3 cool) {
    float level = log2(max(cellPixels * footprint.angle, 1e-6) / 1e-4);
    float lower = floor(level);
    float coarseAngle = 1e-4 * exp2(lower + 1.0);
    float layer = hash33(floor(point / coarseAngle) + seed + 97.0).x < level - lower ? lower + 1.0 : lower;
    float tint = 0.0;
    float glint = glintLayer(point, 1e-4 * exp2(layer), footprint, normal, view, sun, scatter, sharpness, density, arms, seed + layer * 7.0, tint);
    return mix(float3(1.0), cool, tint) * glint;
}

static SnowShape snowShape(float level, float bank) {
    float t = saturate((level - 0.17) / 0.66);
    float packed = t * t * (3.0 - 2.0 * t);
    float u = saturate(packed / 0.7);
    float ridgeOffset = packed - 0.78;
    float ridge = exp(-ridgeOffset * ridgeOffset * 50.0);
    float height = u * u * (3.0 - 2.0 * u) - 1.0 + bank * ridge;
    float rate = 6.0 * t * (1.0 - t) / 0.66 * (6.0 * u * (1.0 - u) / 0.7 - bank * ridge * ridgeOffset * 100.0);
    return {packed, height, rate};
}

static float4 bsplineWeights(float t) {
    float s = 1.0 - t;
    return float4(s * s * s, 4.0 + t * t * (3.0 * t - 6.0), 4.0 + s * s * (3.0 * s - 6.0), t * t * t) / 6.0;
}

static float4 bsplineSlopes(float t) {
    float s = 1.0 - t;
    return float4(-s * s, t * (3.0 * t - 4.0), s * (4.0 - 3.0 * s), t * t) * 0.5;
}

static SnowField snowField(texture2d<float> snowTexture, sampler snowSampler, float2 uv, float clock, float recovery) {
    float2 size = float2(snowTexture.get_width(), snowTexture.get_height());
    float2 texel = uv * size - 0.5;
    float2 base = floor(texel);
    float2 t = texel - base;
    float4 wx = bsplineWeights(t.x);
    float4 wy = bsplineWeights(t.y);
    float4 dx = bsplineSlopes(t.x);
    float4 dy = bsplineSlopes(t.y);
    float value = 0.0;
    float slopeX = 0.0;
    float slopeY = 0.0;
    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            float4 levels = snowLevels(snowTexture.gather(snowSampler, (base + float2(2.0 * float(i), 2.0 * float(j))) / size), clock, recovery);
            float2 upper = float2(levels.w, levels.z);
            float2 lower = float2(levels.x, levels.y);
            float2 weightX = float2(wx[2 * i], wx[2 * i + 1]);
            float2 slopeWeightX = float2(dx[2 * i], dx[2 * i + 1]);
            value += wy[2 * j] * dot(upper, weightX) + wy[2 * j + 1] * dot(lower, weightX);
            slopeX += wy[2 * j] * dot(upper, slopeWeightX) + wy[2 * j + 1] * dot(lower, slopeWeightX);
            slopeY += dy[2 * j] * dot(upper, weightX) + dy[2 * j + 1] * dot(lower, weightX);
        }
    }
    return {value, float2(slopeX, slopeY) * size};
}

static float kink(float track, float index, float seed) {
    float segment = floor(index);
    float a = hash33(float3(track, segment, seed)).x;
    float b = hash33(float3(track, segment + 1.0, seed)).x;
    return mix(a, b, index - segment) - 0.5;
}

static float fracture(float3 point, float3 center, float radius, float amount, float pixelAngle) {
    float3 helper = abs(center.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 east = normalize(cross(helper, center));
    float3 north = cross(center, east);
    float3 offset = point - center * dot(point, center);
    float distance = length(offset);
    float reach = distance / radius;
    if (reach > amount + 0.05 || dot(point, center) < 0.0) {
        return 0.0;
    }
    float angle = atan2(dot(offset, north), dot(offset, east));
    const float spokes = 6.0;
    float sector = angle / (2.0 * M_PI_F) * spokes;
    float line = 0.0;
    for (int k = -1; k <= 1; k++) {
        float index = floor(sector) + float(k);
        float track = fmod(index + spokes * 8.0, spokes);
        float3 random = hash33(float3(track, 7.0, 3.0));
        float bend = kink(track, reach / 0.12, 5.0) * 0.16 / max(reach, 0.12);
        float spokeAngle = (index + 0.5 + 0.7 * (random.x - 0.5)) * 2.0 * M_PI_F / spokes + bend;
        float extent = amount * (0.55 + 0.45 * random.y);
        float across = abs(sin(angle - spokeAngle)) * distance / pixelAngle;
        float spoke = (1.0 - smoothstep(0.3, 1.1, across)) * (1.0 - smoothstep(extent * 0.8, extent, reach)) * step(0.0, cos(angle - spokeAngle));
        line = max(line, spoke);
    }
    const float arcs = 11.0;
    for (int j = 0; j < 2; j++) {
        float arc = (angle + M_PI_F) / (2.0 * M_PI_F) * arcs;
        float arcTrack = fmod(floor(arc) + float(j) * 5.0, arcs);
        float wobble = kink(float(j) + 20.0, arc, 9.0);
        float ringRadius = (0.3 + 0.3 * float(j)) * amount + wobble * 0.06;
        float across = abs(reach - ringRadius) * radius / pixelAngle;
        float gate = step(0.45, hash33(float3(arcTrack, float(j), 29.0)).y);
        line = max(line, (1.0 - smoothstep(0.3, 1.1, across)) * gate);
    }
    return line * smoothstep(0.03, 0.08, reach);
}

static float aurora(float3 normal, float3 sun) {
    float3 pole = normalize(magneticNorth);
    float height = dot(normal, pole);
    float latitude = asin(clamp(abs(height), 0.0, 1.0)) * 57.2958;
    float hemisphere = height >= 0.0 ? 1.0 : -1.0;
    float3 poleAxis = pole * hemisphere;
    float3 east = normalize(cross(poleAxis, float3(1.0, 0.0, 0.0)));
    float3 north = cross(east, poleAxis);
    float3 flat = normal - poleAxis * dot(normal, poleAxis);
    float around = atan2(dot(flat, north), dot(flat, east));
    float3 midnight = -sun - poleAxis * dot(-sun, poleAxis);
    float midnightLength = length(midnight);
    float facing = midnightLength > 1e-4 ? dot(flat, midnight) / (max(length(flat), 1e-4) * midnightLength) : 1.0;
    float center = 67.0 + 1.2 * sin(3.0 * around + 0.7 + hemisphere) + 0.7 * sin(7.0 * around + 2.1) + 0.35 * sin(13.0 * around + 0.3) - 2.0 * facing;
    float offset = latitude - center;
    float width = offset < 0.0 ? 0.5 : 2.0;
    float band = exp(-(offset * offset) / (width * width));
    float curtain = 0.45 + 0.55 * smoothstep(-0.6, 0.9, 0.6 * sin(2.0 * around + 1.3 * hemisphere) + 0.4 * sin(5.0 * around + 0.4) + 0.3 * sin(11.0 * around + 2.0));
    return band * curtain * smoothstep(-0.3, 0.8, facing);
}

fragment half4 iceFragment(MeshFragmentIn in [[stage_in]],
                           constant GlobeUniforms &uniforms [[buffer(0)]],
                           constant IceLook &look [[buffer(1)]],
                           constant EffectUniforms &effects [[buffer(2)]],
                           texture2d<float> dayTexture [[texture(0)]],
                           texture2d<float> lightsTexture [[texture(1)]],
                           texture2d<float> coastTexture [[texture(2)]],
                           texture2d<float> reliefTexture [[texture(3)]],
                           texture2d<float> snowTexture [[texture(4)]],
                           sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    PixelFootprint footprint;
    footprint.dx = dfdx(nG);
    footprint.dy = dfdy(nG);
    footprint.angle = max(max(length(footprint.dx), length(footprint.dy)), 1e-5);
    float pixelAngle = footprint.angle;
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    gradient2d haloGradient = gradient2d(coordinates.dx * 8.0, coordinates.dy * 8.0);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nM = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float coastWidth = max(fwidth(coast), 1e-4);
    float water = 1.0 - coastCoverage(coast, coastWidth);
    float onLand = 1.0 - water;
    float relief = saturate(normalHeight.w);
    float bandVisibility = saturate(1.0 - fwidth(relief) * 10.0);
    float inflate = effectsActive(effects) ? effects.radii.w : 1.0;
    float tilt = 1.0 - saturate(dot(nM, nG));
    float wall = smoothstep(0.08, 0.3, tilt) * (1.0 - smoothstep(0.6, 1.4, coast)) * saturate(inflate);
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        nM = normalize(mix(nG, nM, effects.radii.w) - slope - mix(effects.detail.z, 1.0, water) * effects.wave.x * rippleSlope(nG, effects));
        relief *= effects.radii.w;
    }

    float packed = 1.0;
    float shadow = 0.0;
    float clock = effects.state.w;
    float recovery = max(look.snowRecovery, 0.01);
    if (look.snowCover > 0.0 && clock > 0.0 && water < 1.0 && snowLevelBilinear(snowTexture, surfaceSampler, coordinates.uv, clock, recovery) < 1.0) {
        float cosLatitude = max(length(nG.xz), 0.05);
        float3 eastward = float3(nG.z, 0.0, -nG.x) / cosLatitude;
        float3 northward = cross(nG, eastward);
        SnowField field = snowField(snowTexture, surfaceSampler, coordinates.uv, clock, recovery);
        SnowShape shape = snowShape(field.level, look.snowRim);
        packed = shape.packed;
        float3 drift = shape.rate * (field.slope.x / (2.0 * M_PI_F * cosLatitude) * eastward - field.slope.y / M_PI_F * northward);
        nM = normalize(nM - look.snowDepth * onLand * drift);
        float3 toward = sun - nG * muG;
        float towardLength = length(toward);
        float probe = 1.5 * M_PI_F / float(snowTexture.get_height());
        float2 probeStep = towardLength > 1e-4
            ? float2(dot(toward, eastward) / (2.0 * M_PI_F * cosLatitude), -dot(toward, northward) / M_PI_F) * probe / towardLength
            : float2(0.0);
        float ahead = snowLevelBilinear(snowTexture, surfaceSampler, coordinates.uv + probeStep, clock, recovery);
        float elevation = max(muG, 0.05) / max(towardLength, 0.05);
        shadow = smoothstep(0.0, 1.0, (snowShape(ahead, look.snowRim).height - shape.height) * look.snowDepth / (probe * elevation));
    }
    float trough = (1.0 - smoothstep(0.0, 0.7, packed)) * onLand;
    float bank = exp(-(packed - 0.78) * (packed - 0.78) * 50.0) * onLand;
    shadow *= onLand * (1.0 - smoothstep(0.6, 0.9, packed));

    float daylight = smoothstep(-look.twilightWidth, look.twilightWidth, muG);
    float viewCosine = saturate(dot(nG, -direction));

    float ring = 0.0;
    float wake = 0.0;
    float frostWave = 0.0;
    if (effectsActive(effects)) {
        if (effects.detail.w > 0.0 && effects.ripple.w >= 0.0) {
            float angle = acos(clamp(dot(nG, effects.ripple.xyz), -1.0, 1.0));
            float front = angle - effects.wave.w * effects.ripple.w;
            float width = max(effects.wave.z * 0.07, pixelAngle * 1.2);
            float fade = exp(-effects.state.x * effects.ripple.w) * effects.detail.w;
            ring = exp(-(front * front) / (width * width)) * fade;
            wake = (front < 0.0 ? exp(front / (effects.wave.z * 0.7)) : 0.0) * fade;
        }
        if (look.frostBloom > 0.0 && effects.radii.w < 0.999) {
            float progress = saturate(effects.radii.w);
            float front = (1.0 - viewCosine) - (progress * 1.25 - 0.12);
            frostWave = exp(-(front * front) / 0.012) * (1.0 - smoothstep(0.7, 1.0, progress)) * look.frostBloom;
        }
    }

    float waterline = exp(-max(-coast, 0.0) / max(coastWidth * 1.2, 0.012)) * water;
    float floe = 0.0;
    float floeShade = 1.0;
    float floeSide = 0.0;
    float floeSideLit = 0.0;
    float band = look.packIce * smoothstep(0.62, 0.92, abs(nG.y));
    if (look.packIce > 0.0 && water > 0.0 && coast > -band) {
        float reach = saturate(-coast / max(band, 1e-3));
        float fringe = (1.0 - reach) * 0.12;
        float resolved = saturate(look.floeSize / pixelAngle / 10.0 - 1.0);
        floe = fringe;
        if (resolved > 0.0) {
            float2 polarPlane = nG.xz / (1.0 + abs(nG.y));
            FloeCell cell = floeCell(polarPlane / (0.5 * look.floeSize), nG.y > 0.0 ? 5.0 : 11.0);
            float3 random = hash33(float3(cell.id, 9.0));
            float gap = mix(0.05, 0.45, reach) + 0.1 * random.y;
            float softness = pixelAngle / look.floeSize;
            float present = step(random.x, mix(0.95, 0.3, reach));
            float plate = smoothstep(gap - softness, gap + softness, cell.edge) * present;
            float sideWidth = max(0.07, 1.8 * softness);
            float side = plate * (1.0 - smoothstep(gap + sideWidth - softness, gap + sideWidth + softness, cell.edge));
            float3 outward = float3(cell.away.x, 0.0, cell.away.y);
            outward -= nG * dot(outward, nG);
            float3 sunAcross = sun - nG * muG;
            floeSideLit = dot(outward, sunAcross) * rsqrt(max(dot(outward, outward) * dot(sunAcross, sunAcross), 1e-12));
            floe = mix(fringe, plate, resolved);
            floeSide = side * resolved;
            floeShade = 0.85 + 0.15 * random.z;
        }
        floe *= 1.0 - smoothstep(0.75, 1.0, reach);
    }

    float3 color = float3(0.0);
    if (daylight > 0.0) {
        float snowLit = saturate((dot(nM, sun) + 0.3) / 1.3) * (1.0 - 0.8 * shadow);
        float3 snowTop = mix(look.snowShade.xyz, look.snow.xyz, snowLit);
        snowTop = mix(snowTop, look.packedSnow.xyz * mix(0.55, 1.0, snowLit), trough * 0.85);
        snowTop = mix(snowTop, look.snowShade.xyz * 0.8, shadow * 0.35);
        float lip = smoothstep(0.02, 0.07, tilt) * (1.0 - smoothstep(0.07, 0.16, tilt)) * smoothstep(0.3, 0.5, relief) * onLand;
        snowTop += look.snow.xyz * lip * 0.2 * snowLit;

        float wallLit = saturate(dot(nM, sun));
        float height = smoothstep(0.02, 0.5, relief);
        float bands = 0.5 + 0.5 * cos(relief * 2.0 * M_PI_F * 5.0 + 1.7 * sin(dot(nG, float3(37.0, 23.0, 41.0))));
        float3 deepIce = look.glacier.xyz * (1.0 - look.striations * bands * bandVisibility) * mix(0.6, 1.0, height);
        float3 translucence = look.glacierGlow.xyz * look.wallGlow * (0.35 + 0.65 * height) * (0.6 + 0.4 * (1.0 - wallLit));
        float3 litIce = mix(look.glacierGlow.xyz, look.snow.xyz, 0.45) * mix(0.7, 1.0, height);
        float3 wallColor = mix(deepIce + translucence, litIce, wallLit * wallLit);

        float shelf = 1.0 - smoothstep(0.0, 2.0, -coast);
        float3 sea = mix(look.deepWater.xyz, look.shelfWater.xyz, shelf * shelf * shelf);
        float3 toward = sun - nG * muG;
        float towardLength = length(toward);
        float castLength = min(0.012 * towardLength / max(muG, 0.02), 0.06);
        if (water > 0.0 && coast > -castLength * 57.3 - 0.3 && towardLength > 1e-4) {
            float cosLatitude = max(length(nG.xz), 0.05);
            float3 eastward = float3(nG.z, 0.0, -nG.x) / cosLatitude;
            float2 castStep = float2(dot(toward, eastward) / (2.0 * M_PI_F * cosLatitude), -dot(toward, cross(nG, eastward)) / M_PI_F) * castLength / towardLength;
            float caster = coastTexture.sample(surfaceSampler, coordinates.uv + castStep, gradient).r;
            sea *= 1.0 - 0.55 * smoothstep(-0.25, 0.2, caster) * saturate(inflate);
        }
        float seaLit = saturate(muG * 1.4 + 0.25);
        float3 floeTop = look.floe.xyz * mix(0.4, 1.0, seaLit) * floeShade;
        float3 floeEdge = mix(look.glacier.xyz * 0.8, mix(look.glacierGlow.xyz, look.snow.xyz, 0.5), saturate(floeSideLit * 0.8 + 0.35)) * mix(0.5, 1.0, seaLit);
        float3 seaColor = mix(sea * mix(0.65, 1.0, seaLit), mix(floeTop, floeEdge, floeSide), floe);
        seaColor += look.glacierGlow.xyz * waterline * 0.3 * (1.0 - floe);

        float3 day = mix(mix(snowTop, wallColor, wall), seaColor, water * (1.0 - wall));
        float blueHour = (1.0 - smoothstep(0.0, 0.2, muG)) * daylight;
        day = mix(day, day * look.twilight.xyz * 1.6, blueHour * 0.5);
        day *= mix(0.72, 1.0, sqrt(viewCosine));

        float3 halfVector = sun - direction;
        float3 halfway = halfVector * rsqrt(max(dot(halfVector, halfVector), 1e-8));
        float nh = saturate(dot(nM, halfway));
        float seaSpecular = pow(nh, 3000.0) * 0.45 + pow(nh, 260.0) * 0.035;
        float snowSpecular = pow(nh, 16.0) * 0.08;
        day += float3(mix(snowSpecular, seaSpecular * (1.0 - floe), water * (1.0 - wall))) * saturate(muG * 4.0);
        float snowVisible = look.sparkle * saturate(muG * 4.0) * onLand * (1.0 - wall);
        if (snowVisible > 0.0 && nh > 0.75) {
            float boost = (1.0 + 2.0 * bank + 4.0 * wake) * (1.0 - 0.7 * trough);
            float3 sparkle = glints(nG, footprint, 5.0, nM, direction, sun, 1.1, 24.0, 0.4, 0.0, 3.0, look.glacierGlow.xyz * 1.6) * 0.35;
            if (nh > 0.88) {
                sparkle += glints(nG, footprint, 16.0, nM, direction, sun, look.sparkleScatter, look.sparkleSharpness, 0.8, 1.0, 13.0, look.glacierGlow.xyz * 1.6);
            }
            day += sparkle * snowVisible * boost;
        }
        float waterVisible = look.glitter * saturate(muG * 4.0) * water * (1.0 - floe) * (1.0 - wall);
        if (waterVisible > 0.0 && nh > 0.99) {
            day += glints(nG, footprint, 6.0, nG, direction, sun, 0.12, 1500.0, 0.9, 0.3, 51.0, look.glacierGlow.xyz * 1.4) * waterVisible;
        }
        color += day * daylight;
    }
    if (daylight < 1.0) {
        float3 moon = normalize(uniforms.cameraUp.xyz * 0.55 - uniforms.cameraRight.xyz * 0.35 - uniforms.cameraForward.xyz);
        float moonLit = saturate(dot(nM, moon));
        float3 night = mix(look.nightLand.xyz * (0.5 + 0.65 * moonLit), look.nightWater.xyz, water * (1.0 - wall));
        night = mix(night, look.nightLand.xyz * 0.55, floe * water);
        night += look.glacierGlow.xyz * waterline * 0.025;
        float nightGate = 1.0 - smoothstep(-0.16, 0.02, muG);
        if (nightGate > 0.0 && onLand > 0.0) {
            float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
            float halo = lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r;
            night += (look.cityLight.xyz * pow(lights, 2.2) * 1.6 + look.glacierGlow.xyz * pow(halo, 1.3) * 0.3) * nightGate * onLand;
        }
        if (look.auroraStrength > 0.0 && muG < -0.08) {
            float polarNight = 1.0 - smoothstep(-0.25, -0.08, muG);
            night += look.aurora.xyz * look.auroraStrength * aurora(nG, sun) * polarNight;
        }
        color += night * (1.0 - daylight);
    }
    color += look.rim.xyz * pow(1.0 - viewCosine, 5.0) * mix(0.2, 0.4, daylight);

    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
        if (effects.detail.y > 0.0) {
            float exposed = look.snowCover > 0.0 ? smoothstep(0.15, 0.6, trough) : onLand;
            float crack = fracture(nG, effects.dent.xyz, effects.radii.x, saturate(effects.detail.y), pixelAngle);
            float3 fissure = look.glacier.xyz * mix(0.3, 0.75, daylight);
            color = mix(color, fissure, crack * 0.85 * max(exposed, water * floe));
        }
        color += look.cityLight.xyz * (ring + wake * 0.15);
        color += look.cityLight.xyz * effects.radii.z * effectWeight(nG, effects.bump.xyz, effects.radii.y);
        if (frostWave > 0.001) {
            float3 rime = glints(nG, footprint, 6.0, nG, direction, -direction, 1.2, 10.0, 0.85, 1.0, 71.0, look.glacierGlow.xyz * 1.6);
            float shore = mix(exp(-max(-coast, 0.0) / 1.2), 1.0, onLand);
            color += look.frost.xyz * frostWave * 0.3 * onLand + rime * frostWave * shore * 4.0;
        }
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

static float iceSnowflake(float2 offset, float size) {
    float glint = exp(-dot(offset, offset) / (0.6 * size * size));
    for (int arm = 0; arm < 3; arm++) {
        float angle = float(arm) * 1.0471976 + 0.2618;
        float2 axis = float2(cos(angle), sin(angle));
        float across = dot(offset, float2(-axis.y, axis.x));
        float along = abs(dot(offset, axis));
        glint += 0.4 * exp(-across * across / 0.3) * saturate(1.0 - along / (size * 4.5));
    }
    return glint;
}

fragment half4 iceBackground(FullscreenVertex in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant IceLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float scale = uniforms.viewport.x / 1206.0;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = mix(look.backdrop.xyz, look.shelfWater.xyz * 0.7, 0.45 * smoothstep(-0.05, 0.6, screen.y));
    color *= mix(1.1, 0.75, smoothstep(0.2, 0.8, length(screen)));
    color += look.rim.xyz * 0.08 * exp(-max(reach - 1.0, 0.0) * 4.0);
    BackdropPoint star = backdropPoint(direction, 80.0, 3.0, focal);
    if (star.random.x < 0.35) {
        float magnitude = pow(star.random.y, 4.0) * 0.9 + 0.07;
        color += look.frost.xyz * magnitude * exp(-dot(star.offset, star.offset) / (0.7 * scale * scale));
    }
    BackdropPoint drift = backdropPoint(direction, 38.0, 23.0, focal);
    if (drift.random.x < 0.3) {
        float radius = (2.0 + 2.5 * drift.random.y) * scale;
        color += look.frost.xyz * (0.05 + 0.07 * drift.random.z) * saturate(1.0 - length(drift.offset) / radius);
    }
    BackdropPoint flake = backdropPoint(direction, 14.0, 11.0, focal);
    if (flake.random.x < 0.5) {
        float size = (1.6 + 2.0 * flake.random.y) * scale;
        color += look.frost.xyz * (0.3 + 0.4 * flake.random.z) * iceSnowflake(flake.offset, size);
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
