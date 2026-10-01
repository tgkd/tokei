#include "GlobeShared.h"

struct MosaicLook {
    float4 backdrop;
    float4 backdropShade;
    float4 shard;
    float4 grout;
    float4 groutNight;
    float4 cobalt;
    float4 turquoise;
    float4 seaWhite;
    float4 ochre;
    float4 orange;
    float4 olive;
    float4 lemon;
    float4 gold;
    float4 terracottaBack;
    float4 nightGlaze;
    float4 cityLight;
    float4 twilight;
    float tileSize;
    float tileTilt;
    float glazeGloss;
    float glazeSpec;
    float groutWidth;
    float coastRow;
    float goldChance;
    float goldGloss;
    float flipTime;
    float flipJitter;
    float funnel;
    float pressDepth;
    float recovery;
    float flipThreshold;
    float flipSpread;
    float rattle;
    float inflateSpan;
    float terminatorWidth;
    float cityGlow;
    float patternSize;
    float patternTurns;
    float patternGrout;
    float vignette;
    float reserved;
};

struct MosaicCell {
    float edge;
    float3 away;
    float2 id;
    float3 site;
};

struct MosaicPoint {
    float latitude;
    float longitude;
    float3 east;
    float3 north;
    float cosP;
};

static MosaicPoint mosaicPoint(float3 normal) {
    float cosP = max(length(normal.xz), 1e-4);
    float3 east = float3(normal.z, 0.0, -normal.x) / cosP;
    return {asin(clamp(normal.y, -1.0, 1.0)), atan2(normal.x, normal.z), east, cross(normal, east), cosP};
}

static float mosaicWrap(float angle) {
    return angle - 2.0 * M_PI_F * floor(angle / (2.0 * M_PI_F) + 0.5);
}

static float mosaicCos(float angle) {
    if (abs(angle) < 0.6) {
        float square = angle * angle;
        return 1.0 - square * (0.5 - square * (1.0 / 24.0 - square / 720.0));
    }
    return cos(angle);
}

static float3 mosaicSite(float row, float column, float rows, float seed, float band) {
    float latitude = M_PI_F * 0.5 - (row + 0.5) * band;
    float columns = max(floor(2.0 * rows * cos(latitude) + 0.5), 1.0);
    float3 jitter = hash33(float3(row, column, seed));
    float delta = (0.35 - 0.7 * jitter.y) * band;
    return float3(latitude + delta, 2.0 * M_PI_F * (column + 0.15 + 0.7 * jitter.x) / columns - M_PI_F, 0.0);
}

static MosaicCell mosaicCell(MosaicPoint point, float rows, float seed) {
    float band = M_PI_F / rows;
    float latitude = point.latitude;
    float longitude = point.longitude;
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
            float offset = mosaicWrap((c + 0.15 + 0.7 * jitter.x) * spacing - M_PI_F - longitude);
            float chord;
            if (polar) {
                float half2 = 0.5 * delta * delta;
                float sinF = sinR * (1.0 - half2) + cosR * delta;
                float cosF = cosR * (1.0 - half2) - sinR * delta;
                chord = 2.0 - 2.0 * (sinP * sinF + cosP * cosF * mosaicCos(offset));
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
    float3 nearest = mosaicSite(nearestId.x, nearestId.y, rows, seed, band);
    float3 runner = mosaicSite(runnerId.x, runnerId.y, rows, seed, band);
    float between;
    if (polar) {
        between = 2.0 - 2.0 * (sin(nearest.x) * sin(runner.x) + cos(nearest.x) * cos(runner.x) * mosaicCos(mosaicWrap(runner.y - nearest.y)));
    } else {
        float across = mosaicWrap(runner.y - nearest.y) * cosP;
        float up = runner.x - nearest.x;
        between = across * across + up * up;
    }
    float edge = (second - first) / (2.0 * sqrt(max(between, 1e-10)));
    float3 away = point.east * (mosaicWrap(longitude - nearest.y) * cosP) + point.north * (latitude - nearest.x);
    return {edge, away, nearestId, nearest};
}

static float3 mosaicRotate(float3 v, float3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

fragment half4 mosaicFragment(MeshFragmentIn in [[stage_in]],
                              constant GlobeUniforms &uniforms [[buffer(0)]],
                              constant MosaicLook &look [[buffer(1)]],
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
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    float pixelAngle = max(max(length(dfdx(nG)), length(dfdy(nG))), 1e-5);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nM = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float coastWidth = max(fwidth(coast), 1e-4);

    bool active = effectsActive(effects);
    float inflate = active ? effects.radii.w : 1.0;
    float3 baseNormal = nM;
    if (active) {
        float3 slope;
        effectOffset(nG, effects, slope);
        baseNormal = normalize(mix(nG, nM, inflate) - slope);
    }

    float rows = max(floor(180.0 / look.tileSize + 0.5), 4.0);
    float band = M_PI_F / rows;
    MosaicCell cell = mosaicCell(mosaicPoint(nG), rows, 11.0);
    float3 center = float3(cos(cell.site.x) * sin(cell.site.y), sin(cell.site.x), cos(cell.site.x) * cos(cell.site.y));
    float2 centerUV = float2(cell.site.y / (2.0 * M_PI_F) + 0.5, 0.5 - cell.site.x / M_PI_F);
    float detail = smoothstep(3.0, 6.0, band / pixelAngle);

    float region = coast > 0.0 ? 0.0 : (coast > -look.coastRow ? 1.0 : (coast > -2.0 * look.coastRow ? 2.0 : 3.0));
    float groutHalf = look.groutWidth * band * 0.5;
    float latticeGrout = 1.0 - smoothstep(groutHalf - pixelAngle * 0.5, groutHalf + pixelAngle * 0.5, cell.edge);
    float boundary = min(abs(coast), min(abs(coast + look.coastRow), abs(coast + 2.0 * look.coastRow)));
    float boundaryHalf = groutHalf * 57.29578;
    float boundaryGrout = (1.0 - smoothstep(boundaryHalf - coastWidth * 0.5, boundaryHalf + coastWidth * 0.5, boundary)) * step(-2.0 * look.coastRow - boundaryHalf * 2.0, coast);
    float grout = max(latticeGrout, boundaryGrout) * detail;

    float3 random = hash33(float3(cell.id, 17.0 + region * 7.0));
    float3 albedo;
    bool gold = false;
    if (region < 0.5) {
        albedo = random.x < 0.3 ? look.ochre.xyz : (random.x < 0.55 ? look.orange.xyz : (random.x < 0.8 ? look.olive.xyz : look.lemon.xyz));
        gold = random.y < look.goldChance;
    } else if (region < 1.5) {
        albedo = look.seaWhite.xyz;
    } else if (region < 2.5) {
        albedo = mix(look.seaWhite.xyz, look.turquoise.xyz, 0.18);
    } else {
        albedo = random.x < 0.4 ? look.cobalt.xyz : (random.x < 0.7 ? look.turquoise.xyz : (random.x < 0.88 ? mix(look.cobalt.xyz, look.turquoise.xyz, 0.5) : look.seaWhite.xyz));
    }
    if (gold) {
        albedo = look.gold.xyz;
    }
    albedo *= 0.92 + 0.16 * random.z;

    float cosCenter = max(length(center.xz), 1e-4);
    float3 east = float3(center.z, 0.0, -center.x) / cosCenter;
    float3 north = cross(center, east);
    float2 tilt = (hash33(float3(cell.id, 29.0)).xy - 0.5) * 2.0 * look.tileTilt * detail;
    float3 tileNormal = normalize(baseNormal + east * tilt.x + north * tilt.y);

    float3 jitter = hash33(float3(cell.id, 53.0));
    float3 axis = jitter.z < 0.5 ? east : north;
    float phi = 0.0;
    if (active) {
        if (effects.ripple.w >= 0.0) {
            float arrival = acos(clamp(dot(center, effects.ripple.xyz), -1.0, 1.0)) / max(effects.wave.w, 1e-3) + look.flipJitter * jitter.x;
            float progress = saturate((effects.ripple.w - arrival) / look.flipTime);
            phi += 2.0 * M_PI_F * smoothstep(0.0, 1.0, progress);
        }
        float clock = effects.state.w;
        if (clock > 0.0) {
            float stamp = snowTexture.sample(surfaceSampler, centerUV, level(0.0)).r;
            float refill = saturate((clock - stamp) / max(look.recovery, 0.01));
            float threshold = look.flipThreshold + look.flipSpread * jitter.y;
            phi += M_PI_F * (1.0 - smoothstep(threshold - 0.04, threshold + 0.04, refill));
        }
        float facing = acos(clamp(dot(center, normalize(uniforms.cameraPosition.xyz)), -1.0, 1.0));
        float front = look.inflateSpan * M_PI_F * inflate;
        phi += M_PI_F * (1.0 - smoothstep(facing, facing + 0.3, front));

        float pressAmount = saturate(effects.dent.w / max(look.pressDepth, 1e-5));
        float3 toward = effects.dent.xyz - center * dot(center, effects.dent.xyz);
        float towardLength = length(toward);
        if (pressAmount > 0.0 && towardLength > 1e-5) {
            float funnelWeight = look.funnel * effectWeight(center, effects.dent.xyz, effects.radii.x) * pressAmount;
            tileNormal = normalize(tileNormal + toward / towardLength * funnelWeight);
        }
        float stretch = abs(effects.shapeX.x - 1.0) + abs(effects.shapeY.y - 1.0) + abs(effects.shapeZ.z - 1.0);
        float3 shake = (hash33(float3(cell.id, 71.0)) - 0.5) * 2.0 * look.rattle * stretch * detail;
        tileNormal = normalize(tileNormal + east * shake.x + north * shake.y);
    }

    float turn = phi - 2.0 * M_PI_F * floor(phi / (2.0 * M_PI_F));
    float flipCos = cos(turn);
    bool back = flipCos < 0.0;
    float bed = 0.0;
    if (turn > 1e-3 && turn < 2.0 * M_PI_F - 1e-3) {
        float3 across = cross(center, axis);
        float offsetAcross = abs(dot(cell.away, across));
        float extent = abs(flipCos) * band * 0.75;
        bed = smoothstep(extent - pixelAngle, extent + pixelAngle, offsetAcross);
        tileNormal = mosaicRotate(tileNormal, axis, turn);
        if (dot(tileNormal, nG) < 0.0) {
            tileNormal = -tileNormal;
        }
    }
    if (back) {
        albedo = look.terracottaBack.xyz * (0.9 + 0.2 * random.z);
        gold = false;
    }

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);
    float warmth = (1.0 - smoothstep(0.0, look.terminatorWidth * 5.0, muG)) * daylight;
    float3 halfway = normalize(sun + view);

    float lambert = saturate(dot(tileNormal, sun));
    float glossPower = gold ? look.goldGloss : look.glazeGloss;
    float specular = back ? 0.0 : pow(saturate(dot(tileNormal, halfway)), glossPower) * look.glazeSpec * saturate(muG * 6.0);
    float3 specularColor = gold ? look.gold.xyz * 2.2 : float3(1.0);
    float3 tileDay = albedo * (0.16 + 0.84 * lambert) + specularColor * specular;
    float3 tileNight = look.nightGlaze.xyz * (0.7 + 0.3 * random.z) + albedo * 0.025;
    float3 tileColor = mix(tileNight, tileDay, daylight);

    float groutLambert = saturate(dot(baseNormal, sun));
    float3 groutDay = look.grout.xyz * (0.16 + 0.84 * groutLambert) * 0.85;
    float3 groutColor = mix(look.groutNight.xyz, groutDay, daylight);
    float3 bedColor = look.groutNight.xyz * mix(0.6, 1.0, daylight);

    float3 color = mix(tileColor, groutColor, grout);
    color = mix(color, bedColor, bed);
    color = mix(color, color * look.twilight.xyz * 1.6, warmth * 0.4);

    if (region < 0.5 && nightGate > 0.0) {
        float lights = lightsTexture.sample(surfaceSampler, centerUV, level(0.0)).r;
        float glow = look.cityGlow * (gold ? 1.0 : 0.25);
        color += look.cityLight.xyz * lights * glow * nightGate * (1.0 - grout) * (1.0 - bed);
    }

    if (active) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 mosaicBackground(FullscreenVertex in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant MosaicLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 base = mix(look.backdrop.xyz, look.backdropShade.xyz, smoothstep(0.1, 0.9, length(screen)) * look.vignette * 2.0);

    float3 eye = uniforms.cameraPosition.xyz;
    float eyeDistance = length(eye);
    float pointScale = uniforms.viewport.x / 402.0;
    float cell = look.patternSize * pointScale * pow(3.85 / max(eyeDistance, 1.0), 0.2);
    float yaw = atan2(eye.x, eye.z);
    float pitch = asin(clamp(eye.y / max(eyeDistance, 1e-4), -1.0, 1.0));
    float2 drifted = pixel + float2(-yaw, pitch) * cell * look.patternTurns / M_PI_F;
    float2 motif = drifted / cell;
    float footprint = fwidth(motif.x);

    Cellular tile = cellular(motif, 3.0);
    float3 random = hash33(float3(tile.cell, 5.0));
    float3 tileColor = base * (0.84 + 0.24 * random.x);
    tileColor = mix(tileColor, look.ochre.xyz * 0.62, step(0.9, random.y) * 0.55);
    tileColor = mix(tileColor, look.shard.xyz * 0.78, step(0.985, random.z) * 0.35);
    float bevel = smoothstep(0.0, 0.22, tile.edge);
    float3 shadeAxis = hash33(float3(tile.cell, 9.0)) - 0.5;
    tileColor *= mix(0.86, 1.0, bevel) * (1.0 + 0.08 * shadeAxis.x);
    float glint = pow(saturate(1.0 - tile.edge * 3.5), 3.0) * step(0.5, shadeAxis.y) * 0.08;
    tileColor += look.shard.xyz * glint;

    float grout = 1.0 - smoothstep(look.patternGrout - footprint, look.patternGrout + footprint, tile.edge);
    float3 groutColor = mix(base, look.grout.xyz, 0.32) * 0.9;
    float3 pattern = mix(tileColor, groutColor, grout);

    float open = smoothstep(1.02, 1.3, reach);
    float3 color = mix(base, pattern, mix(0.55, 1.0, open));
    color = mix(color, base * 0.92, 0.35 * exp(-max(reach - 1.0, 0.0) * 6.0));
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
